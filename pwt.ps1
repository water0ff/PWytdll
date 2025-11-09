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
# Forzar UTF-8 en PowerShell y en procesos hijos (Python/yt-dlp)
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
} catch {}

$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
chcp 65001 | Out-Null               # Forzar code page de consola a UTF-8
$env:PYTHONUTF8 = '1'               # Python/yt-dlp en modo UTF-8
$PSStyle.OutputRendering = 'Ansi'   # Evita rarezas con ANSI/UTF-8 en PS 7+
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
- Ahora se debe tener una carpeta preconfigurada de destino, por omisión se usa el Escritorio.
- Ahora permite que selecciones los formatos para video y audio.
- Se agrega la opción para actualizar y desinstalar dependencias.
- Se agregó vista previa del video.
- Se agregó detalles de progreso de descarga en consola.
- Se agregó dependencia Node.
- Se agregó validar consulta de video para descargar.
"@
Write-Host "El usuario aceptó los riesgos. Corriendo programa..." -ForegroundColor Green

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Crear el formulario
$formPrincipal = New-Object System.Windows.Forms.Form
$formPrincipal.Size = New-Object System.Drawing.Size(400, 800)
$formPrincipal.StartPosition = "CenterScreen"
$formPrincipal.BackColor = [System.Drawing.Color]::White
$formPrincipal.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$formPrincipal.MaximizeBox = $false
$formPrincipal.MinimizeBox = $false
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$boldFont    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                                                                                                        $version = "Alfa 251109.1500"
$formPrincipal.Text = ("YTDLL v{0}" -f $version)

Write-Host "`n=============================================" -ForegroundColor DarkCyan
Write-Host "                   YTDLL                       " -ForegroundColor Green
Write-Host ("              Versión: v{0}" -f $version) -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor DarkCyan

# Tooltip y fábricas de controles
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
    $buttonStyle = @{ FlatStyle = [System.Windows.Forms.FlatStyle]::Standard; Font = $defaultFont }
    $button_MouseEnter = { $this.BackColor = [System.Drawing.Color]::FromArgb(200,200,255); $this.Font = $boldFont }
    $button_MouseLeave = { $this.BackColor = $this.Tag; $this.Font = $defaultFont }
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
    return $button
}
function Create-Label {
    param(
        [string]$Text,[System.Drawing.Point]$Location,
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::Transparent,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black,
        [string]$ToolTipText = $null,[System.Drawing.Size]$Size = (New-Object System.Drawing.Size(200, 30)),
        [System.Drawing.Font]$Font = $defaultFont,
        [System.Windows.Forms.BorderStyle]$BorderStyle = [System.Windows.Forms.BorderStyle]::None,
        [System.Drawing.ContentAlignment]$TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text; $label.Size = $Size; $label.Location = $Location
    $label.BackColor = $BackColor; $label.ForeColor = $ForeColor; $label.Font = $Font
    $label.BorderStyle = $BorderStyle; $label.TextAlign = $TextAlign
    if ($ToolTipText) { $toolTip.SetToolTip($label, $ToolTipText) }
    return $label
}
function Create-Form {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter()][System.Drawing.Size]$Size = (New-Object System.Drawing.Size(350,200)),
        [Parameter()][System.Windows.Forms.FormStartPosition]$StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen,
        [Parameter()][System.Windows.Forms.FormBorderStyle]$FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog,
        [Parameter()][bool]$MaximizeBox = $false,[Parameter()][bool]$MinimizeBox = $false,
        [Parameter()][bool]$TopMost = $false,[Parameter()][bool]$ControlBox = $true,
        [Parameter()][System.Drawing.Icon]$Icon = $null,
        [Parameter()][System.Drawing.Color]$BackColor = [System.Drawing.SystemColors]::Control
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text=$Title; $form.Size=$Size; $form.StartPosition=$StartPosition
    $form.FormBorderStyle=$FormBorderStyle; $form.MaximizeBox=$MaximizeBox; $form.MinimizeBox=$MinimizeBox
    $form.TopMost=$TopMost; $form.ControlBox=$ControlBox
    if ($Icon) { $form.Icon = $Icon }
    $form.BackColor = $BackColor
    return $form
}
function Create-ComboBox {
    param(
        [System.Drawing.Point]$Location,[System.Drawing.Size]$Size = (New-Object System.Drawing.Size(200,30)),
        [System.Windows.Forms.ComboBoxStyle]$DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList,
        [System.Drawing.Font]$Font = $defaultFont,[string[]]$Items = @(),[int]$SelectedIndex = -1,[string]$DefaultText = $null
    )
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = $Location; $comboBox.Size = $Size
    $comboBox.DropDownStyle = $DropDownStyle; $comboBox.Font = $Font
    if ($Items.Count -gt 0) { $comboBox.Items.AddRange($Items); $comboBox.SelectedIndex = $SelectedIndex }
    if ($DefaultText) { $comboBox.Text = $DefaultText }
    return $comboBox
}
function Create-TextBox {
    param(
        [System.Drawing.Point]$Location,[System.Drawing.Size]$Size = (New-Object System.Drawing.Size(200,30)),
        [System.Drawing.Color]$BackColor=[System.Drawing.Color]::White,[System.Drawing.Color]$ForeColor=[System.Drawing.Color]::Black,
        [System.Drawing.Font]$Font=$defaultFont,[string]$Text="",[bool]$Multiline=$false,
        [System.Windows.Forms.ScrollBars]$ScrollBars=[System.Windows.Forms.ScrollBars]::None,
        [bool]$ReadOnly=$false,[bool]$UseSystemPasswordChar=$false
    )
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location=$Location; $textBox.Size=$Size; $textBox.BackColor=$BackColor; $textBox.ForeColor=$ForeColor
    $textBox.Font=$Font; $textBox.Text=$Text; $textBox.Multiline=$Multiline; $textBox.ScrollBars=$ScrollBars; $textBox.ReadOnly=$ReadOnly
    $textBox.WordWrap=$false; if ($UseSystemPasswordChar) { $textBox.UseSystemPasswordChar = $true }
    return $textBox
}
# 1) SOLO pinta el botón de descarga
function Set-DownloadButtonVisual {
    param([bool]$ok)
    if ($ok) {
        $btnDescargar.Enabled   = $true
        $btnDescargar.BackColor = [System.Drawing.Color]::ForestGreen
        $btnDescargar.ForeColor = [System.Drawing.Color]::White
        # Texto SIEMPRE fijo
        $btnDescargar.Text      = "Descargar"
        $toolTip.SetToolTip($btnDescargar, "Consulta válida: listo para descargar")
    } else {
        $btnDescargar.Enabled   = $false
        $btnDescargar.BackColor = [System.Drawing.Color]::Black
        $btnDescargar.ForeColor = [System.Drawing.Color]::White
        # Texto SIEMPRE fijo
        $btnDescargar.Text      = "Descargar"
        $toolTip.SetToolTip($btnDescargar, "Descarga deshabilitada: primero 'Consultar'")
    }
    # Mantén el Tag sincronizado para el hover
    $btnDescargar.Tag = $btnDescargar.BackColor
}

# 2) GATE DE DEPENDENCIAS (FUERA de la función anterior)
# --- ¿Node es obligatorio? (true = requerido; false = opcional)
$script:RequireNode = $true

function Test-CommandExists {
    param([Parameter(Mandatory=$true)][string]$Name)
    try { Get-Command $Name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Refresh-GateByDeps {
    # Reglas: yt-dlp y ffmpeg siempre requeridos; Node depende de $RequireNode
    $haveYt   = Test-CommandExists -Name "yt-dlp"
    $haveFfm  = Test-CommandExists -Name "ffmpeg"
    $haveNode = if ($script:RequireNode) { Test-CommandExists -Name "node" } else { $true }

    $allOk = $haveYt -and $haveFfm -and $haveNode

    # Bloquea/Desbloquea "Consultar"
    $btnConsultar.Enabled = $allOk
    if ($allOk) {
        $toolTip.SetToolTip($btnConsultar, "Obtener información del video")
    } else {
        $toolTip.SetToolTip($btnConsultar, "Deshabilitado: instala/activa dependencias")

        # Cascada: limpia consulta y bloquea "Descargar"
        $script:videoConsultado = $false
        $script:ultimaURL       = $null
        $script:ultimoTitulo    = $null
        Set-DownloadButtonVisual -ok:$false
        $lblEstadoConsulta.Text = "Estado: sin consultar"
        $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::Black
        if ($picPreview) { $picPreview.Image = $null }
    }

    # (Opcional) Bloquear edición de URL si faltan deps:
    # $txtUrl.ReadOnly = -not $allOk
}
# ====== [NUEVO] Estructuras para formatos ======
$script:formatsIndex = @{}   # format_id -> objeto con metadatos (tipo, codecs, label)
$script:formatsVideo = @()   # lista de objetos mostrables en Combo Video
$script:formatsAudio = @()   # lista de objetos mostrables en Combo Audio
$script:ExcludedFormatIds = @('18','22','95','96')

# Por compatibilidad PS5/7 evitamos ValueMember; guardamos Display con el format_id al inicio
function New-FormatDisplay {
    param(
        [string]$Id,[string]$Label
    )
    # Formato: "137 — mp4 1080p h264 (v-only) ~3.2MiB 2200k"
    return ("{0} — {1}" -f $Id, $Label)
}

# Detecta si un format (del JSON) es solo video, solo audio o progresivo
function Classify-Format {
    param($fmt)
    $v = $fmt.vcodec; $a = $fmt.acodec
    $isVideoOnly = $v -and $v -ne "none" -and ($a -eq $null -or $a -eq "" -or $a -eq "none")
    $isAudioOnly = $a -and $a -ne "none" -and ($v -eq $null -or $v -eq "" -or $v -eq "none")
    $isProgressive = $v -and $v -ne "none" -and $a -and $a -ne "none"
    [pscustomobject]@{
        VideoOnly     = [bool]$isVideoOnly
        AudioOnly     = [bool]$isAudioOnly
        Progressive   = [bool]$isProgressive
        Ext           = $fmt.ext
        VRes          = $fmt.height
        VCodec        = $fmt.vcodec
        ACodec        = $fmt.acodec
        ABr           = $fmt.abr
        Tbr           = $fmt.tbr
        Filesize      = $fmt.filesize
        FormatNote    = $fmt.format_note
        Id            = $fmt.format_id
    }
}

# Toma bytes y devuelve algo legible
function Human-Size {
    param([Nullable[long]]$bytes)
    if (-not $bytes -or $bytes -le 0) { return "" }
    $units = "B","KiB","MiB","GiB","TiB"
    $p = 0; $n = [double]$bytes
    while ($n -ge 1024 -and $p -lt $units.Count-1) { $n/=1024; $p++ }
    return ("{0:N1}{1}" -f $n, $units[$p])
}

# Imprime tabla tipo -F en consola
function Print-FormatsTable {
    param([array]$formats)  # array del JSON .formats
    Write-Host "`n[FORMATOS] Disponibles (similar a yt-dlp -F):" -ForegroundColor Cyan
    Write-Host ("{0,-9} {1,-5} {2,-10} {3,-7} {4,-9} {5}" -f "format_id","ext","res","vcodec","acodec","nota/tamaño/tbr") -ForegroundColor DarkGray
    foreach ($f in $formats) {
        $sz = Human-Size $f.filesize
        $tbr = if ($f.tbr) { "{0}k" -f [math]::Round($f.tbr) } else { "" }
        $res = if ($f.height) { "{0}p" -f $f.height } else { "" }
        $note = ($f.format_note ? $f.format_note : "")
        $extra = ($note, $sz, $tbr) -join " "
        Write-Host ("{0,-9} {1,-5} {2,-10} {3,-7} {4,-9} {5}" -f $f.format_id, $f.ext, $res, $f.vcodec, $f.acodec, $extra)
    }
}

# Obtiene y prepara formatos desde yt-dlp -J
function Fetch-Formats {
    param([Parameter(Mandatory=$true)][string]$Url)

    $script:formatsIndex.Clear()
    $script:formatsVideo = @()
    $script:formatsAudio = @()

    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
        Write-Host "[ERROR] yt-dlp no disponible para listar formatos." -ForegroundColor Red
        return $false
    }

    # Guardar/restaurar label por si el caller no lo hace (defensa)
    $prevLabel = $null
    if ($lblEstadoConsulta) {
        $prevLabel = $lblEstadoConsulta.Text
        $lblEstadoConsulta.Text = "Consultando formatos…"
    }

    try {
        $obj = Invoke-CaptureResponsive -ExePath $yt.Source -Args @("-J","--no-playlist",$Url) -WorkingText "Consultando formatos…"
        if ($obj.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($obj.StdOut)) {
            Write-Host "[ERROR] No se pudo obtener JSON de formatos." -ForegroundColor Red
            Write-Host $obj.StdErr
            return $false
        }

        try {
            $json = $obj.StdOut | ConvertFrom-Json
        } catch {
            Write-Host "[ERROR] JSON inválido al listar formatos." -ForegroundColor Red
            return $false
        }

        if (-not $json.formats) {
            Write-Host "[WARN] El extractor no devolvió lista de formatos." -ForegroundColor Yellow
            return $false
        }

        Print-FormatsTable -formats $json.formats

        foreach ($f in $json.formats) {
            $klass = Classify-Format $f
            $script:formatsIndex[$klass.Id] = $klass

            if ($klass.Progressive -and $script:ExcludedFormatIds -contains $klass.Id) { continue }

            $res = if ($klass.VRes) { "{0}p" -f $klass.VRes } else { "" }
            $sz  = Human-Size $klass.Filesize
            $tbr = if ($klass.Tbr) { "{0}k" -f [math]::Round($klass.Tbr) } else { "" }

            if ($klass.Progressive) {
                $label = "{0} {1} {2}/{3} (progresivo) {4} {5}" -f $klass.Ext,$res,$klass.VCodec,$klass.ACodec,$sz,$tbr
                $script:formatsVideo += (New-FormatDisplay -Id $klass.Id -Label $label)
            } elseif ($klass.VideoOnly) {
                $label = "{0} {1} {2} (v-only) {3} {4}" -f $klass.Ext,$res,$klass.VCodec,$sz,$tbr
                $script:formatsVideo += (New-FormatDisplay -Id $klass.Id -Label $label)
            } elseif ($klass.AudioOnly) {
                $label = "{0} ~{1} {2} (a-only) {3}" -f $klass.Ext, $klass.ABr, $klass.ACodec, $sz
                $script:formatsAudio += (New-FormatDisplay -Id $klass.Id -Label $label)
            }
        }

        $script:formatsVideo = @(
            "best — mejor calidad (progresivo si existe; si no, será adaptativo)",
            "bestvideo — mejor video (sin audio; usar con audio)"
        ) + $script:formatsVideo

        $script:formatsAudio = @(
            "bestaudio — mejor audio disponible"
        ) + $script:formatsAudio

        return $true
    } finally {
        if ($lblEstadoConsulta -and $prevLabel) {
            # NO dejar “Consultando formatos…”
            $lblEstadoConsulta.Text = $prevLabel
        }
    }
}


# Devuelve el format_id a partir del texto mostrado en combo
function Get-SelectedFormatId {
    param([System.Windows.Forms.ComboBox]$Combo)
    $t = ($Combo.SelectedItem | ForEach-Object { $_.ToString() })
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }
    # Si es 'best...' lo devolvemos tal cual
    if ($t -like "best*") { return ($t -split '\s')[0] } # "best" / "bestvideo" / "bestaudio"
    # Caso "137 — ..."
    return ($t -split '\s')[0]
}
# ================== [NUEVO] Botones de acciones por dependencia ==================
function Create-IconButton {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [string]$ToolTipText
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Size = New-Object System.Drawing.Size(26, 24) # compacto
    $btn.Location = $Location
    $btn.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 10, [System.Drawing.FontStyle]::Bold)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
    $btn.BackColor = [System.Drawing.Color]::White
    $btn.Tag = $btn.BackColor
    $btn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(220,230,255) })
    $btn.Add_MouseLeave({ $this.BackColor = $this.Tag })
    if ($ToolTipText) { $toolTip.SetToolTip($btn, $ToolTipText) }
    return $btn
}

function Refresh-DependencyLabel {
    param(
        [string]$CommandName,
        [string]$FriendlyName,
        [ref]$LabelRef,
        [string]$VersionArgs = "--version",
        [ValidateSet("FirstLine","Raw")][string]$Parse = "FirstLine"
    )
    $ver = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse
    if ($ver) {
        $LabelRef.Value.Text = ("{0}: {1}" -f $FriendlyName, $ver)
        $LabelRef.Value.ForeColor = [System.Drawing.Color]::ForestGreen
    } else {
        $LabelRef.Value.Text = ("{0}: no instalado" -f $FriendlyName)
        $LabelRef.Value.ForeColor = [System.Drawing.Color]::Red
    }
    Refresh-GateByDeps   # <-- NUEVO
}


function Update-Dependency {
    param(
        [string]$ChocoPkg,
        [string]$FriendlyName,
        [string]$CommandName,
        [ref]$LabelRef,
        [string]$VersionArgs = "--version",
        [ValidateSet("FirstLine","Raw")][string]$Parse = "FirstLine"
    )
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Chocolatey no está disponible. Instálalo para poder actualizar dependencias.",
            "Chocolatey requerido",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    Write-Host ("[UPDATE] Actualizando {0} con choco upgrade {1} -y" -f $FriendlyName, $ChocoPkg) -ForegroundColor Cyan
    try {
        Start-Process -FilePath "choco" -ArgumentList @("upgrade",$ChocoPkg,"-y") -Wait -NoNewWindow
        Refresh-DependencyLabel -CommandName $CommandName -FriendlyName $FriendlyName -LabelRef $LabelRef -VersionArgs $VersionArgs -Parse $Parse
        [System.Windows.Forms.MessageBox]::Show(
            ("{0} ha sido verificado/actualizado." -f $FriendlyName),
            "Actualización completada",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Write-Host ("[ERROR] Falló actualización de {0}: {1}" -f $FriendlyName, $_) -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            ("No se pudo actualizar {0}. Revisa la consola." -f $FriendlyName),
            "Error de actualización",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        Refresh-GateByDeps   # <-- re-evalúa y bloquea/habilita Consultar/Descargar
    }
}
function Uninstall-Dependency {
    param(
        [string]$ChocoPkg,
        [string]$FriendlyName,
        [ref]$LabelRef
    )
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Chocolatey no está disponible. Instálalo para poder desinstalar dependencias.",
            "Chocolatey requerido",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    $r = [System.Windows.Forms.MessageBox]::Show(
        ("¿Seguro que deseas desinstalar {0}?{1}{1}Esto podría requerir reiniciar PowerShell para refrescar el PATH." -f $FriendlyName, [Environment]::NewLine),
        "Confirmar desinstalación",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Write-Host ("[UNINSTALL] Desinstalando {0} con choco uninstall {1} -y" -f $FriendlyName,$ChocoPkg) -ForegroundColor Cyan
    try {
        Start-Process -FilePath "choco" -ArgumentList @("uninstall",$ChocoPkg,"-y") -Wait -NoNewWindow
        $LabelRef.Value.Text = ("{0}: no instalado" -f $FriendlyName)
        $LabelRef.Value.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show(
            ("{0} ha sido desinstalado.{1}{1}Te recomiendo cerrar y abrir PowerShell para refrescar el PATH." -f $FriendlyName,[Environment]::NewLine),
            "Desinstalación completada",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Write-Host ("[ERROR] Falló desinstalación de {0}: {1}" -f $FriendlyName, $_) -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            ("No se pudo desinstalar {0}. Revisa la consola." -f $FriendlyName),
            "Error de desinstalación",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        Refresh-GateByDeps   # <-- re-evalúa y bloquea/habilita Consultar/Descargar
    }
}


# ====== Consola: LOGS explícitos ======
Write-Host "[INIT] Cargando UI..." -ForegroundColor Cyan

# Funciones de validación e instalación
function Check-Chocolatey {
    Write-Host "[CHECK] Verificando Chocolatey..." -ForegroundColor Cyan
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "[WARN] Chocolatey no encontrado." -ForegroundColor Yellow
        $response = [System.Windows.Forms.MessageBox]::Show(
            "Chocolatey no está instalado. ¿Desea instalarlo ahora?",
            "Chocolatey no encontrado",[System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($response -eq [System.Windows.Forms.DialogResult]::No) {
            Write-Host "[CANCEL] Usuario rechazó instalar Chocolatey." -ForegroundColor Red
            return $false
        }
        Write-Host "[INSTALL] Instalando Chocolatey..." -ForegroundColor Cyan
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Host "[OK] Chocolatey instalado. Configurando cache..." -ForegroundColor Green
            choco config set cacheLocation C:\Choco\cache | Out-Null
            [System.Windows.Forms.MessageBox]::Show(
                "Chocolatey se instaló correctamente y ha sido configurado. Por favor, reinicie PowerShell antes de continuar.",
                "Reinicio requerido",[System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            Stop-Process -Id $PID -Force
            return $false
        } catch {
            Write-Host "[ERROR] Falló instalación de Chocolatey: $_" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                "Error al instalar Chocolatey. Por favor, inténtelo manualmente.",
                "Error de instalación",[System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return $false
        }
    } else {
        Write-Host "[OK] Chocolatey ya está instalado." -ForegroundColor Green
        return $true
    }
}

# ====== utilidades yt-dlp / ffmpeg ======
# === [NUEVO] Utilidades de vista previa YouTube ===
function Get-YouTubeVideoId {
    param([Parameter(Mandatory=$true)][string]$Url)
    # youtu.be/<id>
    $m = [regex]::Match($Url, 'youtu\.be/([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }

    # youtube.com/watch?v=<id> (&...)
    $m = [regex]::Match($Url, '[?&]v=([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }

    # /shorts/<id>
    $m = [regex]::Match($Url, '/shorts/([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }

    # /embed/<id>
    $m = [regex]::Match($Url, '/embed/([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }

    return $null
}

function Get-ImageFromUrl {
    param([Parameter(Mandatory=$true)][string]$Url)
    try {
        $hc = [System.Net.Http.HttpClient]::new()
        $bytes = $hc.GetByteArrayAsync($Url).Result
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        return [System.Drawing.Image]::FromStream($ms)
    } catch {
        return $null
    } finally {
        if ($hc) { $hc.Dispose() }
    }
}

function Show-PreviewFromUrl {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [string]$Titulo = $null
    )
    $picPreview.Image = $null
    $id = Get-YouTubeVideoId -Url $Url
    if (-not $id) { return }

    # Intenta en orden de mayor calidad disponible
    $candidatas = @(
        "https://img.youtube.com/vi/$id/maxresdefault.jpg",
        "https://img.youtube.com/vi/$id/sddefault.jpg",
        "https://img.youtube.com/vi/$id/hqdefault.jpg",
        "https://img.youtube.com/vi/$id/mqdefault.jpg",
        "https://img.youtube.com/vi/$id/default.jpg"
    )
    foreach ($u in $candidatas) {
        $img = Get-ImageFromUrl -Url $u
        if ($img) {
            $picPreview.Image = $img
            if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
            break
        }
    }
}
# === [FIN utilidades vista previa] ===

function Get-ToolVersion {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [string]$ArgsForVersion="--version",
        [ValidateSet("FirstLine","Raw")][string]$Parse="FirstLine"
    )
    try { $cmd = Get-Command $Command -ErrorAction Stop } catch { return $null }
    try {
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $p.StartInfo.FileName = $cmd.Source
        $p.StartInfo.Arguments = $ArgsForVersion
        $p.StartInfo.RedirectStandardOutput = $true
        $p.StartInfo.RedirectStandardError  = $true
        $p.StartInfo.UseShellExecute = $false
        $p.StartInfo.CreateNoWindow  = $true
        [void]$p.Start()
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $combined = ($stdout + "`n" + $stderr).Trim()
        if ($Parse -eq "FirstLine") {
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
        [string]$VersionArgs="--version",
        [ValidateSet("FirstLine","Raw")][string]$Parse="FirstLine"
    )
    Write-Host ("[CHECK] Verificando {0}..." -f $FriendlyName) -ForegroundColor Cyan
    $version = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse

    if (-not $version) {
        Write-Host ("[WARN] {0} no encontrado." -f $FriendlyName) -ForegroundColor Yellow

        $resp = [System.Windows.Forms.MessageBox]::Show(
            ("{0} no está instalado. ¿Desea instalarlo ahora con Chocolatey?" -f $FriendlyName),
            ("{0} no encontrado" -f $FriendlyName),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($resp -ne [System.Windows.Forms.DialogResult]::Yes) {
            $LabelRef.Value.Text = ("{0}: no instalado" -f $FriendlyName)
            $LabelRef.Value.ForeColor = [System.Drawing.Color]::Red
            Write-Host ("[CANCEL] Usuario omitió instalación de {0}." -f $FriendlyName) -ForegroundColor Yellow
            return
        }

        Write-Host ("[INSTALL] Instalando {0} con choco install {1} -y" -f $FriendlyName,$ChocoPkg) -ForegroundColor Cyan
        try {
            # Instalación con progreso de choco (hereda consola del host)
            Start-Process -FilePath "choco" -ArgumentList @("install",$ChocoPkg,"-y") -NoNewWindow -Wait

            # Verificar inmediatamente después
            $version = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse

            if ($version) {
                $LabelRef.Value.Text = ("{0}: {1}" -f $FriendlyName,$version)
                $LabelRef.Value.ForeColor = [System.Drawing.Color]::ForestGreen
                Write-Host ("[OK] {0} instalado: {1}" -f $FriendlyName,$version) -ForegroundColor Green

                # *** Comportamiento requerido: cerrar UI y solicitar reinicio de PowerShell ***
                [System.Windows.Forms.MessageBox]::Show(
                    ("{0} se instaló correctamente.`n`nPara que el PATH y las variables se apliquen, cierre y vuelva a abrir PowerShell.`nLa aplicación se cerrará ahora." -f $FriendlyName),
                    "Reinicio de PowerShell requerido",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null

                try { $formPrincipal.Close(); $formPrincipal.Dispose() } catch {}
                # Cierra el host para asegurar que no queden sesiones con PATH viejo
                Stop-Process -Id $PID -Force
            }
            else {
                # Instalado pero no detecta versión (raro): igual pedimos reinicio y cerramos
                $LabelRef.Value.Text = ("{0}: Instalado (reinicie PowerShell)" -f $FriendlyName)
                $LabelRef.Value.ForeColor = [System.Drawing.Color]::DarkOrange
                Write-Host ("[WARN] {0} instalado, pero versión no detectada. Requiere reinicio de PowerShell." -f $FriendlyName) -ForegroundColor Yellow

                [System.Windows.Forms.MessageBox]::Show(
                    ("{0} parece haberse instalado, pero no se pudo leer la versión inmediatamente.`n`nCierre y vuelva a abrir PowerShell.`nLa aplicación se cerrará ahora." -f $FriendlyName),
                    "Reinicio de PowerShell requerido",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null

                try { $formPrincipal.Close(); $formPrincipal.Dispose() } catch {}
                Stop-Process -Id $PID -Force
            }
        } catch {
            $LabelRef.Value.Text = ("{0}: error al instalar" -f $FriendlyName)
            $LabelRef.Value.ForeColor = [System.Drawing.Color]::Red
            Write-Host ("[ERROR] Falló instalación de {0}: {1}" -f $FriendlyName,$_ ) -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                ("No se pudo instalar {0} automáticamente.`nRevise la conexión o intente manualmente." -f $FriendlyName),
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }
    else {
        $LabelRef.Value.Text = ("{0}: {1}" -f $FriendlyName,$version)
        $LabelRef.Value.ForeColor = [System.Drawing.Color]::ForestGreen
        Write-Host ("[OK] {0} detectado: {1}" -f $FriendlyName,$version) -ForegroundColor Green
    }
}

# ====== Estado de consulta ======
$script:videoConsultado   = $false
$script:ultimaURL         = $null
$script:ultimoTitulo      = $null
# Por omisión: Escritorio del usuario (soporta redirecciones como OneDrive)
$script:ultimaRutaDescarga = [Environment]::GetFolderPath('Desktop')
# ====== [NUEVO] Selectores de formato ======
$lblVideoFmt = Create-Label -Text "Formato de VIDEO:" `
    -Location (New-Object System.Drawing.Point(20, 215)) `
    -Size (New-Object System.Drawing.Size(360, 20)) -Font $boldFont

$cmbVideoFmt = Create-ComboBox `
    -Location (New-Object System.Drawing.Point(20, 238)) `
    -Size (New-Object System.Drawing.Size(360, 28))

$lblAudioFmt = Create-Label -Text "Formato de AUDIO:" `
    -Location (New-Object System.Drawing.Point(20, 270)) `
    -Size (New-Object System.Drawing.Size(360, 20)) -Font $boldFont

$cmbAudioFmt = Create-ComboBox `
    -Location (New-Object System.Drawing.Point(20, 293)) `
    -Size (New-Object System.Drawing.Size(360, 28))

$formPrincipal.Controls.Add($lblVideoFmt)
$formPrincipal.Controls.Add($cmbVideoFmt)
$formPrincipal.Controls.Add($lblAudioFmt)
$formPrincipal.Controls.Add($cmbAudioFmt)
# Parte SUPERIOR: consulta y descarga
$lblUrl = Create-Label -Text "URL de YouTube:" -Location (New-Object System.Drawing.Point(20, 20)) -Size (New-Object System.Drawing.Size(360, 22)) -Font $boldFont
$txtUrl = Create-TextBox -Location (New-Object System.Drawing.Point(20, 45)) -Size (New-Object System.Drawing.Size(360, 26))
# --- Label de estado con 2 renglones (wrap) ---
$lblEstadoConsulta = Create-Label `
    -Text "Estado: sin consultar" `
    -Location (New-Object System.Drawing.Point(20, 75)) `
    -Size (New-Object System.Drawing.Size(360, 44)) `
    -Font $defaultFont `
    -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle) `
    -TextAlign ([System.Drawing.ContentAlignment]::TopLeft)
$lblEstadoConsulta.UseCompatibleTextRendering = $true

$btnConsultar = Create-Button -Text "Consultar" `
    -Location (New-Object System.Drawing.Point(20, 125)) `
    -Size (New-Object System.Drawing.Size(170, 35)) `
    -BackColor ([System.Drawing.Color]::White) `
    -ForeColor ([System.Drawing.Color]::Black) `
    -ToolTipText "Obtener información del video"

$btnDescargar = Create-Button -Text "Descargar" `
    -Location (New-Object System.Drawing.Point(210, 125)) `
    -Size (New-Object System.Drawing.Size(170, 35)) `
    -BackColor ([System.Drawing.Color]::Black) `
    -ForeColor ([System.Drawing.Color]::White) `
    -ToolTipText "Descargar usando bestvideo+bestaudio -> mp4"
Set-DownloadButtonVisual -ok:$false
# --- Carpeta de destino (configurable, por omisión Escritorio) ---
$lblDestino = Create-Label -Text "Carpeta de destino:" `
    -Location (New-Object System.Drawing.Point(20, 160)) `
    -Size (New-Object System.Drawing.Size(360, 20)) -Font $boldFont

# TextBox solo lectura con la ruta actual
$txtDestino = Create-TextBox `
    -Location (New-Object System.Drawing.Point(20, 183)) `
    -Size (New-Object System.Drawing.Size(320, 26)) `
    -ReadOnly $true `
    -Text $script:ultimaRutaDescarga

# Botón para abrir selector de carpeta
$btnPickDestino = Create-IconButton -Text "📁" `
    -Location (New-Object System.Drawing.Point(346, 183)) `
    -ToolTipText "Cambiar carpeta de destino"

$formPrincipal.Controls.Add($lblDestino)
$formPrincipal.Controls.Add($txtDestino)
$formPrincipal.Controls.Add($btnPickDestino)

$btnPickDestino.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description  = "Selecciona la carpeta de descarga"
    $fbd.SelectedPath = if ([string]::IsNullOrWhiteSpace($script:ultimaRutaDescarga)) {
        [Environment]::GetFolderPath('Desktop')
    } else {
        $script:ultimaRutaDescarga
    }

    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:ultimaRutaDescarga = $fbd.SelectedPath
        $txtDestino.Text = $script:ultimaRutaDescarga
        Write-Host ("[DESTINO] Carpeta configurada: {0}" -f $script:ultimaRutaDescarga) -ForegroundColor Cyan
    }
})

# ----- [NUEVO] Zona de vista previa -----
$lblPreview = Create-Label -Text "Vista previa:" `
    -Location (New-Object System.Drawing.Point(20, 330)) `
    -Size (New-Object System.Drawing.Size(360, 22)) `
    -Font $boldFont

$picPreview = New-Object System.Windows.Forms.PictureBox
$picPreview.Location   = New-Object System.Drawing.Point(20, 355)
$picPreview.Size       = New-Object System.Drawing.Size(360, 146)
$picPreview.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$picPreview.SizeMode   = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$picPreview.BackColor  = [System.Drawing.Color]::White

$formPrincipal.Controls.Add($lblPreview)
$formPrincipal.Controls.Add($picPreview)


$formPrincipal.Controls.Add($lblUrl)
$formPrincipal.Controls.Add($txtUrl)
$formPrincipal.Controls.Add($lblEstadoConsulta)
$formPrincipal.Controls.Add($btnConsultar)
$formPrincipal.Controls.Add($btnDescargar)

# --- Bitácora con scroll vertical 
$txtCambios = Create-TextBox `
    -Location (New-Object System.Drawing.Point(20, 520)) -Size (New-Object System.Drawing.Size(360, 50)) `
    -BackColor ([System.Drawing.Color]::White) -ForeColor ([System.Drawing.Color]::Black) `
    -Font $defaultFont -Text $global:defaultInstructions `
    -Multiline $true -ScrollBars ([System.Windows.Forms.ScrollBars]::Vertical) `
    -ReadOnly $true
$txtCambios.WordWrap = $true
$formPrincipal.Controls.Add($txtCambios)

$lblTituloDeps = Create-Label -Text "Dependencias:" -Location (New-Object System.Drawing.Point(20, 590)) -Size (New-Object System.Drawing.Size(360, 24)) -Font $boldFont
$lblYtDlp      = Create-Label -Text "yt-dlp: verificando..." -Location (New-Object System.Drawing.Point(80, 620)) -Size (New-Object System.Drawing.Size(300, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$lblFfmpeg     = Create-Label -Text "ffmpeg: verificando..." -Location (New-Object System.Drawing.Point(80, 650)) -Size (New-Object System.Drawing.Size(300, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$lblNode       = Create-Label -Text "Node.js: verificando..." -Location (New-Object System.Drawing.Point(80, 680)) -Size (New-Object System.Drawing.Size(300, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$btnExit    = Create-Button -Text "Salir"    -Location (New-Object System.Drawing.Point(20, 720)) -BackColor ([System.Drawing.Color]::Black) -ForeColor ([System.Drawing.Color]::White) -ToolTipText "Cerrar la aplicación" -Size (New-Object System.Drawing.Size(360, 35))
$btnYtRefresh   = Create-IconButton -Text "↻" -Location (New-Object System.Drawing.Point(20, 620)) -ToolTipText "Buscar/actualizar yt-dlp"
$btnYtUninstall = Create-IconButton -Text "✖" -Location (New-Object System.Drawing.Point(48, 620)) -ToolTipText "Desinstalar yt-dlp"
$btnYtRefresh.Add_Click({
    Update-Dependency -ChocoPkg "yt-dlp" -FriendlyName "yt-dlp" -CommandName "yt-dlp" -LabelRef ([ref]$lblYtDlp) -VersionArgs "--version" -Parse "FirstLine"
})
$btnYtUninstall.Add_Click({
    Uninstall-Dependency -ChocoPkg "yt-dlp" -FriendlyName "yt-dlp" -LabelRef ([ref]$lblYtDlp)
})
$formPrincipal.Controls.Add($btnYtRefresh)
$formPrincipal.Controls.Add($btnYtUninstall)
$btnFfmpegRefresh   = Create-IconButton -Text "↻" -Location (New-Object System.Drawing.Point(20, 650)) -ToolTipText "Buscar/actualizar ffmpeg"
$btnFfmpegUninstall = Create-IconButton -Text "✖" -Location (New-Object System.Drawing.Point(48, 650)) -ToolTipText "Desinstalar ffmpeg"
$btnFfmpegRefresh.Add_Click({
    Update-Dependency -ChocoPkg "ffmpeg" -FriendlyName "ffmpeg" -CommandName "ffmpeg" -LabelRef ([ref]$lblFfmpeg) -VersionArgs "-version" -Parse "FirstLine"
})
$btnFfmpegUninstall.Add_Click({
    Uninstall-Dependency -ChocoPkg "ffmpeg" -FriendlyName "ffmpeg" -LabelRef ([ref]$lblFfmpeg)
})
$formPrincipal.Controls.Add($btnFfmpegRefresh)
$formPrincipal.Controls.Add($btnFfmpegUninstall)

# Node.js (paquete LTS en choco)
$btnNodeRefresh   = Create-IconButton -Text "↻" -Location (New-Object System.Drawing.Point(20, 680)) -ToolTipText "Buscar/actualizar Node.js (LTS)"
$btnNodeUninstall = Create-IconButton -Text "✖" -Location (New-Object System.Drawing.Point(48, 680)) -ToolTipText "Desinstalar Node.js (LTS)"
$btnNodeRefresh.Add_Click({
    Update-Dependency -ChocoPkg "nodejs-lts" -FriendlyName "Node.js" -CommandName "node" -LabelRef ([ref]$lblNode) -VersionArgs "--version" -Parse "FirstLine"
})
$btnNodeUninstall.Add_Click({
    Uninstall-Dependency -ChocoPkg "nodejs-lts" -FriendlyName "Node.js" -LabelRef ([ref]$lblNode)
})
$formPrincipal.Controls.Add($btnNodeRefresh)
$formPrincipal.Controls.Add($btnNodeUninstall)
# ================== [FIN NUEVO] Botones de acciones por dependencia ==================

$formPrincipal.Controls.Add($lblTituloDeps)
$formPrincipal.Controls.Add($lblNode)
$formPrincipal.Controls.Add($lblYtDlp)
$formPrincipal.Controls.Add($lblFfmpeg)
$formPrincipal.Controls.Add($btnExit)

# ====== Utilidad captura ======
# === UI modeless "Trabajando..." ===
function New-WorkingBox {
    param([string]$Text)
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Trabajando..."
    $f.Size = New-Object System.Drawing.Size(320,110)
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $f.StartPosition = "CenterParent"
    $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.ControlBox = $false
    $f.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text; $lbl.AutoSize = $false
    $lbl.Size = New-Object System.Drawing.Size(300,30)
    $lbl.Location = New-Object System.Drawing.Point(10,10)
    $lbl.TextAlign = "MiddleCenter"
    $prg = New-Object System.Windows.Forms.ProgressBar
    $prg.Style = "Marquee"
    $prg.MarqueeAnimationSpeed = 25
    $prg.Size = New-Object System.Drawing.Size(300,20)
    $prg.Location = New-Object System.Drawing.Point(10,45)
    $f.Controls.Add($lbl); $f.Controls.Add($prg)
    $f.Show() | Out-Null
    return @{ Form = $f; Label = $lbl }
}

function Invoke-CaptureResponsive {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [string[]]$Args = @(),
        [string]$WorkingText = "Procesando...",
        [int]$TimeoutSec = 120
    )

    # Deshabilitar "Consultar" mientras corre
    $prevBtnState = $null
    if ($btnConsultar) { $prevBtnState = $btnConsultar.Enabled; $btnConsultar.Enabled = $false }

    # Mostrar texto en label (parpadeo)
    $prevLabel = $null
    if ($lblEstadoConsulta) { $prevLabel = $lblEstadoConsulta.Text; $lblEstadoConsulta.Text = $WorkingText }

    # Archivos temporales para stdout/err (evita deadlock)
    $tmpDir  = [System.IO.Path]::GetTempPath()
    $outFile = Join-Path $tmpDir ("proc_stdout_{0}.log" -f ([guid]::NewGuid()))
    $errFile = Join-Path $tmpDir ("proc_stderr_{0}.log" -f ([guid]::NewGuid()))

    $argLine = ($Args | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '

    $proc = Start-Process -FilePath $ExePath `
        -ArgumentList $argLine `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError  $errFile

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $dot = 0
    try {
        while (-not $proc.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            $dot = ($dot + 1) % 4
            if ($lblEstadoConsulta) { $lblEstadoConsulta.Text = $WorkingText + ("." * $dot) }

            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
                try { $proc.Kill() } catch {}
                throw "Tiempo de espera agotado ($TimeoutSec s) en '$WorkingText'."
            }
            Start-Sleep -Milliseconds 120
        }
    } finally {
        $sw.Stop()
        # Restaurar botón
        if ($btnConsultar -and $prevBtnState -ne $null) { $btnConsultar.Enabled = $prevBtnState }
    }

    # Leer salidas
    $stdout = ""; $stderr = ""
    try { if (Test-Path $outFile) { $stdout = [IO.File]::ReadAllText($outFile) } } catch {}
    try { if (Test-Path $errFile) { $stderr = [IO.File]::ReadAllText($errFile) } } catch {}
    try { Remove-Item -Path $outFile,$errFile -ErrorAction SilentlyContinue } catch {}

    # NO restauramos el label aquí; lo hará el llamador con el texto final correcto.
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
}



function Invoke-Capture {
    param([Parameter(Mandatory=$true)][string]$ExePath,[string[]]$Args=@())
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
# Progreso SOLO en consola usando tail de STDERR de yt-dlp
function Invoke-YtDlpConsoleProgress {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [Parameter(Mandatory=$true)][string[]]$Args
    )

    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    $global:ProgressPreference = 'SilentlyContinue'

    $tmpDir  = [System.IO.Path]::GetTempPath()
    $errFile = Join-Path $tmpDir ("yt-dlp-stderr_{0}.log" -f ([guid]::NewGuid()))
    $outFile = Join-Path $tmpDir ("yt-dlp-stdout_{0}.log" -f ([guid]::NewGuid()))

    # Armar argumentos con comillas cuando hay espacios
    $argLine = ($Args | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '

    $proc = Start-Process -FilePath $ExePath `
        -ArgumentList $argLine `
        -NoNewWindow -PassThru `
        -RedirectStandardError $errFile `
        -RedirectStandardOutput $outFile

    # Abrir ambos streams (stdout + stderr)
    $fsErr = [System.IO.File]::Open($errFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $srErr = New-Object System.IO.StreamReader($fsErr)
    $fsOut = [System.IO.File]::Open($outFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $srOut = New-Object System.IO.StreamReader($fsOut)

    $script:lastPct = -1
    function _PrintLine([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return }
        # 1) progress-template: "download: 12.3% ETA:00:10 SPEED:1.23MiB/s"
        $m = [regex]::Match($text, 'download:\s*(?<pct>\d+(?:\.\d+)?)%\s*(?:ETA:(?<eta>\S+))?\s*(?:SPEED:(?<spd>.+))?', 'IgnoreCase')
        if (-not $m.Success) {
            # 2) clásico: "... 12.3% ... at 1.2MiB/s ETA 00:10"
            $m = [regex]::Match($text, '(?<pct>\d+(?:\.\d+)?)%\s+of.*?at\s+(?<spd>\S+)\s+ETA\s+(?<eta>\S+)', 'IgnoreCase')
            if (-not $m.Success) {
                # 3) porcentaje suelto
                $m = [regex]::Match($text, '(?<pct>\d+(?:\.\d+)?)%')
            }
        }
        if ($m.Success) {
            $pct = [int][math]::Min(100, [math]::Round([double]$m.Groups['pct'].Value))
            $eta = $m.Groups['eta'].Value
            $spd = $m.Groups['spd'].Value
            if ($pct -ne $script:lastPct) {
                $script:lastPct = $pct
                Write-Host ("`r[PROGRESO] {0,3}%  ETA {1,-8}  {2,-16}" -f $pct, $eta, $spd) -NoNewline
            }
        } else {
            Write-Host ("`n{0}" -f $text)
        }
    }

    try {
        while (-not $proc.HasExited -or -not ($srErr.EndOfStream -and $srOut.EndOfStream)) {
            while (-not $srOut.EndOfStream) { _PrintLine ($srOut.ReadLine()) }
            while (-not $srErr.EndOfStream) { _PrintLine ($srErr.ReadLine()) }
            Start-Sleep -Milliseconds 80
        }
    } finally {
        try { $srErr.Close(); $fsErr.Close() } catch {}
        try { $srOut.Close(); $fsOut.Close() } catch {}
        Write-Host ""
        # Remove-Item -Path $errFile,$outFile -ErrorAction SilentlyContinue
    }

    return $proc.ExitCode
}



# ====== Eventos ======

# Consultar
$btnConsultar.Add_Click({
    # Bloquear doble clic desde el inicio
    $btnConsultar.Enabled = $false
    try {
        Refresh-GateByDeps
        if (-not $btnConsultar.Enabled) { return }

        $url = $txtUrl.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($url)) {
            [System.Windows.Forms.MessageBox]::Show("Escribe una URL de YouTube.","Falta URL",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        Write-Host ("[CONSULTA] Consultando URL: {0}" -f $url) -ForegroundColor Cyan
        try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
            Write-Host "[ERROR] yt-dlp no disponible. Valida dependencias." -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible. Valídalo en Dependencias.","yt-dlp no encontrado",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }

        # 1) Consultar título
        $res = Invoke-CaptureResponsive -ExePath $yt.Source `
                -Args @("--no-playlist","--get-title",$url) `
                -WorkingText "Consultando URL…"

        $titulo = ($res.StdOut + "`n" + $res.StdErr).Trim() -split "`r?`n" |
                  Where-Object { $_.Trim() -ne "" } | Select-Object -First 1

        if ($res.ExitCode -ne 0 -or -not $titulo) {
            $script:videoConsultado = $false; $script:ultimaURL = $null; $script:ultimoTitulo = $null
            $lblEstadoConsulta.Text = "Error al consultar la URL"; $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::Red
            Set-DownloadButtonVisual -ok:$false
            $picPreview.Image = $null
            Write-Host "[ERROR] No se pudo consultar el video. STDOUT/ERR:" -ForegroundColor Red
            Write-Host $res.StdOut
            Write-Host $res.StdErr
            [System.Windows.Forms.MessageBox]::Show("No se pudo consultar el video. Revisa la URL o tu conexión.","Consulta fallida",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }

        # 2) Ya tengo título -> dejo el label en Consultado: <titulo>
        $script:videoConsultado = $true; $script:ultimaURL = $url; $script:ultimoTitulo = $titulo
        $lblEstadoConsulta.Text = ("Consultado: {0}" -f $titulo); $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::ForestGreen
        Set-DownloadButtonVisual -ok:$true
        Show-PreviewFromUrl -Url $url -Titulo $titulo
        Write-Host ("[OK] Video consultado: {0}" -f $titulo) -ForegroundColor Green

        # 3) Rellenar formatos (si cambia el label a “Consultando formatos…”, lo restauramos al final)
        $cmbVideoFmt.Items.Clear()
        $cmbAudioFmt.Items.Clear()

        $prevLabelText = $lblEstadoConsulta.Text
        $lblEstadoConsulta.Text = "Consultando formatos…"
        try {
            if (Fetch-Formats -Url $url) {
                foreach ($i in $script:formatsVideo) { [void]$cmbVideoFmt.Items.Add($i) }
                foreach ($i in $script:formatsAudio) { [void]$cmbAudioFmt.Items.Add($i) }

                if ($cmbVideoFmt.Items.Count -gt 0) {
                    $idx = 0
                    for ($n=0; $n -lt $cmbVideoFmt.Items.Count; $n++) {
                        if ($cmbVideoFmt.Items[$n].ToString().StartsWith("bestvideo")) { $idx = $n; break }
                        if ($cmbVideoFmt.Items[$n].ToString().StartsWith("best")) { $idx = $n }
                    }
                    $cmbVideoFmt.SelectedIndex = $idx
                }
                if ($cmbAudioFmt.Items.Count -gt 0) {
                    $idx = 0
                    for ($n=0; $n -lt $cmbAudioFmt.Items.Count; $n++) {
                        if ($cmbAudioFmt.Items[$n].ToString().StartsWith("bestaudio")) { $idx = $n; break }
                    }
                    $cmbAudioFmt.SelectedIndex = $idx
                }
            } else {
                Write-Host "[WARN] No se pudieron enumerar formatos. Se usará bestvideo+bestaudio." -ForegroundColor Yellow
            }
        } finally {
            # 4) Restaurar SIEMPRE el título en el label (evita que quede ‘Consultando formatos…’)
            $lblEstadoConsulta.Text = $prevLabelText
        }

    } finally {
        # Rehabilitar el botón “Consultar” pase lo que pase
        $btnConsultar.Enabled = $true
    }
})


# Descargar (pregunta DÓNDE en entorno visual, y loguea en consola)
# Descargar (pregunta DÓNDE, muestra progreso en consola + barra)
$btnDescargar.Add_Click({
    if (-not $script:videoConsultado -or [string]::IsNullOrWhiteSpace($script:ultimaURL)) {
        [System.Windows.Forms.MessageBox]::Show("Primero usa 'Consultar' para validar la URL.","Requisito: Consultar",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
        Write-Host "[ERROR] yt-dlp no disponible. Valida dependencias." -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible. Valídalo en Dependencias.","yt-dlp no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    # Usar la carpeta configurada (sin preguntar)
    $dest = $script:ultimaRutaDescarga
    if ([string]::IsNullOrWhiteSpace($dest)) {
        $dest = [Environment]::GetFolderPath('Desktop')
        $script:ultimaRutaDescarga = $dest
        try { $txtDestino.Text = $dest } catch {}
    }
    if (-not (Test-Path -LiteralPath $dest)) {
        try {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Write-Host ("[DESTINO] Carpeta creada: {0}" -f $dest) -ForegroundColor Cyan
        } catch {
            Write-Host ("[ERROR] No se pudo preparar la carpeta destino: {0}" -f $_) -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                "No se pudo preparar la carpeta de destino. Verifica permisos.",
                "Error de destino",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return
        }
    }
    Write-Host ("[DESCARGA] Carpeta destino: {0}" -f $dest) -ForegroundColor Cyan


    # ====== [NUEVO] Construcción de -f con combos ======
    $videoSel = Get-SelectedFormatId -Combo $cmbVideoFmt
    $audioSel = Get-SelectedFormatId -Combo $cmbAudioFmt

    # Lógica:
    # - Si $videoSel es 'best' -> progresivo si existe; ignoramos audio.
    # - Si $videoSel es format_id PROGRESIVO -> ignoramos audio.
    # - Si $videoSel es 'bestvideo' o VIDEO-ONLY -> combinar con audio (o bestaudio).
    # - Si nada seleccionado -> bestvideo+bestaudio.
    $fSelector = $null
    $mergeExt  = "mp4"   # por omisión, para --merge-output-format

    if ($videoSel) {
        if ($videoSel -eq "best") {
            $fSelector = "best"
        } elseif ($videoSel -eq "bestvideo") {
            $fSelector = "bestvideo+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
            } else {
                # Es un format_id específico
                $klass = $script:formatsIndex[$videoSel]
                if ($klass -and $klass.Progressive) {
                    # Evitar progresivos: forzar adaptativo (video-only + audio)
                    $fSelector = "bestvideo+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
                    $mergeExt  = "mp4"

            } elseif ($klass -and $klass.VideoOnly) {
                $fSelector = $videoSel + "+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
            } else {
                # Desconocido: intentar combinar con audio por seguridad
                $fSelector = $videoSel + "+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
            }
        }
    } else {
        # Nada seleccionado: omisión robusta
        $fSelector = "bestvideo+bestaudio"
    }

    # Construcción de argumentos finales
    $args = @(
      "--encoding","utf-8",
      "--progress","--no-color","--newline",
      "-f",$fSelector,
      "--merge-output-format",$mergeExt,
      "-P",$dest,
      "--progress-template","download:%(progress._percent_str)s ETA:%(progress._eta_str)s SPEED:%(progress._speed_str)s",
      "--extractor-args","youtube:player_client=default,-web_safari,-web_embedded,-tv",
      $script:ultimaURL
    )

    Write-Host ("[DESCARGA] Selector de formato: -f `"{0}`"" -f $fSelector) -ForegroundColor DarkCyan
    Write-Host ("[CMD] {0} {1}" -f $yt.Source, ($args -join ' ')) -ForegroundColor DarkGray

    $exit = Invoke-YtDlpConsoleProgress -ExePath $yt.Source -Args $args



    if ($exit -eq 0) {
        Write-Host ("[OK] Descarga finalizada: {0}" -f $($script:ultimoTitulo)) -ForegroundColor Green
        [System.Windows.Forms.MessageBox]::Show(("Descarga finalizada:`n{0}" -f $($script:ultimoTitulo)),"Completado",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } else {
        Write-Host ("[ERROR] Falló la descarga. Código: {0}" -f $exit) -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show("Falló la descarga. Revisa conexión/URL/DRM.","Error de descarga",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
})


# Validación de Chocolatey y dependencias al iniciar la UI
$formPrincipal.Add_Shown({
    try {
        if (-not (Check-Chocolatey)) {
            Write-Host "[EXIT] Cerrando por falta de Chocolatey / reinicio requerido." -ForegroundColor Yellow
            $formPrincipal.Close()
            return
        }
        Write-Host "[CHECK] Validando dependencias yt-dlp y ffmpeg..." -ForegroundColor Cyan
        Ensure-Tool -CommandName "yt-dlp" -FriendlyName "yt-dlp" -ChocoPkg "yt-dlp" -LabelRef ([ref]$lblYtDlp) -VersionArgs "--version"
        $lblFfmpeg.Text = "ffmpeg: verificando..."
        Ensure-Tool -CommandName "ffmpeg" -FriendlyName "ffmpeg" -ChocoPkg "ffmpeg" -LabelRef ([ref]$lblFfmpeg) -VersionArgs "-version"
        Ensure-Tool -CommandName "node"   -FriendlyName "Node.js" -ChocoPkg "nodejs-lts" -LabelRef ([ref]$lblNode) -VersionArgs "--version"
        Write-Host "[READY] Dependencias verificadas." -ForegroundColor Green
        Refresh-GateByDeps   # <--- NUEVO: bloquea/desbloquea botones según deps
        try { $txtDestino.Text = $script:ultimaRutaDescarga } catch {}

    } catch {
        Write-Host ("[ERROR] Error al validar dependencias: {0}" -f $_) -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            ("Error al validar dependencias:`n{0}" -f $_),"Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $formPrincipal.Close()
    }
})

# Botón Salir
$btnExit.Add_Click({
    Write-Host "[EXIT] Cerrando aplicación por solicitud del usuario." -ForegroundColor Yellow
    $formPrincipal.Dispose()
    $formPrincipal.Close()
})

$formPrincipal.Refresh()
$formPrincipal.ShowDialog()
