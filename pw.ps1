#requires -version 5.1
# ============================================
# YT-DLP GUI Bootstrap - Daniel Tools
# ============================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Utils de consola
function Log([string]$msg, [ConsoleColor]$color = [ConsoleColor]::White) {
    Write-Host $msg -ForegroundColor $color
}

# --- Crear carpetas base
if (!(Test-Path -Path "C:\Temp")) { New-Item -ItemType Directory -Path "C:\Temp" | Out-Null; Log "[OK] Carpeta 'C:\Temp' creada." Green } else { Log "[OK] Carpeta 'C:\Temp' existente." DarkGreen }
$iconDir = "C:\Temp\icos"
if (-not (Test-Path $iconDir)) { New-Item -ItemType Directory -Path $iconDir -Force | Out-Null; Log "[OK] Carpeta de íconos creada: $iconDir" Green } else { Log "[OK] Carpeta de íconos existente: $iconDir" DarkGreen }

# --- Advertencia ALFA
Log "`n==============================================" Red
Log "           ADVERTENCIA DE VERSIÓN ALFA          " Red
Log "==============================================" Red
Log "Esta aplicación se encuentra en fase de desarrollo ALFA.`n" Yellow
Log "¿Acepta ejecutar esta aplicación bajo su propia responsabilidad? (Y/N)" Yellow
$response = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
while ($response.Character -notin 'Y','N') { $response = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') }
if ($response.Character -ne 'Y') { Log "`n[ABORT] Ejecución cancelada por el usuario.`n" Red; exit }
Clear-Host
Log "[OK] El usuario aceptó los riesgos. Corriendo programa..." Green

# --- Variables globales
$global:defaultInstructions = @"
----- CAMBIOS -----
- Primer versión
"@
$version     = "Alfa 251109.1123"
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$boldFont    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

Log "`n=============================================" DarkCyan
Log "                   YTDLL                       " Green
Log "              Versión: v$($version)               " Green
Log "=============================================" DarkCyan

# --- UI helpers
function Create-Form {
    param([string]$Title,[System.Drawing.Size]$Size=(New-Object System.Drawing.Size(340, 360)))
    $f = New-Object System.Windows.Forms.Form
    $f.Text=$Title; $f.Size=$Size; $f.StartPosition='CenterScreen'
    $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false; $f.MinimizeBox=$false
    $f.BackColor=[System.Drawing.Color]::White
    return $f
}
function Create-Label {
    param([string]$Text,[int]$x,[int]$y,[int]$w=280,[int]$h=24,[System.Drawing.Font]$Font=$defaultFont)
    $l = New-Object System.Windows.Forms.Label
    $l.Text=$Text; $l.Location=New-Object System.Drawing.Point($x,$y); $l.Size=New-Object System.Drawing.Size($w,$h)
    $l.Font=$Font; $l.AutoSize=$false; $l.UseCompatibleTextRendering=$true
    return $l
}
function Create-Button {
    param([string]$Text,[int]$x,[int]$y,[int]$w=120,[int]$h=35)
    $b = New-Object System.Windows.Forms.Button
    $b.Text=$Text; $b.Location=New-Object System.Drawing.Point($x,$y); $b.Size=New-Object System.Drawing.Size($w,$h)
    $b.Font=$defaultFont
    return $b
}

# --- Progreso simple (para installs/updates vía choco)
function Show-ProgressBar {
    $form = Create-Form -Title "Progreso"
    $form.Size = New-Object System.Drawing.Size(420,150)
    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Location=New-Object System.Drawing.Point(20,60); $bar.Size=New-Object System.Drawing.Size(360,20)
    $bar.Style=[System.Windows.Forms.ProgressBarStyle]::Continuous; $bar.Maximum=100
    $lbl = Create-Label -Text "0% Completado" -x 20 -y 20 -w 360 -h 24
    $lbl.TextAlign=[System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.AddRange(@($lbl,$bar))
    $form | Add-Member NoteProperty ProgressBar $bar -Force
    $form | Add-Member NoteProperty Label $lbl -Force
    $form.TopMost=$true; $form.ControlBox=$false
    $form.Show(); return $form
}
function Update-ProgressBar($pf,$curr,$total){ $p=[math]::Round(($curr/$total)*100); if(-not $pf.IsDisposed){$pf.ProgressBar.Value=$p; $pf.Label.Text="$p% Completado"; [System.Windows.Forms.Application]::DoEvents() } }
function Close-ProgressBar($pf){ if($pf -and -not $pf.IsDisposed){ $pf.Close() } }

# --- Chocolatey
function Install-Chocolatey {
    try{
        Log "[CHOCOLATEY] Iniciando instalación..." Cyan
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        choco config set cacheLocation C:\Choco\cache | Out-Null
        Log "[CHOCOLATEY] Instalación y configuración completadas." Green
        return $true
    } catch {
        Log "[ERROR] Falló la instalación de Chocolatey: $_" Red
        return $false
    }
}
function Ensure-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) { Log "[OK] Chocolatey detectado." Green; return $true }
    $ans=[System.Windows.Forms.MessageBox]::Show("Chocolatey es requerido. ¿Desea instalarlo ahora?","Chocolatey no encontrado",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
    if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ Log "[ABORT] Usuario rechazó instalar Chocolatey." Red; return $false }
    $p=Show-ProgressBar; Update-ProgressBar $p 1 4
    $ok=Install-Chocolatey
    Update-ProgressBar $p 4 4; Close-ProgressBar $p
    if(-not $ok){ [System.Windows.Forms.MessageBox]::Show("Error al instalar Chocolatey.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return $false }
    [System.Windows.Forms.MessageBox]::Show("Chocolatey instalado correctamente.","Listo",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    return $true
}

# --- Versionado de herramientas
function Get-ExeVersion {
    param([string]$Exe,[ValidateSet('yt-dlp','ffmpeg')]$Mode)
    try{
        if(-not (Get-Command $Exe -ErrorAction SilentlyContinue)){ return $null }
        switch($Mode){
            'yt-dlp' {
                $v = & $Exe --version 2>$null
                if([string]::IsNullOrWhiteSpace($v)){ return $null }
                return ($v.Trim())
            }
            'ffmpeg' {
                $line = (& $Exe -version 2>$null | Select-Object -First 1)
                # Ej: "ffmpeg version 7.0.2-essentials_build ..."
                if($line -match 'ffmpeg version ([^\s]+)'){ return $matches[1] }
                return $null
            }
        }
    } catch { return $null }
}

function Get-ChocoInstalledVersion {
    param([string]$PackageId)
    try{
        $out = choco list --local-only --exact --limit-output $PackageId 2>$null
        # Formato: package|version
        if($out -match '^\s*'+[regex]::Escape($PackageId)+'\|(.+)$'){ return $matches[1].Trim() }
        return $null
    } catch { return $null }
}

function Get-ChocoLatestVersion {
    param([string]$PackageId)
    try{
        $out = choco search $PackageId --exact --by-id-only -r 2>$null
        # Formato: package|latestVersion
        if($out -match '^\s*'+[regex]::Escape($PackageId)+'\|(.+)$'){ return $matches[1].Trim() }
        return $null
    } catch { return $null }
}

function Is-PackageOutdated {
    param([string]$PackageId)
    try{
        $out = choco outdated -r 2>$null
        # Filas: id|current|available|pinned?
        foreach($line in ($out -split "`r?`n")){
            if($line -match '^\s*'+[regex]::Escape($PackageId)+'\|'){ return $true }
        }
        return $false
    } catch { return $false }
}

function Ensure-Tool {
    param(
        [ValidateSet('yt-dlp','ffmpeg')]$Tool,
        [string]$ExeName,
        [string]$ChocoId,
        [System.Windows.Forms.Label]$TargetLabel
    )
    Log "[CHECK] Validando $Tool..." Cyan
    $exeVersion = Get-ExeVersion -Exe $ExeName -Mode $Tool
    $installedViaChocoVersion = Get-ChocoInstalledVersion -PackageId $ChocoId
    $latest = Get-ChocoLatestVersion -PackageId $ChocoId
    $outdated = Is-PackageOutdated -PackageId $ChocoId

    if($null -eq $exeVersion){
        Log "[MISS] $Tool no está instalado (no se encontró '$ExeName')." Yellow
        $TargetLabel.Text = "$Tool: no instalado"
        $ans=[System.Windows.Forms.MessageBox]::Show("$Tool no está instalado. ¿Desea instalarlo ahora con Chocolatey?","$Tool requerido",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
        if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ Log "[ABORT] Usuario canceló instalación de $Tool." Red; return }
        Log "[CHOCOLATEY] Instalando $Tool (choco install $ChocoId -y)..." Cyan
        choco install $ChocoId -y
        # Releer versión
        $exeVersion = Get-ExeVersion -Exe $ExeName -Mode $Tool
        if($exeVersion){ Log "[OK] $Tool instalado. Versión: $exeVersion" Green; $TargetLabel.Text="$Tool: $exeVersion (instalado)"; }
        else { Log "[ERROR] No se detectó $Tool después de instalar." Red; $TargetLabel.Text="$Tool: error al instalar"; }
        return
    }

    # Instalado
    Log "[OK] $Tool detectado. Versión ejecutable: $exeVersion" Green

    if($installedViaChocoVersion){ Log "[INFO] Versión en Chocolatey (local): $installedViaChocoVersion" DarkGreen }
    if($latest){ Log "[INFO] Versión disponible (repos): $latest" DarkGreen }

    if($outdated -and $latest){
        $TargetLabel.Text = "$Tool: $exeVersion (desactualizado → $latest)"
        $ans=[System.Windows.Forms.MessageBox]::Show("$Tool está desactualizado ($exeVersion → $latest). ¿Actualizar ahora?","Actualizar $Tool",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information)
        if($ans -eq [System.Windows.Forms.DialogResult]::Yes){
            Log "[CHOCOLATEY] Actualizando $Tool (choco upgrade $ChocoId -y)..." Cyan
            choco upgrade $ChocoId -y
            $exeVersion = Get-ExeVersion -Exe $ExeName -Mode $Tool
            if($exeVersion){ Log "[OK] Actualizado $Tool a $exeVersion" Green; $TargetLabel.Text="$Tool: $exeVersion (actualizado)" }
            else { Log "[WARN] No se pudo determinar versión tras actualizar $Tool." Yellow }
        } else {
            Log "[SKIP] Usuario decidió no actualizar $Tool." DarkYellow
        }
    } else {
        $TargetLabel.Text = "$Tool: $exeVersion (actualizado)"
    }
}

# --- Verificar privilegios admin (recomendado para choco)
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) { Log "[WARN] No estás en PowerShell (Admin). Algunas instalaciones/actualizaciones pueden fallar." Yellow }

# --- Asegurar Chocolatey antes de UI
if (-not (Ensure-Chocolatey)) { Log "[EXIT] Sin Chocolatey no se puede continuar." Red; return }

# --- UI principal
$form = Create-Form -Title "Daniel Tools v$version"

$lblTitulo   = Create-Label -Text "YT-DLP GUI (ALFA)" -x 20 -y 16 -w 300 -h 26 -Font $boldFont
$lblCambios  = Create-Label -Text $global:defaultInstructions -x 20 -y 50 -w 300 -h 70
$lblYtTitle  = Create-Label -Text "yt-dlp:" -x 20 -y 130 -w 80 -h 22 -Font $boldFont
$lblYtVer    = Create-Label -Text "Detectando..." -x 100 -y 130 -w 210 -h 22
$lblFfTitle  = Create-Label -Text "ffmpeg:" -x 20 -y 160 -w 80 -h 22 -Font $boldFont
$lblFfVer    = Create-Label -Text "Detectando..." -x 100 -y 160 -w 210 -h 22

$btnRevisar  = Create-Button -Text "Revisar dependencias" -x 20 -y 200 -w 180 -h 34
$btnExit     = Create-Button -Text "Salir" -x 220 -y 200 -w 80 -h 34

$form.Controls.AddRange(@($lblTitulo,$lblCambios,$lblYtTitle,$lblYtVer,$lblFfTitle,$lblFfVer,$btnRevisar,$btnExit))

# --- Acciones
$btnExit.Add_Click({ Log "[UI] Cierre solicitado por el usuario." DarkYellow; $form.Close() })

$checkDeps = {
    try{
        Log "[RUN] Revisando dependencias (yt-dlp / ffmpeg)..." Cyan
        Ensure-Tool -Tool 'yt-dlp' -ExeName 'yt-dlp' -ChocoId 'yt-dlp' -TargetLabel $lblYtVer
        Ensure-Tool -Tool 'ffmpeg' -ExeName 'ffmpeg' -ChocoId 'ffmpeg' -TargetLabel $lblFfVer
        Log "[DONE] Revisión de dependencias finalizada." DarkCyan
    } catch {
        Log "[ERROR] Falla en revisión de dependencias: $_" Red
    }
}

$btnRevisar.Add_Click($checkDeps)

# Ejecutar revisión automáticamente al mostrar la ventana (para que alcance a dibujar primero)
$form.Add_Shown({ $form.Activate(); Start-Sleep -Milliseconds 100; & $checkDeps })

# Mostrar UI
Log "[RUN] Mostrando interfaz..." Cyan
[void]$form.ShowDialog()
Log "[END] Interfaz cerrada." DarkCyan
