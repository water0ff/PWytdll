#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Owner = "water0n",
    [string]$Repository = "PWytdll",
    [string]$InstallRoot = "C:\Temp\YTDLL",
    [switch]$ForceUpdate,
    [switch]$NoLaunch,
    [string]$PackagePath,
    [string]$PackageVersion
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$installRootPath = [System.IO.Path]::GetFullPath($InstallRoot)
$installRootDrive = [System.IO.Path]::GetPathRoot($installRootPath)
if ($installRootPath.TrimEnd("\") -eq $installRootDrive.TrimEnd("\")) {
    throw "InstallRoot no puede ser la raiz de una unidad."
}

$assetName = "ytdll-release.zip"
$appPath = Join-Path $installRootPath "app"
$localVersionFile = Join-Path $appPath "version.json"
$localRunBat = Join-Path $appPath "run.bat"
$localInstallMetadataFile = Join-Path $installRootPath "install.json"

function Get-InstalledVersion {
    if (-not (Test-Path -LiteralPath $localVersionFile)) {
        return $null
    }

    try {
        $data = Get-Content -LiteralPath $localVersionFile -Raw | ConvertFrom-Json
        return [string]$data.Version
    } catch {
        return $null
    }
}

function Normalize-Sha256Digest {
    param([string]$Digest)

    if ([string]::IsNullOrWhiteSpace($Digest)) {
        return $null
    }
    if ($Digest -match '^sha256:([a-fA-F0-9]{64})$') {
        return "sha256:$($matches[1].ToLowerInvariant())"
    }
    if ($Digest -match '^[a-fA-F0-9]{64}$') {
        return "sha256:$($Digest.ToLowerInvariant())"
    }
    return $null
}

function Get-InstalledPackageDigest {
    if (-not (Test-Path -LiteralPath $localInstallMetadataFile)) {
        return $null
    }

    try {
        $data = Get-Content -LiteralPath $localInstallMetadataFile -Raw | ConvertFrom-Json
        return (Normalize-Sha256Digest -Digest ([string]$data.PackageSha256))
    } catch {
        return $null
    }
}

function Save-InstallMetadata {
    param(
        [string]$Version,
        [string]$PackageSha256,
        [string]$SourceVersion
    )

    $metadata = [ordered]@{
        Version       = $Version
        SourceVersion = $SourceVersion
        PackageSha256 = (Normalize-Sha256Digest -Digest $PackageSha256)
        InstalledAt   = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    }
    $metadata |
        ConvertTo-Json |
        Set-Content -LiteralPath $localInstallMetadataFile -Encoding UTF8
}

function Start-Ytdll {
    if (-not (Test-Path -LiteralPath $localRunBat)) {
        throw "No se encontro el ejecutable local: $localRunBat"
    }

    if (-not $NoLaunch) {
        Write-Host "Iniciando YTDLL..." -ForegroundColor Green
        Start-Process -FilePath $localRunBat -WorkingDirectory $appPath
    }
}

function Use-InstalledCopy {
    param([string]$Reason)

    if (Test-Path -LiteralPath $localRunBat) {
        Write-Warning $Reason
        Write-Host "Se usara la instalacion local." -ForegroundColor Yellow
        Start-Ytdll
        return $true
    }

    return $false
}

New-Item -ItemType Directory -Path $installRootPath -Force | Out-Null

$downloadPath = Join-Path $installRootPath $assetName
$remoteVersion = $PackageVersion
$expectedDigest = $null
$packageSha256 = $null

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $apiUrl = "https://api.github.com/repos/$Owner/$Repository/releases/latest"
    Write-Host "Consultando la ultima version de YTDLL..." -ForegroundColor Cyan

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing `
            -Headers @{ "User-Agent" = "YTDLL-Installer" }
    } catch {
        if (Use-InstalledCopy -Reason "No se pudo consultar GitHub Releases: $($_.Exception.Message)") {
            return
        }
        throw
    }

    $remoteVersion = [string]$release.tag_name
    $asset = @($release.assets | Where-Object name -eq $assetName | Select-Object -First 1)
    if ($asset.Count -eq 0) {
        if (Use-InstalledCopy -Reason "El release $remoteVersion no contiene $assetName.") {
            return
        }
        throw "El release $remoteVersion no contiene el archivo $assetName."
    }
    $expectedDigest = [string]$asset[0].digest
    $normalizedExpectedDigest = Normalize-Sha256Digest -Digest $expectedDigest

    $installedVersion = Get-InstalledVersion
    $installedDigest = Get-InstalledPackageDigest
    if (-not $ForceUpdate -and
        -not [string]::IsNullOrWhiteSpace($installedVersion) -and
        $installedVersion -eq $remoteVersion) {
        if ($normalizedExpectedDigest -and $installedDigest -eq $normalizedExpectedDigest) {
            Write-Host "YTDLL $installedVersion ya esta actualizado." -ForegroundColor Green
            Start-Ytdll
            return
        }

        if ($normalizedExpectedDigest) {
            Write-Host "YTDLL $installedVersion tiene el mismo tag, pero el paquete remoto cambio. Actualizando..." -ForegroundColor Yellow
        } else {
            Write-Host "YTDLL $installedVersion ya esta actualizado." -ForegroundColor Green
            Start-Ytdll
            return
        }
    }

    Write-Host "Descargando YTDLL $remoteVersion..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $asset[0].browser_download_url `
            -OutFile $downloadPath -UseBasicParsing
    } catch {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        if (Use-InstalledCopy -Reason "No se pudo descargar $remoteVersion`: $($_.Exception.Message)") {
            return
        }
        throw
    }

    $packageSha256 = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash
    if ($normalizedExpectedDigest) {
        $actualDigest = Normalize-Sha256Digest -Digest $packageSha256
        if ($actualDigest -ne $normalizedExpectedDigest) {
            Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
            throw "La suma SHA256 del paquete descargado no coincide con GitHub."
        }
    }
} else {
    $resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
    Copy-Item -LiteralPath $resolvedPackage -Destination $downloadPath -Force
    $packageSha256 = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash
    if ([string]::IsNullOrWhiteSpace($remoteVersion)) {
        $remoteVersion = "paquete local"
    }
}

$stagingPath = Join-Path $installRootPath ("app.new." + [guid]::NewGuid().ToString("N"))
$backupPath = Join-Path $installRootPath ("app.old." + [guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $stagingPath -Force

    foreach ($requiredFile in @(
        "Main.ps1",
        "Dependencies.ps1",
        "Functions.ps1",
        "GUI.ps1",
        "run.bat",
        "version.json"
    )) {
        $candidate = Join-Path $stagingPath $requiredFile
        if (-not (Test-Path -LiteralPath $candidate)) {
            throw "El paquete esta incompleto. Falta: $requiredFile"
        }
    }

    $packageInfo = Get-Content -LiteralPath (Join-Path $stagingPath "version.json") -Raw |
        ConvertFrom-Json
    $packageVersionFound = [string]$packageInfo.Version
    if ([string]::IsNullOrWhiteSpace($packageVersionFound)) {
        throw "version.json no contiene una version valida."
    }
    if (-not [string]::IsNullOrWhiteSpace($remoteVersion) -and
        $remoteVersion -ne "paquete local" -and
        $packageVersionFound -ne $remoteVersion) {
        throw "La version del paquete ($packageVersionFound) no coincide con el release ($remoteVersion)."
    }

    if (Test-Path -LiteralPath $appPath) {
        Move-Item -LiteralPath $appPath -Destination $backupPath
    }

    try {
        Move-Item -LiteralPath $stagingPath -Destination $appPath
    } catch {
        if (Test-Path -LiteralPath $backupPath) {
            Move-Item -LiteralPath $backupPath -Destination $appPath
        }
        throw
    }

    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    }
} finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $downloadPath) {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    }
}

$installedVersion = Get-InstalledVersion
Save-InstallMetadata -Version $installedVersion -PackageSha256 $packageSha256 -SourceVersion $remoteVersion
Write-Host "YTDLL instalado correctamente." -ForegroundColor Green
Write-Host "Version: $installedVersion" -ForegroundColor Cyan
Write-Host "Ruta: $appPath" -ForegroundColor DarkGray

Start-Ytdll
