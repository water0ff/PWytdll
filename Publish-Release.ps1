#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Version = ("v{0}" -f (Get-Date -Format "yyMMdd.HHmm")),
    [string]$Title,
    [string]$Notes,
    [string]$NotesFile,
    [switch]$SkipBuild,
    [switch]$Draft,
    [switch]$Prerelease,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Path))
}

function Assert-FileExists {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta el archivo requerido: $Path"
    }
    return $Path
}

function Get-ReleaseNotesText {
    if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
        $resolvedNotesFile = Resolve-Path -LiteralPath $NotesFile
        return (Get-Content -LiteralPath $resolvedNotesFile.Path -Raw)
    }

    if (-not [string]::IsNullOrWhiteSpace($Notes)) {
        return $Notes
    }

    $typedNotes = Read-Host "Notas del release"
    if ([string]::IsNullOrWhiteSpace($typedNotes)) {
        return "Sin notas."
    }
    return $typedNotes
}

function Format-CommandArgument {
    param([Parameter(Mandatory=$true)][string]$Value)
    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }
    return $Value
}

Push-Location $PSScriptRoot
try {
    if (-not $SkipBuild) {
        Write-Host ("Creando build {0}..." -f $Version) -ForegroundColor Cyan
        & (Resolve-ProjectPath "build.ps1") -Version $Version
        if (-not $?) {
            throw "build.ps1 no se completo correctamente."
        }
    }

    $versionFile = Assert-FileExists (Resolve-ProjectPath "release\version.json")
    $meta = Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json
    $tag = [string]$meta.Version
    if ([string]::IsNullOrWhiteSpace($tag)) {
        throw "release\version.json no contiene Version."
    }

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = "YTDLL $tag"
    }

    $releaseNotes = Get-ReleaseNotesText
    if ([string]::IsNullOrWhiteSpace($releaseNotes)) {
        $releaseNotes = "Sin notas."
    }

    $assets = @(
        (Assert-FileExists -Path (Resolve-ProjectPath "ytdll-release.zip")),
        (Assert-FileExists -Path (Resolve-ProjectPath "Install-YTDLL.ps1")),
        (Assert-FileExists -Path (Resolve-ProjectPath "YTDLL.bat"))
    )

    $ghArgs = @("release", "create", $tag)
    $ghArgs += $assets
    $ghArgs += @("--title", $Title, "--notes", $releaseNotes)
    if ($Draft) { $ghArgs += "--draft" }
    if ($Prerelease) { $ghArgs += "--prerelease" }

    if ($DryRun) {
        Write-Host "Comando preparado:" -ForegroundColor Yellow
        Write-Host ("gh " + (($ghArgs | ForEach-Object { Format-CommandArgument $_ }) -join " "))
        return
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) no esta disponible en PATH."
    }

    Write-Host ("Publicando release {0}..." -f $tag) -ForegroundColor Cyan
    & gh @ghArgs
    if ($LASTEXITCODE -ne 0) {
        throw "gh release create finalizo con codigo $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
