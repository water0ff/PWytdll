# ============================================
# YT-DLP GUI Bootstrap - Daniel Tools
# ============================================

# --- Config inicial y carpeta temporal ---
Write-Host "`n[INFO] Iniciando asistente..." -ForegroundColor Cyan

# Crear C:\Temp y C:\Temp\icos
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
    Write-Host "[OK] Carpeta 'C:\Temp' creada." -ForegroundColor Green
} else {
    Write-Host "[OK] Carpeta 'C:\Temp' existente." -ForegroundColor DarkGreen
}
$iconDir = "C:\Temp\icos"
if (-not (Test-Path $iconDir)) {
    New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
    Write-Host "[OK] Carpeta de íconos creada: $iconDir" -ForegroundColor Green
} else {
    Write-Host "[OK] Carpeta de íconos existente: $iconDir" -ForegroundColor DarkGreen
}

# --- Advertencia ALFA ---
Write-Host "`n==============================================" -ForegroundColor Red
Write-Host "           ADVERTENCIA DE VERSIÓN ALFA          " -ForegroundColor Red
Write-Host "==============================================" -ForegroundColor Red
Write-Host "Esta aplicación se encuentra en fase de desarrollo ALFA.`n" -ForegroundColor Yellow
Write-Host "¿Acepta ejecutar esta aplicación bajo su propia responsabilidad? (Y/N)" -ForegroundColor Yellow
$response = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
while ($response.Character -notin 'Y','N') {
    $response = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
if ($response.Character -ne 'Y') {
    Write-Host "`n[ABORT] Ejecución cancelada por el usuario.`n" -ForegroundColor Red
    exit
}
Clear-Host
Write-Host "[OK] El usuario aceptó los riesgos. Corriendo programa..." -ForegroundColor Green

# --- Variables globales ---
$global:defaultInstructions = @"
----- CAMBIOS -----
- Primer versión
- 2
"@

# --- Cargar WinForms ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Versionado y fuentes ---
$version     = "Alfa 251109.1123"
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$boldFont    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

Write-Host "`n=============================================" -ForegroundColor DarkCyan
Write-Host "                   YTDLL                       " -ForegroundColor Green
Write-Host "              Versión: v$($version)               " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor DarkCyan

# --- Utilidades UI básicas ---
function Create-Form {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(300, 600)),
        [System.Windows.Forms.FormStartPosition]$StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen,
        [System.Windows.Forms.FormBorderStyle]$FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog,
        [bool]$MaximizeBox = $false, [bool]$MinimizeBox = $false,
        [bool]$TopMost = $false, [bool]$ControlBox = $true,
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::White
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = $Size
    $form.StartPosition = $StartPosition
    $form.FormBorderStyle = $FormBorderStyle
    $form.MaximizeBox = $MaximizeBox
    $form.MinimizeBox = $MinimizeBox
    $form.TopMost = $TopMost
    $form.ControlBox = $ControlBox
    $form.BackColor = $BackColor
    return $form
}
function Create-Label {
    param(
        [string]$Text, [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(260, 100)),
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black,
        [System.Drawing.Font]$Font = $defaultFont,
        [System.Windows.Forms.BorderStyle]$BorderStyle = [System.Windows.Forms.BorderStyle]::None,
        [System.Drawing.ContentAlignment]$TextAlign = [System.Drawing.ContentAlignment]::TopLeft
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = $Location
    $label.Size = $Size
    $label.ForeColor = $ForeColor
    $label.Font = $Font
    $label.BorderStyle = $BorderStyle
    $label.TextAlign = $TextAlign
    $label.AutoSize = $false
    $label.UseCompatibleTextRendering = $true
    return $label
}
function Create-Button {
    param(
        [string]$Text, [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(120, 35)),
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::White,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black,
        [System.Drawing.Font]$Font = $defaultFont
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = $Location
    $btn.Size = $Size
    $btn.BackColor = $BackColor
    $btn.ForeColor = $ForeColor
    $btn.Font = $Font
    return $btn
}

# --- Progreso (opcional, para instalaciones) ---
function Show-ProgressBar {
    $sizeProgress = New-Object System.Drawing.Size(400, 150)
    $formProgress = Create-Form -Title "Progreso" -Size $sizeProgress -TopMost $true -ControlBox $false
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size = New-Object System.Drawing.Size(360, 20)
    $progressBar.Location = New-Object System.Drawing.Point(10, 50)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $progressBar.Maximum = 100
    $type = $progressBar.GetType()
    $flags = [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance
    $type.GetField("DoubleBuffered", $flags).SetValue($progressBar, $true)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(10, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 20)
    $lbl.Text = "0% Completado"
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $formProgress.Controls.Add($progressBar)
    $formProgress.Controls.Add($lbl)
    $formProgress | Add-Member -MemberType NoteProperty -Name ProgressBar -Value $progressBar -Force
    $formProgress | Add-Member -MemberType NoteProperty -Name Label -Value $lbl -Force

    $formProgress.Show()
    return $formProgress
}
function Update-ProgressBar {
    param($ProgressForm, $CurrentStep, $TotalSteps)
    $percent = [math]::Round(($CurrentStep / $TotalSteps) * 100)
    if (-not $ProgressForm.IsDisposed) {
        $ProgressForm.ProgressBar.Value = $percent
        $ProgressForm.Label.Text = "$percent% Completado"
        [System.Windows.Forms.Application]::DoEvents()
    }
}
function Close-ProgressBar { param($ProgressForm) $ProgressForm.Close() }

# --- Instalación de Chocolatey ---
function Install-Chocolatey {
    Write-Host "[CHOCOLATEY] Iniciando instalación..." -ForegroundColor Cyan
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "[CHOCOLATEY] Instalación completada." -ForegroundColor Green

        Write-Host "[CHOCOLATEY] Configurando cacheLocation..." -ForegroundColor Yellow
        choco config set cacheLocation C:\Choco\cache | Out-Null
        Write-Host "[CHOCOLATEY] Configuración completada." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[ERROR] Falló la instalación de Chocolatey: $_" -ForegroundColor Red
        return $false
    }
}

# --- Verificar y (opcional) instalar/actualizar herramientas ---
function Check-Tool {
    param(
        [Parameter(Mandatory=$true)][string]$Display,  # 'yt-dlp' o 'FFmpeg'
        [Parameter(Mandatory=$true)][string]$Exe,      # ejecutable: 'yt-dlp' o 'ffmpeg'
        [Parameter(Mandatory=$true)][string]$ChocoPkg, # paquete choco: 'yt-dlp' o 'ffmpeg'
        [Parameter(Mandatory=$true)][System.Windows.Forms.Label]$Label
    )

    Write-Host "[CHECK] Verificando $Display..." -ForegroundColor Cyan
    $installed = $false
    $version = $null

    try {
        $out = & $Exe --version 2>$null
        if ($out) {
            $installed = $true
            if ($Display -eq 'FFmpeg') {
                $first = ($out -split "`n")[0]
                if ($first -match 'version\s+([^\s]+)') { $version = $Matches[1] }
            } else {
                $version = ($out -split "`n")[0].Trim()
            }
        }
    } catch {}

    if (-not $installed) {
        Write-Host "[MISS] $Display no está instalado." -ForegroundColor Yellow
        $Label.Text = "$Display: NO INSTALADO"
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "$Display no está instalado. ¿Desea instalarlo con Chocolatey?",
            "$Display requerido",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($resp -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "[CHOCOLATEY] Instalando $ChocoPkg..." -ForegroundColor Cyan
            choco install $ChocoPkg -y | Out-Null
            # Reintentar detección
            return Check-Tool -Display $Display -Exe $Exe -ChocoPkg $ChocoPkg -Label $Label
        } else {
            Write-Host "[SKIP] Instalación de $Display cancelada por el usuario." -ForegroundColor DarkYellow
            return
        }
    }

    $Label.Text = "$Display v$version"
    Write-Host "[OK] $Display versión detectada: $version" -ForegroundColor Green

    # Comprobar si hay actualización disponible
    Write-Host "[CHECK] Buscando actualización de $Display en Chocolatey..." -ForegroundColor Cyan
    $isOutdated = choco outdated --local-only | Select-String -Pattern "^\s*$ChocoPkg\s"
    if ($isOutdated) {
        Write-Host "[OUTDATED] Hay una actualización disponible para $Display." -ForegroundColor Yellow
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "$Display tiene una actualización disponible. ¿Desea actualizar ahora?",
            "Actualizar $Display",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        if ($resp -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "[CHOCOLATEY] Actualizando $ChocoPkg..." -ForegroundColor Cyan
            choco upgrade $ChocoPkg -y | Out-Null
            # Releer versión después de actualizar
            return Check-Tool -Display $Display -Exe $Exe -ChocoPkg $ChocoPkg -Label $Label
        } else {
            Write-Host "[SKIP] Actualización de $Display omitida por el usuario." -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "[OK] $Display está actualizado." -ForegroundColor Green
    }
}

# --- Verificar/Instalar Chocolatey ---
function Ensure-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Chocolatey ya está instalado." -ForegroundColor Green
        return $true
    }

    Write-Host "[WARN] Chocolatey no está instalado." -ForegroundColor Yellow
    $resp = [System.Windows.Forms.MessageBox]::Show(
        "Chocolatey no está instalado y es necesario para continuar." + [Environment]::NewLine +
        "¿Desea instalarlo ahora?",
        "Chocolatey requerido",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($resp -eq [System.Windows.Forms.DialogResult]::No) {
        Write-Host "[ABORT] El usuario rechazó instalar Chocolatey." -ForegroundColor Red
        return $false
    }

    # (Opcional) barra de progreso visual
    $p = Show-ProgressBar
    Update-ProgressBar -ProgressForm $p -CurrentStep 1 -TotalSteps 5
    $ok = Install-Chocolatey
    Update-ProgressBar -ProgressForm $p -CurrentStep 5 -TotalSteps 5
    Close-ProgressBar -ProgressForm $p

    if (-not $ok) {
        [System.Windows.Forms.MessageBox]::Show(
            "Error al instalar Chocolatey. Por favor, inténtelo manualmente.",
            "Error de instalación",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Chocolatey se instaló correctamente. Es recomendable reiniciar PowerShell antes de continuar.",
        "Instalación completada",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    Write-Host "[OK] Chocolatey instalado correctamente." -ForegroundColor Green
    return $true
}

# --- (Opcional) Verificar privilegios de admin para instalar choco ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) {
    Write-Host "[WARN] PowerShell no se está ejecutando como Administrador. Algunas instalaciones pueden fallar." -ForegroundColor Yellow
}

# --- Flujo principal: verificar choco y abrir interfaz ---
if (-not (Ensure-Chocolatey)) {
    Write-Host "[EXIT] No se puede continuar sin Chocolatey." -ForegroundColor Red
    return
}
Write-Host "[OK] Preparando interfaz gráfica..." -ForegroundColor Green

# 1) Crear el formulario ANTES de usar .Controls
$formPrincipal = Create-Form -Title "Daniel Tools v$version" -Size (New-Object System.Drawing.Size(300, 600)) -BackColor ([System.Drawing.Color]::White)

# 2) Crear y agregar controles
# Título
$lblTitulo = Create-Label -Text "YT-DLP GUI (ALFA)" -Location (New-Object System.Drawing.Point(20,20)) -Size (New-Object System.Drawing.Size(260, 30)) -ForeColor ([System.Drawing.Color]::Black) -Font $boldFont
$formPrincipal.Controls.Add($lblTitulo)

# Cambios
$lblCambios = Create-Label -Text $global:defaultInstructions -Location (New-Object System.Drawing.Point(20,60)) -Size (New-Object System.Drawing.Size(260, 80)) -ForeColor ([System.Drawing.Color]::Black) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle) -TextAlign ([System.Drawing.ContentAlignment]::TopLeft)
$formPrincipal.Controls.Add($lblCambios)
Write-Host "[OK] Label 'CAMBIOS' agregado a la interfaz." -ForegroundColor Green

# Estado de herramientas
$lblYtDlp  = Create-Label -Text "yt-dlp: verificando..." -Location (New-Object System.Drawing.Point(20, 210)) -Size (New-Object System.Drawing.Size(260, 25))
$formPrincipal.Controls.Add($lblYtDlp)

$lblFfmpeg = Create-Label -Text "FFmpeg: verificando..." -Location (New-Object System.Drawing.Point(20, 240)) -Size (New-Object System.Drawing.Size(260, 25))
$formPrincipal.Controls.Add($lblFfmpeg)

# Botón Salir (una sola vez)
$btnExit = Create-Button -Text "Salir" -Location (New-Object System.Drawing.Point(20,160)) -Size (New-Object System.Drawing.Size(120, 35))
$btnExit.Add_Click({
    Write-Host "[UI] Cierre solicitado por el usuario." -ForegroundColor DarkYellow
    $formPrincipal.Close()
})
$formPrincipal.Controls.Add($btnExit)

# 3) Eventos del formulario
$formPrincipal.Add_Shown({
    try {
        Check-Tool -Display 'yt-dlp' -Exe 'yt-dlp' -ChocoPkg 'yt-dlp' -Label $lblYtDlp
        Check-Tool -Display 'FFmpeg' -Exe 'ffmpeg' -ChocoPkg 'ffmpeg' -Label $lblFfmpeg
    } catch {
        Write-Host "[ERROR] Falló la validación de herramientas: $_" -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            "Ocurrió un error al validar las herramientas.`n$_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

# 4) Mostrar el formulario
Write-Host "[RUN] Mostrando la interfaz..." -ForegroundColor Cyan
$formPrincipal.ShowDialog() | Out-Null
Write-Host "[END] Interfaz cerrada." -ForegroundColor DarkCyan
