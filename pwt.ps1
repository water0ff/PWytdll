# Crear la carpeta 'C:\Temp' si no existe
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
    Write-Host "Carpeta 'C:\Temp' creada correctamente."
}
$iconDir = "C:\Temp\icos"
if (-not (Test-Path $iconDir)) {
    New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
    Write-Host "Carpeta de íconos creada: $iconDir"
}
# Mostrar advertencia ALFA y solicitar confirmación
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
    Write-Host "`nEjecución cancelada por el usuario.`n" -ForegroundColor Red
    exit
}
Clear-Host
$global:defaultInstructions = @"
----- CAMBIOS -----
- Primer versión
"@
Write-Host "El usuario aceptó los riesgos. Corriendo programa..." -ForegroundColor Green
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Crear el formulario
$formPrincipal = New-Object System.Windows.Forms.Form
$formPrincipal.Size = New-Object System.Drawing.Size(300, 600)
$formPrincipal.StartPosition = "CenterScreen"
$formPrincipal.BackColor = [System.Drawing.Color]::White
$formPrincipal.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$formPrincipal.MaximizeBox = $false
$formPrincipal.MinimizeBox = $false
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$boldFont    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$version = "Alfa 251109.1223"
$formPrincipal.Text = "Daniel Tools v$version"

Write-Host "`n=============================================" -ForegroundColor DarkCyan
Write-Host "                   YTDLL                       " -ForegroundColor Green
Write-Host "              Versión: v$($version)               " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor DarkCyan

# Creación maestra de botones
$toolTip = New-Object System.Windows.Forms.ToolTip
function Create-Button {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::White,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black,
        [string]$ToolTipText = $null,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(220, 35)),
        [System.Drawing.Font]$Font = $defaultFont,
        [bool]$Enabled = $true
    )
    $buttonStyle = @{
        FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
        Font      = $defaultFont
    }
    $button_MouseEnter = {
        $this.BackColor = [System.Drawing.Color]::FromArgb(200, 200, 255)
        $this.Font = $boldFont
    }
    $button_MouseLeave = {
        $this.BackColor = $this.Tag
        $this.Font = $defaultFont
    }
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = $Size
    $button.Location = $Location
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.Font = $Font
    $button.FlatStyle = $buttonStyle.FlatStyle
    $button.Tag = $BackColor
    $button.Add_MouseEnter($button_MouseEnter)
    $button.Add_MouseLeave($button_MouseLeave)
    $button.Enabled = $Enabled
    if ($ToolTipText) { $toolTip.SetToolTip($button, $ToolTipText) }
    if ($PSBoundParameters.ContainsKey('DialogResult')) { $button.DialogResult = $DialogResult }
    return $button
}

# Lo mismo pero para las labels
function Create-Label {
    param (
        [string]$Text,
        [System.Drawing.Point]$Location,
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::Transparent,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black,
        [string]$ToolTipText = $null,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(200, 30)),
        [System.Drawing.Font]$Font = $defaultFont,
        [System.Windows.Forms.BorderStyle]$BorderStyle = [System.Windows.Forms.BorderStyle]::None,
        [System.Drawing.ContentAlignment]$TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Size = $Size
    $label.Location = $Location
    $label.BackColor = $BackColor
    $label.ForeColor = $ForeColor
    $label.Font = $Font
    $label.BorderStyle = $BorderStyle
    $label.TextAlign = $TextAlign
    if ($ToolTipText) { $toolTip.SetToolTip($label, $ToolTipText) }
    return $label
}

function Create-Form {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter()][System.Drawing.Size]$Size = (New-Object System.Drawing.Size(350, 200)),
        [Parameter()][System.Windows.Forms.FormStartPosition]$StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen,
        [Parameter()][System.Windows.Forms.FormBorderStyle]$FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog,
        [Parameter()][bool]$MaximizeBox = $false,
        [Parameter()][bool]$MinimizeBox = $false,
        [Parameter()][bool]$TopMost = $false,
        [Parameter()][bool]$ControlBox = $true,
        [Parameter()][System.Drawing.Icon]$Icon = $null,
        [Parameter()][System.Drawing.Color]$BackColor = [System.Drawing.SystemColors]::Control
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = $Title
    $form.Size            = $Size
    $form.StartPosition   = $StartPosition
    $form.FormBorderStyle = $FormBorderStyle
    $form.MaximizeBox     = $MaximizeBox
    $form.MinimizeBox     = $MinimizeBox
    $form.TopMost     = $TopMost
    $form.ControlBox  = $ControlBox
    if ($Icon) { $form.Icon = $Icon }
    $form.BackColor = $BackColor
    return $form
}

function Create-ComboBox {
    param (
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(200, 30)),
        [System.Windows.Forms.ComboBoxStyle]$DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList,
        [System.Drawing.Font]$Font = $defaultFont,
        [string[]]$Items = @(),
        [int]$SelectedIndex = -1,
        [string]$DefaultText = $null
    )
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = $Location
    $comboBox.Size = $Size
    $comboBox.DropDownStyle = $DropDownStyle
    $comboBox.Font = $Font
    if ($Items.Count -gt 0) {
        $comboBox.Items.AddRange($Items)
        $comboBox.SelectedIndex = $SelectedIndex
    }
    if ($DefaultText) { $comboBox.Text = $DefaultText }
    return $comboBox
}

function Create-TextBox {
    param (
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(200, 30)),
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::White,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black,
        [System.Drawing.Font]$Font = $defaultFont,
        [string]$Text = "",
        [bool]$Multiline = $false,
        [System.Windows.Forms.ScrollBars]$ScrollBars = [System.Windows.Forms.ScrollBars]::None,
        [bool]$ReadOnly = $false,
        [bool]$UseSystemPasswordChar = $false
    )
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = $Location
    $textBox.Size = $Size
    $textBox.BackColor = $BackColor
    $textBox.ForeColor = $ForeColor
    $textBox.Font = $Font
    $textBox.Text = $Text
    $textBox.Multiline = $Multiline
    $textBox.ScrollBars = $ScrollBars
    $textBox.ReadOnly = $ReadOnly
    $textBox.WordWrap = $false
    if ($UseSystemPasswordChar) { $textBox.UseSystemPasswordChar = $true }
    return $textBox
}

# Función para verificar e instalar Chocolatey
function Check-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        $response = [System.Windows.Forms.MessageBox]::Show(
            "Chocolatey no está instalado. ¿Desea instalarlo ahora?",
            "Chocolatey no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($response -eq [System.Windows.Forms.DialogResult]::No) {
            Write-Host "`nEl usuario canceló la instalación de Chocolatey." -ForegroundColor Red
            return $false
        }
        Write-Host "`nInstalando Chocolatey..." -ForegroundColor Cyan
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Host "`nChocolatey se instaló correctamente." -ForegroundColor Green
            choco config set cacheLocation C:\Choco\cache | Out-Null
            [System.Windows.Forms.MessageBox]::Show(
                "Chocolatey se instaló correctamente y ha sido configurado. Por favor, reinicie PowerShell antes de continuar.",
                "Reinicio requerido",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            Stop-Process -Id $PID -Force
            return $false
        } catch {
            Write-Host "`nError al instalar Chocolatey: $_" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                "Error al instalar Chocolatey. Por favor, inténtelo manualmente.",
                "Error de instalación",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return $false
        }
    } else {
        Write-Host "`tChocolatey ya está instalado." -ForegroundColor Green
        return $true
    }
}

# ====== NUEVO: utilidades para validar yt-dlp y ffmpeg ======
function Get-ToolVersion {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [string]$ArgsForVersion = "--version",
        [ValidateSet("FirstLine","Raw")][string]$Parse = "FirstLine"
    )
    try {
        $cmd = Get-Command $Command -ErrorAction Stop
    } catch {
        return $null
    }
    try {
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $p.StartInfo.FileName = $cmd.Source
        $p.StartInfo.Arguments = $ArgsForVersion
        $p.StartInfo.RedirectStandardOutput = $true
        $p.StartInfo.RedirectStandardError  = $true   # <— IMPORTANTE
        $p.StartInfo.UseShellExecute = $false
        $p.StartInfo.CreateNoWindow  = $true
        [void]$p.Start()
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        $combined = ($stdout + "`n" + $stderr).Trim()

        if ($Parse -eq "FirstLine") {
            # Toma la primera línea no vacía
            return ($combined -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
        }
        return $combined
    } catch {
        return "Detectado pero no se obtuvo versión"
    }
}


function Ensure-Tool {
    param(
        [Parameter(Mandatory=$true)][string]$CommandName,
        [Parameter(Mandatory=$true)][string]$FriendlyName,
        [Parameter(Mandatory=$true)][string]$ChocoPkg,
        [Parameter(Mandatory=$true)][ref]$LabelRef,
        [string]$VersionArgs = "--version",             # <— nuevo
        [ValidateSet("FirstLine","Raw")][string]$Parse = "FirstLine"
    )
    $version = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse
    if (-not $version) {
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "$FriendlyName no está instalado. ¿Desea instalarlo ahora con Chocolatey?",
            "$FriendlyName no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($resp -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                Start-Process -FilePath "choco" -ArgumentList @("install", $ChocoPkg, "-y") -NoNewWindow -Wait
                $version = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse
                if (-not $version) { $version = "Instalado, versión no detectada" }
                $LabelRef.Value.Text = "$($FriendlyName): $version"
                $LabelRef.Value.ForeColor = [System.Drawing.Color]::ForestGreen
            } catch {
                $LabelRef.Value.Text = "$($FriendlyName): error al instalar"
                $LabelRef.Value.ForeColor = [System.Drawing.Color]::Red
                [System.Windows.Forms.MessageBox]::Show(
                    "No se pudo instalar $FriendlyName automáticamente.",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        } else {
            $LabelRef.Value.Text = "$($FriendlyName): no instalado"
            $LabelRef.Value.ForeColor = [System.Drawing.Color]::Red
        }
    } else {
        $LabelRef.Value.Text = "$($FriendlyName): $version"
        $LabelRef.Value.ForeColor = [System.Drawing.Color]::ForestGreen
    }
}


# ====== FIN utilidades nuevas ======

# Función para mostrar la barra de progreso (sin cambios)
function Show-ProgressBar {
    $sizeProgress = New-Object System.Drawing.Size(400, 150)
    $formProgress = Create-Form `
        -Title "Progreso" -Size $sizeProgress -StartPosition ([System.Windows.Forms.FormStartPosition]::CenterScreen) `
        -FormBorderStyle ([System.Windows.Forms.FormBorderStyle]::FixedDialog) -TopMost $true -ControlBox $false
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size = New-Object System.Drawing.Size(360, 20)
    $progressBar.Location = New-Object System.Drawing.Point(10, 50)
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $progressBar.Maximum = 100
    $type = $progressBar.GetType()
    $flags = [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance
    $type.GetField("DoubleBuffered", $flags).SetValue($progressBar, $true)

    $lblPercentage = New-Object System.Windows.Forms.Label
    $lblPercentage.Location = New-Object System.Drawing.Point(10, 20)
    $lblPercentage.Size = New-Object System.Drawing.Size(360, 20)
    $lblPercentage.Text = "0% Completado"
    $lblPercentage.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $formProgress.Controls.Add($progressBar)
    $formProgress.Controls.Add($lblPercentage)
    $formProgress | Add-Member -MemberType NoteProperty -Name ProgressBar -Value $progressBar -Force
    $formProgress | Add-Member -MemberType NoteProperty -Name Label -Value $lblPercentage -Force
    $formProgress.Show()
    return $formProgress
}
function Update-ProgressBar { param($ProgressForm, $CurrentStep, $TotalSteps)
    $percent = [math]::Round(($CurrentStep / $TotalSteps) * 100)
    if (-not $ProgressForm.IsDisposed) {
        $ProgressForm.ProgressBar.Value = $percent
        $ProgressForm.Label.Text = "$percent% Completado"
        [System.Windows.Forms.Application]::DoEvents()
    }
}
function Close-ProgressBar { param($ProgressForm) $ProgressForm.Close() }







# ======                                                                                                 NUEVO: URL + acciones ======
# estado de consulta
$script:videoConsultado = $false
$script:ultimaURL = $null
$script:ultimoTitulo = $null

# etiqueta y caja de texto para URL
$lblUrl = Create-Label -Text "URL de YouTube:" -Location (New-Object System.Drawing.Point(20, 305)) -Size (New-Object System.Drawing.Size(260, 22)) -Font $boldFont
$txtUrl = Create-TextBox -Location (New-Object System.Drawing.Point(20, 330)) -Size (New-Object System.Drawing.Size(260, 26))

# etiqueta de estado de la consulta
$lblEstadoConsulta = Create-Label -Text "Estado: sin consultar" -Location (New-Object System.Drawing.Point(20, 360)) -Size (New-Object System.Drawing.Size(260, 22)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)

# botones
$btnConsultar = Create-Button -Text "Consultar" -Location (New-Object System.Drawing.Point(20, 390)) -Size (New-Object System.Drawing.Size(120, 35)) -BackColor ([System.Drawing.Color]::White) -ForeColor ([System.Drawing.Color]::Black) -ToolTipText "Obtener información del video"
$btnDescargar = Create-Button -Text "Descargar versión seleccionada" -Location (New-Object System.Drawing.Point(20, 435)) -Size (New-Object System.Drawing.Size(260, 35)) -BackColor ([System.Drawing.Color]::Black) -ForeColor ([System.Drawing.Color]::White) -ToolTipText "Descargar usando bestvideo+bestaudio -> mp4"
$btnDescargar.Enabled = $false

# Controles de URL y acciones
$formPrincipal.Controls.Add($lblUrl)
$formPrincipal.Controls.Add($txtUrl)
$formPrincipal.Controls.Add($lblEstadoConsulta)
$formPrincipal.Controls.Add($btnConsultar)
$formPrincipal.Controls.Add($btnDescargar)

# ====== NUEVO: lógica Consultar y Descargar ======

# Utilidad segura para invocar un ejecutable y capturar salida y código de retorno
function Invoke-Capture {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [string[]]$Args = @()
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.Arguments = (($Args | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ ExitCode = $p.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

# Botón: Consultar
$btnConsultar.Add_Click({
    $url = $txtUrl.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($url)) {
        [System.Windows.Forms.MessageBox]::Show("Escribe una URL de YouTube.", "Falta URL",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }
    try {
        $yt = Get-Command yt-dlp -ErrorAction Stop
    } catch {
        [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible. Valídalo en Dependencias.", "yt-dlp no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    # intentamos obtener título (validación suave de la URL)
    $res = Invoke-Capture -ExePath $yt.Source -Args @("--no-playlist","--get-title",$url)
    $titulo = ($res.StdOut + "`n" + $res.StdErr).Trim() -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1

    if ($res.ExitCode -eq 0 -and $titulo) {
        $script:videoConsultado = $true
        $script:ultimaURL = $url
        $script:ultimoTitulo = $titulo
        $lblEstadoConsulta.Text = "Consultado: $titulo"
        $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::ForestGreen
        $btnDescargar.Enabled = $true
    } else {
        $script:videoConsultado = $false
        $script:ultimaURL = $null
        $script:ultimoTitulo = $null
        $lblEstadoConsulta.Text = "Error al consultar la URL"
        $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::Red
        $btnDescargar.Enabled = $false
        [System.Windows.Forms.MessageBox]::Show(
            "No se pudo consultar el video. Revisa la URL o tu conexión.",
            "Consulta fallida",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

# Botón: Descargar versión seleccionada (por omisión)
$btnDescargar.Add_Click({
    if (-not $script:videoConsultado -or [string]::IsNullOrWhiteSpace($script:ultimaURL)) {
        [System.Windows.Forms.MessageBox]::Show("Primero usa 'Consultar' para validar la URL.", "Requisito: Consultar",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    try {
        $yt = Get-Command yt-dlp -ErrorAction Stop
    } catch {
        [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible. Valídalo en Dependencias.", "yt-dlp no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    # Descarga con el formato por omisión solicitado
    $args = @("-f","bestvideo+bestaudio","--merge-output-format","mp4",$script:ultimaURL)

    # (Opcional) mostrar progreso con tu barra si quieres más adelante
    $resultado = Invoke-Capture -ExePath $yt.Source -Args $args

    if ($resultado.ExitCode -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Descarga finalizada:`n$($script:ultimoTitulo)",
            "Completado",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Falló la descarga. Revisa conexión/URL/DRM. Detalle:`n$($resultado.StdErr)",
            "Error de descarga",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})















# --- Botón Salir usando Create-Button ---
$btnExit = Create-Button -Text "Salir" -Location (New-Object System.Drawing.Point(20, 170)) -BackColor ([System.Drawing.Color]::Black) -ForeColor ([System.Drawing.Color]::White) `
    -ToolTipText "Cerrar la aplicación" -Size (New-Object System.Drawing.Size(120, 35)) -Font $defaultFont

# --- Label "CAMBIOS" usando Create-Label ---
$lblCambios = Create-Label -Text $global:defaultInstructions -Location (New-Object System.Drawing.Point(20, 60)) -Size (New-Object System.Drawing.Size(260, 100)) `
    -BackColor ([System.Drawing.Color]::Transparent) -ForeColor ([System.Drawing.Color]::Black) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle) `
    -TextAlign ([System.Drawing.ContentAlignment]::TopLeft)
$lblCambios.AutoSize = $false
$lblCambios.UseCompatibleTextRendering = $true

# ====== NUEVO: labels para versiones ======
$lblTituloDeps = Create-Label -Text "Dependencias:" -Location (New-Object System.Drawing.Point(20, 210)) -Size (New-Object System.Drawing.Size(260, 24)) -Font $boldFont
$lblYtDlp      = Create-Label -Text "yt-dlp: verificando..." -Location (New-Object System.Drawing.Point(20, 240)) -Size (New-Object System.Drawing.Size(260, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$lblFfmpeg     = Create-Label -Text "ffmpeg: verificando..." -Location (New-Object System.Drawing.Point(20, 270)) -Size (New-Object System.Drawing.Size(260, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)

# Agregar controles (incluye el botón Salir que antes no se agregaba)
$formPrincipal.Controls.Add($lblCambios)
$formPrincipal.Controls.Add($btnExit)
$formPrincipal.Controls.Add($lblTituloDeps)
$formPrincipal.Controls.Add($lblYtDlp)
$formPrincipal.Controls.Add($lblFfmpeg)

# --- Validación de Chocolatey y dependencias al iniciar la UI ---
$formPrincipal.Add_Shown({
    try {
        if (-not (Check-Chocolatey)) {
            $formPrincipal.Close()
            return
        }

        # Validar/instalar yt-dlp y ffmpeg (con MessageBox si faltan)
        Ensure-Tool -CommandName "yt-dlp" -FriendlyName "yt-dlp" -ChocoPkg "yt-dlp" -LabelRef ([ref]$lblYtDlp) -VersionArgs "--version"
        # ffmpeg imprime mucho; usamos "-version" y tomamos primera línea
        $lblFfmpeg.Text = "ffmpeg: verificando..."
        Ensure-Tool -CommandName "ffmpeg" -FriendlyName "ffmpeg" -ChocoPkg "ffmpeg" -LabelRef ([ref]$lblFfmpeg) -VersionArgs "-version"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error al validar dependencias:`n$_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $formPrincipal.Close()
    }
})

# Botón para salir
$btnExit.Add_Click({
    $formPrincipal.Dispose()
    $formPrincipal.Close()
})

$formPrincipal.Refresh()
$formPrincipal.ShowDialog()
