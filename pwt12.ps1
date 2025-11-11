if (!(Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
    Write-Host "Carpeta 'C:\Temp' creada correctamente."
}
$iconDir = "C:\Temp\icos"
if (-not (Test-Path $iconDir)) {
    New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
    Write-Host "Carpeta de íconos creada: $iconDir"
}
$script:LogFile = "C:\Temp\ytdll_history.txt"
if (-not (Test-Path -LiteralPath $script:LogFile)) {
    New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
}
function Get-HistoryUrls {
    try {
        $content = Get-Content -LiteralPath $script:LogFile -ErrorAction Stop -Raw
        $content -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and ($_ -notmatch '^\s*$') } |
            Select-Object -Unique
    } catch { @() }
}
function Add-HistoryUrl {
    param([Parameter(Mandatory=$true)][string]$Url)
    $u = $Url.Trim()
    if ([string]::IsNullOrWhiteSpace($u)) { return }
    # No guardar placeholders
    if ($u -eq $global:UrlPlaceholder) { return }
    # Validar rudamente que parezca URL
    if ($u -notmatch '^(https?://|www\.)') { return }
    $list = Get-HistoryUrls
    if ($list -notcontains $u) {
        # Limitar a 200 entradas
        $newList = @($u) + $list
        if ($newList.Count -gt 200) { $newList = $newList[0..199] }
        try {
            Set-Content -LiteralPath $script:LogFile -Value $newList -Encoding UTF8
        } catch {}
    }
}

function Clear-History {
    try { Clear-Content -LiteralPath $script:LogFile -ErrorAction Stop } catch {}
}
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
} catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
chcp 65001 | Out-Null               # Forzar code page de consola a UTF-8
$env:PYTHONUTF8 = '1'               # Python/yt-dlp en modo UTF-8
$PSStyle.OutputRendering = 'Ansi'   # Evita rarezas con ANSI/UTF-8 en PS 7+
$global:defaultInstructions = @"
----- CAMBIOS -----
- Ahora ya guarda un log con URLS consultadas.
- Se agrea funcionalidad para ver y buscar sitios compatibles.
- Soporte para VODS de twitch / vista previa.
- Se agregó botón ? para información de sistema.
- Ahora ya solo existe 1 botón para consultar y descargar.
- Ahora se debe tener una carpeta preconfigurada de destino, por omisión se usa el Escritorio.
- Ahora permite que selecciones los formatos para video y audio.
- Se agrega la opción para actualizar y desinstalar dependencias.
- Se agregó vista previa del video.
- Se agregó detalles de progreso de descarga en consola.
- Se agregó dependencia Node.
- Se agregó validar consulta de video para descargar.
"@
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
                                                                                                $version = "beta 251111.1111"
$formPrincipal = New-Object System.Windows.Forms.Form
$formPrincipal.Size = New-Object System.Drawing.Size(400, 800)
$formPrincipal.StartPosition = "CenterScreen"
$formPrincipal.BackColor = [System.Drawing.Color]::White
$formPrincipal.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$formPrincipal.MaximizeBox = $false
$formPrincipal.MinimizeBox = $false
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$boldFont    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$formPrincipal.Text = ("YTDLL v{0}" -f $version)
Write-Host "`n=============================================" -ForegroundColor DarkCyan
Write-Host "                   YTDLL                       " -ForegroundColor Green
Write-Host ("              Versión: v{0}" -f $version) -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor DarkCyan
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
function Set-DownloadButtonVisual {
    param()
    $haveYt   = Test-CommandExists -Name "yt-dlp"
    $haveFfm  = Test-CommandExists -Name "ffmpeg"
    $haveNode = if ($script:RequireNode) { Test-CommandExists -Name "node" } else { $true }
    $depsOk = $haveYt -and $haveFfm -and $haveNode
    if (-not $depsOk) {
        $btnDescargar.Enabled   = $false
        $btnDescargar.BackColor = [System.Drawing.Color]::Black
        $btnDescargar.ForeColor = [System.Drawing.Color]::White
        $btnDescargar.Text      = "Descargar"
        $toolTip.SetToolTip($btnDescargar, "Deshabilitado: instala/activa dependencias")
        $btnDescargar.Tag = $btnDescargar.BackColor
        return
    }
    $currentUrl = Get-CurrentUrl
    $isConsulted = $script:videoConsultado -and
                   -not [string]::IsNullOrWhiteSpace($script:ultimaURL) -and
                   ($script:ultimaURL -eq $currentUrl)
    $btnDescargar.Enabled = $true
    $btnDescargar.Text    = "Descargar"
    if (-not $isConsulted) {
        $btnDescargar.BackColor = [System.Drawing.Color]::DodgerBlue
        $btnDescargar.ForeColor = [System.Drawing.Color]::White
        $toolTip.SetToolTip($btnDescargar, "Aún no consultado: al hacer clic validará la URL (no descargará)")
    }
        elseif (-not $script:formatsEnumerated) {
            $btnDescargar.Enabled   = $true
            $btnDescargar.BackColor = [System.Drawing.Color]::DarkOrange
            $btnDescargar.ForeColor = [System.Drawing.Color]::White
            $toolTip.SetToolTip($btnDescargar, "No se pudieron extraer formatos. Presiona 'Descargar' para volver a consultar.")
            if ($lblEstadoConsulta) {
                $lblEstadoConsulta.Text = "No fue posible extraer formatos. Presiona 'Descargar' para volver a consultar."
                $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::DarkOrange
            }
        }
    else {
        $btnDescargar.BackColor = [System.Drawing.Color]::ForestGreen
        $btnDescargar.ForeColor = [System.Drawing.Color]::White
        $toolTip.SetToolTip($btnDescargar, "Consulta válida: listo para descargar")
    }
    $btnDescargar.Tag = $btnDescargar.BackColor
}
$script:RequireNode = $true
function Test-CommandExists {
    param([Parameter(Mandatory=$true)][string]$Name)
    try { Get-Command $Name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}
function Normalize-ThumbUrl {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [string]$Extractor = $null
    )
    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    $u = $Url.Trim()
    if ($Extractor -match '^twitch' -or $u -match 'twitch\.tv|static-cdn\.jtvnw\.net') {
        Write-Host "[TWITCH] Normalizando miniatura: $u" -ForegroundColor Yellow
        $u = $u -replace '%\{width\}x%\{height\}', '1280x720'
        $u = $u -replace '\{width\}x\{height\}', '1280x720'
        $u = $u -replace '%\{width\}', '1280'
        $u = $u -replace '%\{height\}', '720'
        $u = $u -replace '\{width\}', '1280'
        $u = $u -replace '\{height\}', '720'
        $u = $u -replace '%\{\s*width\s*\}', '1280'
        $u = $u -replace '%\{\s*height\s*\}', '720'
        if ($u -match 'thumb0-\{width\}x\{height\}') {
            $u = $u -replace 'thumb0-\{width\}x\{height\}', 'thumb0-1280x720'
        }
        if ($u -match '(thumb0?|preview)-(\d+)x(\d+)') {
            $u = $u -replace '(thumb0?|preview)-(\d+)x(\d+)', '${1}-1280x720'
        }
        Write-Host "[TWITCH] Miniatura normalizada: $u" -ForegroundColor Green
    }
    return $u
}
function Refresh-GateByDeps {
    $haveYt   = Test-CommandExists -Name "yt-dlp"
    $haveFfm  = Test-CommandExists -Name "ffmpeg"
    $haveNode = if ($script:RequireNode) { Test-CommandExists -Name "node" } else { $true }
    $allOk = $haveYt -and $haveFfm -and $haveNode
    Set-DownloadButtonVisual
    $btnConsultar.Enabled = $allOk
    if ($allOk) {
        $toolTip.SetToolTip($btnConsultar, "Obtener información del video")
    } else {
        $toolTip.SetToolTip($btnConsultar, "Deshabilitado: instala/activa dependencias")
        $script:videoConsultado = $false
        $script:ultimaURL       = $null
        $script:ultimoTitulo    = $null
        Set-DownloadButtonVisual
        $lblEstadoConsulta.Text = "Estado: sin consultar"
        $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::Black
        if ($picPreview) { $picPreview.Image = $null }
    }
}
$script:formatsIndex = @{}   # format_id -> objeto con metadatos (tipo, codecs, label)
$script:formatsVideo = @()   # lista de objetos mostrables en Combo Video
$script:formatsAudio = @()   # lista de objetos mostrables en Combo Audio
$script:ExcludedFormatIds = @('18','22','95','96')
function New-FormatDisplay {
    param(
        [string]$Id,[string]$Label
    )
    return ("{0} — {1}" -f $Id, $Label)
}
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
function Human-Size {
    param([Nullable[long]]$bytes)
    if (-not $bytes -or $bytes -le 0) { return "" }
    $units = "B","KiB","MiB","GiB","TiB"
    $p = 0; $n = [double]$bytes
    while ($n -ge 1024 -and $p -lt $units.Count-1) { $n/=1024; $p++ }
    return ("{0:N1}{1}" -f $n, $units[$p])
}
function Format-Count {
    param(
        [Parameter(Mandatory=$true)][int]$Count,
        [Parameter(Mandatory=$true)][string]$Singular,
        [Parameter(Mandatory=$true)][string]$Plural
    )
    if ($Count -eq 1) { return "1 $Singular" }
    return ("{0} {1}" -f $Count, $Plural)
}
function Get-SafeFileName {
    param([Parameter(Mandatory=$true)][string]$Name)
    $invalid = ([IO.Path]::GetInvalidFileNameChars() -join '')
    $regex   = "[{0}]" -f [regex]::Escape($invalid)
    $n = [regex]::Replace($Name, $regex, " ")
    $n = ($n -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { $n = "video" }
    return $n
}
function Format-ExtractorsInline {
    param(
        [Parameter(Mandatory=$true)][string]$RawText,
        [int]$WrapAt = 120
    )
    $lines = $RawText -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object {
            $_ -and
            ($_ -notmatch '^\s*WARNING') -and
            ($_ -notmatch '^\s*ERROR')   -and
            ($_ -notmatch '^\s*Deprecation')
        }

    $tokens = foreach ($ln in $lines) {
        $clean = $ln -replace '\s+\(.*?\)\s*$',''
        $parts = $clean -split '[\s,]+' | Where-Object { $_ }
        foreach ($p in $parts) {
            if ($p -match '^[A-Za-z0-9][\w:-]+$') { $p }
        }
    }

    $uniq = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($t in $tokens) { if ($seen.Add($t)) { $null = $uniq.Add($t) } }

    $sb = [System.Text.StringBuilder]::new()
    $lineLen = 0
    for ($i=0; $i -lt $uniq.Count; $i++) {
        $tok = $uniq[$i]
        $sep = if ($i -eq 0 -or $lineLen -eq 0) { '' } else { ' | ' }
        $addLen = $sep.Length + $tok.Length
        if ($WrapAt -gt 0 -and ($lineLen + $addLen) -gt $WrapAt) {
            [void]$sb.AppendLine()
            $lineLen = 0
            $sep = ''
            $addLen = $tok.Length
        }
        [void]$sb.Append($sep)
        [void]$sb.Append($tok)
        $lineLen += $addLen
    }

    [pscustomobject]@{
        Text  = $sb.ToString()
        Count = $uniq.Count
        List  = $uniq           # <--- NUEVO: lista utilizable para filtrar
    }
}

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
$script:bestProgId   = $null
$script:bestProgRank = -1
function Fetch-Formats {
    param([Parameter(Mandatory=$true)][string]$Url)
    $script:formatsIndex.Clear()
    $script:formatsVideo = @()
    $script:formatsAudio = @()
    $script:formatsEnumerated = $false   # <-- reset
    $script:lastFormats = $null          # <-- NUEVA VARIABLE
    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
        Write-Host "[ERROR] yt-dlp no disponible para listar formatos." -ForegroundColor Red
        return $false
    }

    $prevLabel = $null
    if ($lblEstadoConsulta) {
        $prevLabel = $lblEstadoConsulta.Text
        $lblEstadoConsulta.Text = "Consultando formatos…"
    }
    try {
        $obj = Invoke-CaptureResponsive -ExePath $yt.Source -Args @(
            "-J","--no-playlist",
            "--extractor-args","youtube:player_client=default,-web_safari,-web_embedded,-tv",
            $Url
        ) -WorkingText "Consultando formatos…"
        if ($obj.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($obj.StdOut)) {
            Write-Host "[ERROR] No se pudo obtener JSON de formatos." -ForegroundColor Red
            Write-Host $obj.StdErr
            return $false
        }

        try { $json = $obj.StdOut | ConvertFrom-Json } catch {
            Write-Host "[ERROR] JSON inválido al listar formatos." -ForegroundColor Red
            return $false
        }
        $script:lastThumbUrl = Get-BestThumbnailUrl -Json $json
        if (-not $json.formats -or $json.formats.Count -eq 0) {
            Write-Host "[WARN] El extractor no devolvió lista de formatos." -ForegroundColor Yellow
            return $false
        }
        $script:lastFormats = $json.formats
        $script:bestProgId   = $null
        $script:bestProgRank = -1

        foreach ($f in $json.formats) {
            $klass = Classify-Format $f
            # Evitar el pseudo-formato "download" (marcado como watermarked)
            if ($klass.Progressive -and $klass.Id -ne 'download') {
                # ranking sencillo: mayor altura + mayor tbr
                $height = [int]($klass.VRes ? $klass.VRes : 0)
                $tbr    = [int]($klass.Tbr  ? $klass.Tbr  : 0)
                $rank   = ($height * 100000) + $tbr  # peso alto a la resolución
            
                if ($rank -gt $script:bestProgRank) {
                    $script:bestProgRank = $rank
                    $script:bestProgId   = $klass.Id
                }
            }

            $script:formatsIndex[$klass.Id] = $klass
            if ($klass.Progressive -and $script:ExcludedFormatIds -contains $klass.Id) { continue }

            $res = if ($klass.VRes) { "{0}p" -f $klass.VRes } else { "" }
            $sz  = Human-Size $klass.Filesize
            $tbr = if ($klass.Tbr) { "{0}k" -f [math]::Round($klass.Tbr) } else { "" }

            if     ($klass.Progressive) { $script:formatsVideo += (New-FormatDisplay -Id $klass.Id -Label ("{0} {1} {2}/{3} (progresivo) {4} {5}" -f $klass.Ext,$res,$klass.VCodec,$klass.ACodec,$sz,$tbr)) }
            elseif ($klass.VideoOnly)   { $script:formatsVideo += (New-FormatDisplay -Id $klass.Id -Label ("{0} {1} {2} (v-only) {3} {4}" -f $klass.Ext,$res,$klass.VCodec,$sz,$tbr)) }
            elseif ($klass.AudioOnly)   { $script:formatsAudio += (New-FormatDisplay -Id $klass.Id -Label ("{0} ~{1} {2} (a-only) {3}" -f $klass.Ext,$klass.ABr,$klass.ACodec,$sz)) }
        }
            # Headers “best*” (único lugar donde se agregan)
            $progOnly = Is-ProgressiveOnlySite $script:lastExtractor
            
            $headersVideo = @("best — mejor calidad (progresivo si existe; si no, adaptativo)")
            if (-not $progOnly) {
                $headersVideo += "bestvideo — mejor video (sin audio; usar con audio)"
            }
            $script:formatsVideo = ( $headersVideo + $script:formatsVideo ) | Select-Object -Unique
            $script:formatsAudio = ( @("bestaudio — mejor audio disponible") + $script:formatsAudio ) | Select-Object -Unique
            $script:formatsEnumerated = ($script:formatsVideo.Count -gt 0 -or $script:formatsAudio.Count -gt 0)
            if ($json.extractor) { $script:lastExtractor = $json.extractor }
            return $script:formatsEnumerated
    }
    finally {
        if ($lblEstadoConsulta -and $prevLabel) { $lblEstadoConsulta.Text = $prevLabel }
    }
}

function Get-Metadata {
    param([Parameter(Mandatory=$true)][string]$Url)

    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch { return $null }

    $obj = Invoke-CaptureResponsive -ExePath $yt.Source -Args @(
        "-J", "--no-playlist",
        $Url
    ) -WorkingText "Leyendo metadatos…"

    if ($obj.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($obj.StdOut)) { return $null }

    try { $json = $obj.StdOut | ConvertFrom-Json } catch { return $null }

    $thumb = Get-BestThumbnailUrl -Json $json
    [pscustomobject]@{
        Title      = $json.title
        Extractor  = $json.extractor         # p.ej. 'twitch', 'youtube', 'twitter', etc.
        Domain     = $json.webpage_url_domain
        Thumbnail  = $thumb
        Duration   = $json.duration
        Uploader   = $json.uploader
        Json       = $json                   # por si lo quieres reutilizar
    }
}
function Get-SelectedFormatId {
    param([System.Windows.Forms.ComboBox]$Combo)
    if (-not $Combo) { return $null }
    if (-not $Combo.SelectedItem) { return $null }

    $t = [string]$Combo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }

    if ($t -like "best*") { return ($t -split '\s')[0] } # best / bestvideo / bestaudio
    return ($t -split '\s')[0]
}
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
function New-LinkLabel {
    param(
        [string]$Text,
        [string]$Url,
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size
    )
    $ll = New-Object System.Windows.Forms.LinkLabel
    $ll.Text = $Text
    $ll.AutoSize = $false
    $ll.Location = $Location
    $ll.Size = $Size
    $ll.LinkBehavior = [System.Windows.Forms.LinkBehavior]::HoverUnderline
    [void]$ll.Links.Add(0, $Text.Length, $Url)
    $ll.add_LinkClicked({
        param($s,$e)
        try { Start-Process $e.Link.LinkData } catch {}
    })
    return $ll
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
function Get-DownloadExtras {
    param([string]$Extractor, [string]$Domain)

    switch -Regex ($Extractor) {
        'twitch' {
            return @("--hls-use-mpegts", "--retries","10", "--retry-sleep","1", "-N","4")
        }
        'vimeo'  { return @("-N","4") }
        'douyin|tiktok' { return @("-N","4") } # hls segmentado suele ir mejor con paralelo
        default { return @() }
    }
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
Write-Host "[INIT] Cargando UI..." -ForegroundColor Cyan
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
            Write-Host "`t[OK] Chocolatey instalado. Configurando cache..." -ForegroundColor Green
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
        Write-Host "`t[OK] Chocolatey ya está instalado." -ForegroundColor Green
        return $true
    }
}
function Get-YouTubeVideoId {
    param([Parameter(Mandatory=$true)][string]$Url)
    $m = [regex]::Match($Url, 'youtu\.be/([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    $m = [regex]::Match($Url, '[?&]v=([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    $m = [regex]::Match($Url, '/shorts/([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    $m = [regex]::Match($Url, '/embed/([A-Za-z0-9_-]{11})', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}
function Get-CurrentUrl {
    if (-not $txtUrl) { return "" }
    $t = ($txtUrl.Text).Trim()
    if ($t -eq $global:UrlPlaceholder) { return "" }
    return $t
}
function New-HttpClient {
    $hc = [System.Net.Http.HttpClient]::new()
    try {
        $hc.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell-YTDLL")
        $hc.DefaultRequestHeaders.Accept.ParseAdd("image/*")
    } catch {}
    return $hc
}
function Get-ImageFromUrl {
    param([Parameter(Mandatory=$true)][string]$Url)
    $hc = $null
    try {
        $hc = New-HttpClient
        $bytes = $hc.GetByteArrayAsync($Url).Result
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        return [System.Drawing.Image]::FromStream($ms)
    } catch {
        return $null
    } finally {
        if ($hc) { $hc.Dispose() }
    }
}
function Get-TempThumbPattern {
    $tmp = [System.IO.Path]::GetTempPath()
    return (Join-Path $tmp "ytdll_thumb_*")
}
function Fetch-ThumbnailFile {
    param(
        [Parameter(Mandatory=$true)][string]$Url
    )
    try { 
        $yt = Get-Command yt-dlp -ErrorAction Stop 
    } catch { 
        Write-Host "[ERROR] yt-dlp no disponible para descargar miniatura" -ForegroundColor Red
        return $null 
    }
    Get-ChildItem -Path (Get-TempThumbPattern) -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $outTmpl = Join-Path ([System.IO.Path]::GetTempPath()) "ytdll_thumb_%(id)s.%(ext)s"
    $args = @(
        "--skip-download",
        "--quiet",
        "--no-warnings",
        "--write-thumbnail",
        "--convert-thumbnails", "jpg",
        "-o", $outTmpl
    )
    if ($Url -match 'twitch\.tv') {
        Write-Host "[TWITCH] Usando estrategia múltiple para miniaturas..." -ForegroundColor Yellow
        $storyboardArgs = @(
            "--skip-download",
            "--quiet",
            "--no-warnings", 
            "--write-thumbnail",
            "--convert-thumbnails", "jpg",
            "--thumbs", "1",  # Solo la primera miniatura del storyboard
            "-o", $outTmpl,
            $Url
        )
        Write-Host "[TWITCH] Intentando descargar storyboard..." -ForegroundColor Cyan
        $res = Invoke-Capture -ExePath $yt.Source -Args $storyboardArgs
        if ($res.ExitCode -eq 0) {
            $thumb = Get-ChildItem -Path (Get-TempThumbPattern) -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1
            if ($thumb) {
                Write-Host "[TWITCH] Storyboard descargado: $($thumb.FullName)" -ForegroundColor Green
                return $thumb.FullName
            }
        }
        Write-Host "[TWITCH] Falló storyboard, intentando con más fuerza..." -ForegroundColor Yellow
        $args += @(
            "--force-ipv4",
            "--retries", "5", 
            "--socket-timeout", "15",
            "--extractor-args", "twitch:force_source"
        )
    }
    if ($script:cookiesPath) { 
        $args += @("--cookies", $script:cookiesPath) 
    }
    $args += $Url
    Write-Host "[THUMB] Ejecutando yt-dlp para obtener miniatura..." -ForegroundColor Cyan
    $res = Invoke-Capture -ExePath $yt.Source -Args $args
    if ($res.ExitCode -ne 0) {
        Write-Host "[THUMB] Error al obtener miniatura: $($res.StdErr)" -ForegroundColor Red
    }
    $thumb = Get-ChildItem -Path (Get-TempThumbPattern) -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1
    if ($thumb) {
        Write-Host "[THUMB] Miniatura descargada: $($thumb.FullName)" -ForegroundColor Green
        if ($thumb.Extension -eq '.webp') {
            Write-Host "[THUMB] Convirtiendo WEBP a PNG..." -ForegroundColor Yellow
            $png = [IO.Path]::ChangeExtension($thumb.FullName, ".png")
            try {
                $ff = Get-Command ffmpeg -ErrorAction Stop | Select-Object -ExpandProperty Source
                $proc = Start-Process -FilePath $ff -ArgumentList @("-y", "-hide_banner", "-loglevel", "error", "-i", $thumb.FullName, $png) `
                                      -NoNewWindow -PassThru -Wait
                if ($proc.ExitCode -eq 0 -and (Test-Path $png)) {
                    Remove-Item $thumb.FullName -Force -ErrorAction SilentlyContinue
                    return $png
                }
            } catch {
                Write-Host "[THUMB] Error convirtiendo WEBP: $_" -ForegroundColor Red
            }
        }
        
        return $thumb.FullName
    } else {
        Write-Host "[THUMB] No se pudo descargar miniatura con yt-dlp" -ForegroundColor Red
        if ($Url -match 'twitch\.tv') {
            Write-Host "[TWITCH] Usando placeholder para Twitch..." -ForegroundColor Yellow
            return $null
        }
        
        return $null
    }
}
function Show-PreviewUniversal {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [string]$Titulo = $null,
        [string]$DirectThumbUrl = $null
    )
    Write-Host "[PREVIEW] Intentando vista previa para: $Url" -ForegroundColor Cyan
    Write-Host "[PREVIEW] Thumbnail URL: $(if ($DirectThumbUrl) { $DirectThumbUrl } else { 'NULO' })" -ForegroundColor Cyan
    Write-Host "[PREVIEW] Extractor: $($script:lastExtractor)" -ForegroundColor Cyan
    if (-not $DirectThumbUrl -and $script:lastExtractor -match 'twitch') {
        Write-Host "[TWITCH] No hay miniatura directa, intentando construir URL alternativa..." -ForegroundColor Yellow
        $vodId = $script:ultimaURL -replace '.*videos/(\d+).*', '$1'
        if ($vodId -and $vodId -match '^\d+$') {
            $DirectThumbUrl = "https://static-cdn.jtvnw.net/cf_vods/d2vj7p5g7y6u8s/$vodId//thumb/thumb0-1280x720.jpg"
            Write-Host "[TWITCH] URL alternativa construida: $DirectThumbUrl" -ForegroundColor Green
        }
    }
    if ($DirectThumbUrl) {
        Write-Host "[PREVIEW] Usando miniatura directa..." -ForegroundColor Yellow
        if ($DirectThumbUrl -match '\.webp($|\?)') {
            Write-Host "[PREVIEW] Detectado WEBP, intentando conversión..." -ForegroundColor Yellow
            $png = Convert-WebpUrlToPng -Url $DirectThumbUrl
            if ($png -and (Test-Path $png)) {
                try { 
                    if ($picPreview.Image) { $picPreview.Image.Dispose() } 
                    $imgW = [System.Drawing.Image]::FromFile($png)
                    $picPreview.Image = $imgW
                    if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
                    Write-Host "[PREVIEW] Vista previa cargada (WEBP convertido)" -ForegroundColor Green
                    return $true
                } catch {
                    Write-Host "[PREVIEW] Error cargando WEBP convertido: $_" -ForegroundColor Red
                }
            }
        }
        Write-Host "[PREVIEW] Intentando carga directa de imagen..." -ForegroundColor Yellow
        $img1 = Get-ImageFromUrl -Url $DirectThumbUrl
        if ($img1) {
            try { 
                if ($picPreview.Image) { $picPreview.Image.Dispose() } 
                $picPreview.Image = $img1
                if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
                Write-Host "[PREVIEW] Vista previa cargada (directa)" -ForegroundColor Green
                return $true
            } catch {
                Write-Host "[PREVIEW] Error en carga directa: $_" -ForegroundColor Red
            }
        }
        Write-Host "[PREVIEW] Falló carga directa" -ForegroundColor Red
    }
    Write-Host "[PREVIEW] Usando fallback con yt-dlp..." -ForegroundColor Yellow
    $file = Fetch-ThumbnailFile -Url $Url
    if ($file -and (Test-Path -LiteralPath $file)) {
        try {
            $img2 = [System.Drawing.Image]::FromFile($file)
            try { if ($picPreview.Image) { $picPreview.Image.Dispose() } } catch {}
            $picPreview.Image = $img2
            if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
            Write-Host "[PREVIEW] Vista previa cargada (yt-dlp fallback)" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "[PREVIEW] Error cargando thumbnail de yt-dlp: $_" -ForegroundColor Red
            return $false
        }
    }
    Write-Host "[PREVIEW] No se pudo cargar vista previa" -ForegroundColor Red
    Write-Host "[PREVIEW] Probando fallback por fotograma (ffmpeg)..." -ForegroundColor Yellow
        $stream = Get-BestStreamUrl -Url $Url
        if ($stream) {
            $snap = Build-PreviewFromStream -StreamUrl $stream -SeekSec 2
            if ($snap -and (Test-Path $snap)) {
                try {
                    $img3 = [System.Drawing.Image]::FromFile($snap)
                    try { if ($picPreview.Image) { $picPreview.Image.Dispose() } } catch {}
                    $picPreview.Image = $img3
                    if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
                    Write-Host "[PREVIEW] Vista previa cargada (fotograma HLS)" -ForegroundColor Green
                    return $true
                } catch {
                    Write-Host "[PREVIEW] Error cargando fotograma: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "[PREVIEW] No se pudo generar fotograma de HLS." -ForegroundColor Red
            }
        }
    return $false
}
function Show-PreviewImage {
    param(
        [Parameter(Mandatory=$true)][string]$ImageUrl,
        [string]$Titulo = $null
    )
    try {
        if ($ImageUrl -match '\.webp($|\?)') {
            $png = Convert-WebpUrlToPng -Url $ImageUrl
            if ($png -and (Test-Path $png)) {
                try { if ($picPreview.Image) { $picPreview.Image.Dispose() } } catch {}
                $imgW = [System.Drawing.Image]::FromFile($png)
                $picPreview.Image = $imgW
                if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
                return $true
            }
            return $false
        }

        $img = Get-ImageFromUrl -Url $ImageUrl
        if ($img) {
            try { if ($picPreview.Image) { $picPreview.Image.Dispose() } } catch {}
            $picPreview.Image = $img
            if ($Titulo) { $toolTip.SetToolTip($picPreview, $Titulo) }
            return $true
        }
        return $false
    } catch {
        return $false
    }
}
function Get-BestThumbnailUrl {
    param([Parameter(Mandatory=$true)]$Json)
    $candidate = $null
    if ($Json.thumbnail -and -not [string]::IsNullOrWhiteSpace($Json.thumbnail)) {
        $candidate = [string]$Json.thumbnail
    }
    if (-not $candidate -and $Json.thumbnails -and $Json.thumbnails.Count -gt 0) {
        $ordered = $Json.thumbnails | Sort-Object @{Expression='preference';Descending=$true}, @{Expression='width';Descending=$true}
        $thumbNonWebp = $ordered | Where-Object { $_.url -and ($_.url -notmatch '\.webp($|\?)') } | Select-Object -First 1
        if ($thumbNonWebp?.url) { $candidate = [string]$thumbNonWebp.url }
        if (-not $candidate) {
            $thumb = $ordered | Select-Object -First 1
            if ($thumb?.url) { $candidate = [string]$thumb.url }
        }
    }
    if ($candidate) {
        $candidate = Normalize-ThumbUrl -Url $candidate -Extractor $Json.extractor
    }

    return $candidate
}
function Get-BestStreamUrl {
    param([Parameter(Mandatory=$true)][string]$Url)
    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch { return $null }
    $args = @("-g","-f","best",$Url)
    if ($script:cookiesPath) { $args += @("--cookies",$script:cookiesPath) }
    $res = Invoke-Capture -ExePath $yt.Source -Args $args
    if ($res.ExitCode -ne 0) { return $null }
    $line = ($res.StdOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    return ([string]$line).Trim()
}
function Build-PreviewFromStream {
    param(
        [Parameter(Mandatory=$true)][string]$StreamUrl,
        [int]$SeekSec = 2
    )
    try { $ff = (Get-Command ffmpeg -ErrorAction Stop).Source } catch { return $null }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ytdll_snap_{0}.jpg" -f ([guid]::NewGuid()))
    $args = @(
        "-y","-hide_banner","-loglevel","error",
        "-ss", $SeekSec.ToString(),
        "-i", $StreamUrl,
        "-frames:v","1",
        "-vf","scale=1280:-2",
        $tmp
    )
    $env:FFREPORT=""
    $p = Start-Process -FilePath $ff -ArgumentList $args -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -eq 0 -and (Test-Path $tmp)) { return $tmp }
    return $null
}
function Invoke-ConsultaFromUI {
    param(
        [Parameter(Mandatory=$true)][string]$Url
    )
    Refresh-GateByDeps
    if ([string]::IsNullOrWhiteSpace($Url)) {
        [System.Windows.Forms.MessageBox]::Show("Escribe una URL de YouTube.","Falta URL",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }
    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
        [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible. Valídalo en Dependencias.","yt-dlp no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return $false
    }
    Write-Host ("[CONSULTA] Consultando URL: {0}" -f $Url) -ForegroundColor Cyan
    $res = Invoke-CaptureResponsive -ExePath $yt.Source `
           -Args @("--no-playlist","--get-title",$Url) `
           -WorkingText "Consultando URL…"
    $titulo = ($res.StdOut + "`n" + $res.StdErr).Trim() -split "`r?`n" |
              Where-Object { $_.Trim() -ne "" } | Select-Object -First 1
    if ($res.ExitCode -ne 0 -or -not $titulo) {
        $script:videoConsultado = $false; $script:ultimaURL = $null; $script:ultimoTitulo = $null
        $lblEstadoConsulta.Text = "Error al consultar la URL"; $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::Red
        $picPreview.Image = $null
        Write-Host "[ERROR] No se pudo consultar el video." -ForegroundColor Red
        return $false
    }
    $script:videoConsultado = $true
    $script:ultimaURL       = $Url
    $script:ultimoTitulo    = $titulo
    $lblEstadoConsulta.Text = ("Consultado: {0}" -f $titulo)
    $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::ForestGreen
    Write-Host ("`t[OK] Video consultado: {0}" -f $titulo) -ForegroundColor Green
    $cmbVideoFmt.Items.Clear()
        $prevLabelText = $lblEstadoConsulta.Text
        $lblEstadoConsulta.Text = "Consultando formatos…"
        $meta = Get-Metadata -Url $Url
        $script:lastExtractor = $meta?.Extractor
        $script:lastDomain    = $meta?.Domain
        $script:lastThumbUrl  = $meta?.Thumbnail
        if ($meta -and $meta.Thumbnail) { $script:lastThumbUrl = $meta.Thumbnail }
        try {
            if (Fetch-Formats -Url $Url) {
                foreach ($i in $script:formatsVideo) { [void]$cmbVideoFmt.Items.Add($i) }
                foreach ($i in $script:formatsAudio) { [void]$cmbAudioFmt.Items.Add($i) }
                if ($cmbVideoFmt.Items.Count -gt 0) {
                    $progOnly = Is-ProgressiveOnlySite $script:lastExtractor
                    if ($progOnly -and $script:bestProgId) {
                        $idx = 0
                        for ($n=0; $n -lt $cmbVideoFmt.Items.Count; $n++) {
                            if ($cmbVideoFmt.Items[$n].ToString().StartsWith($script:bestProgId)) { $idx = $n; break }
                        }
                        $cmbVideoFmt.SelectedIndex = $idx
                        try { $cmbAudioFmt.Enabled = $false } catch {}
                    } else {
                        $idx = 0
                        for ($n=0; $n -lt $cmbVideoFmt.Items.Count; $n++) {
                            $s = $cmbVideoFmt.Items[$n].ToString()
                            if ($s.StartsWith("bestvideo")) { $idx = $n; break }
                            if ($s.StartsWith("best"))      { $idx = $n }
                        }
                        $cmbVideoFmt.SelectedIndex = $idx
                        try { $cmbAudioFmt.Enabled = $true } catch {}
                    }
                }
                if ($cmbAudioFmt.Items.Count -gt 0) {
                    $idx = 0
                    for ($n=0; $n -lt $cmbAudioFmt.Items.Count; $n++) {
                        if ($cmbAudioFmt.Items[$n].ToString().StartsWith("bestaudio")) { $idx = $n; break }
                    }
                    $cmbAudioFmt.SelectedIndex = $idx
                }
            }
            else {
                $script:formatsEnumerated = $false
                $cmbVideoFmt.Items.Clear()
                $cmbAudioFmt.Items.Clear()
                Write-Host "[WARN] No se pudieron enumerar formatos. Pide volver a consultar." -ForegroundColor Yellow
                $lblEstadoConsulta.Text = "No fue posible extraer formatos. Vuelve a consultar."
                $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::DarkOrange
                Set-DownloadButtonVisual
                return $false
            }
        }
        finally {
            $lblEstadoConsulta.Text = $prevLabelText
        }
    $shown = $false
        $thumbDirect = $script:lastThumbUrl
        if ($thumbDirect) {
            $thumbDirect = Normalize-ThumbUrl -Url $thumbDirect -Extractor $script:lastExtractor
        }
        $null = Show-PreviewUniversal -Url $Url -Titulo $titulo -DirectThumbUrl $thumbDirect
    if ($script:formatsEnumerated -and $script:lastFormats) {
        Print-FormatsTable -formats $script:lastFormats
    }
    if ($script:formatsEnumerated) {
        Add-HistoryUrl -Url $Url
    }
    return $true
}
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
            Start-Process -FilePath "choco" -ArgumentList @("install",$ChocoPkg,"-y") -NoNewWindow -Wait
            $version = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse
            if ($version) {
                $LabelRef.Value.Text = ("{0}: {1}" -f $FriendlyName,$version)
                $LabelRef.Value.ForeColor = [System.Drawing.Color]::ForestGreen
                Write-Host ("`t[OK] {0} instalado: {1}" -f $FriendlyName,$version) -ForegroundColor Green
                [System.Windows.Forms.MessageBox]::Show(
                    ("{0} se instaló correctamente.`n`nPara que el PATH y las variables se apliquen, cierre y vuelva a abrir PowerShell.`nLa aplicación se cerrará ahora." -f $FriendlyName),
                    "Reinicio de PowerShell requerido",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                try { $formPrincipal.Close(); $formPrincipal.Dispose() } catch {}
                Stop-Process -Id $PID -Force
            }
            else {
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
        Write-Host ("`t[OK] {0} detectado: {1}" -f $FriendlyName,$version) -ForegroundColor Green
    }
}
function Ensure-ToolHeadless {
    param(
        [Parameter(Mandatory=$true)][string]$CommandName,
        [Parameter(Mandatory=$true)][string]$FriendlyName,
        [Parameter(Mandatory=$true)][string]$ChocoPkg,
        [string]$VersionArgs="--version",
        [ValidateSet("FirstLine","Raw")][string]$Parse="FirstLine"
    )
    Write-Host ("[CHECK] (headless) Verificando {0}..." -f $FriendlyName) -ForegroundColor Cyan
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
            Write-Host ("[CANCEL] Usuario omitió instalación de {0}." -f $FriendlyName) -ForegroundColor Yellow
            return $false
        }
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Chocolatey no está disponible. Instálalo para continuar.",
                "Chocolatey requerido",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return $false
        }
        Write-Host ("[INSTALL] (headless) choco install {0} -y" -f $ChocoPkg) -ForegroundColor Cyan
        try {
            Start-Process -FilePath "choco" -ArgumentList @("install",$ChocoPkg,"-y") -NoNewWindow -Wait
        } catch {
            Write-Host ("[ERROR] Falló instalación de {0}: {1}" -f $FriendlyName,$_ ) -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show(
                ("No se pudo instalar {0} automáticamente." -f $FriendlyName),
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return $false
        }
        $version = Get-ToolVersion -Command $CommandName -ArgsForVersion $VersionArgs -Parse $Parse
        if (-not $version) {
            [System.Windows.Forms.MessageBox]::Show(
                ("{0} fue instalado. Cierre y vuelva a abrir PowerShell para refrescar el PATH. La aplicación se cerrará." -f $FriendlyName),
                "Reinicio de PowerShell requerido",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            Stop-Process -Id $PID -Force
            return $false
        }
    }
    Write-Host ("`t[OK] {0} detectado." -f $FriendlyName) -ForegroundColor Green
    return $true
}
function Initialize-AppHeadless {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    if (-not (Check-Chocolatey)) {
        Write-Host "[EXIT] Falta Chocolatey o se requiere reinicio." -ForegroundColor Yellow
        return $false
    }
    if (-not (Ensure-ToolHeadless -CommandName "yt-dlp" -FriendlyName "yt-dlp" -ChocoPkg "yt-dlp" -VersionArgs "--version")) { return $false }
    if (-not (Ensure-ToolHeadless -CommandName "ffmpeg" -FriendlyName "ffmpeg" -ChocoPkg "ffmpeg" -VersionArgs "-version")) { return $false }
    if ($script:RequireNode) {
        if (-not (Ensure-ToolHeadless -CommandName "node" -FriendlyName "Node.js" -ChocoPkg "nodejs-lts" -VersionArgs "--version")) { return $false }
    }

    return $true
}
if (-not (Initialize-AppHeadless)) {
    return
}
function Show-AppInfo {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Información de la aplicación"
    $f.Size = New-Object System.Drawing.Size(520, 600)
    $f.StartPosition = "CenterParent"
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.BackColor = [System.Drawing.Color]::White
    $lblTitulo = Create-Label -Text "YTDLL — Información" `
        -Location (New-Object System.Drawing.Point(20,16)) `
        -Size (New-Object System.Drawing.Size(460,28)) `
        -Font (New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold))
    $lblVer = Create-Label -Text ("Versión: {0}" -f $version) `
        -Location (New-Object System.Drawing.Point(20,46)) `
        -Size (New-Object System.Drawing.Size(460,22)) `
        -Font $defaultFont
    $lblCamb = Create-Label -Text "Cambios recientes:" `
        -Location (New-Object System.Drawing.Point(20,76)) `
        -Size (New-Object System.Drawing.Size(460,20)) `
        -Font $boldFont
    $psBlue = [System.Drawing.Color]::FromArgb(1,36,86)      # Azul PS clásico
    $psText = [System.Drawing.Color]::Gainsboro              # Texto claro
    $fontCambios = New-Object System.Drawing.Font("Consolas", 10)
    if ($fontCambios.Name -ne "Consolas") {
        $fontCambios = New-Object System.Drawing.Font("Lucida Console", 10)
    }
    $logCambios = $global:defaultInstructions -replace "`r?`n","`r`n"
    $txtCamb = New-Object System.Windows.Forms.RichTextBox
    $txtCamb.Location   = New-Object System.Drawing.Point(20, 98)
    $txtCamb.Size       = New-Object System.Drawing.Size(460, 150)
    $txtCamb.ReadOnly   = $true
    $txtCamb.BorderStyle= [System.Windows.Forms.BorderStyle]::None
    $txtCamb.BackColor  = $psBlue
    $txtCamb.ForeColor  = $psText
    $txtCamb.Font       = $fontCambios
    $txtCamb.Multiline  = $true
    $txtCamb.WordWrap   = $false                              # NO envolver; respeta renglones
    $txtCamb.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both
    $txtCamb.DetectUrls = $false
    $txtCamb.Text       = $logCambios
    $lblDeps = Create-Label -Text "Dependencias detectadas:" `
        -Location (New-Object System.Drawing.Point(20,258)) `
        -Size (New-Object System.Drawing.Size(460,22)) `
        -Font $boldFont
    $txtDeps = Create-TextBox `
        -Location (New-Object System.Drawing.Point(20,282)) `
        -Size (New-Object System.Drawing.Size(460,90)) `
        -BackColor ([System.Drawing.Color]::White) `
        -ForeColor ([System.Drawing.Color]::Black) `
        -Font $defaultFont `
        -Multiline $true `
        -ReadOnly $true
    $ytVer  = (Get-ToolVersion -Command "yt-dlp" -ArgsForVersion "--version" -Parse "FirstLine")
    $ffVer  = (Get-ToolVersion -Command "ffmpeg" -ArgsForVersion "-version"  -Parse "FirstLine")
    $ndVer  = if ($script:RequireNode) { (Get-ToolVersion -Command "node" -ArgsForVersion "--version" -Parse "FirstLine") } else { $null }
    $txtDeps.Text = @(
        ("yt-dlp: " + ($ytVer  ? $ytVer : "no instalado"))
        ("ffmpeg: " + ($ffVer  ? $ffVer : "no instalado"))
        ($script:RequireNode ? ("Node.js: " + ($ndVer ? $ndVer : "no instalado")) : $null)
    ) | Where-Object { $_ } | Out-String
    $lblLinks = Create-Label -Text "Proyectos:" `
        -Location (New-Object System.Drawing.Point(20, 378)) `
        -Size (New-Object System.Drawing.Size(460, 22)) `
        -Font $boldFont
    $lnkApp = New-LinkLabel -Text "PWytdll (GitHub)" `
              -Url "https://github.com/water0ff/PWytdll/tree/main" `
              -Location (New-Object System.Drawing.Point(20, 404)) `
              -Size (New-Object System.Drawing.Size(460, 20))
    $lnkYt  = New-LinkLabel -Text "yt-dlp" `
              -Url "https://github.com/yt-dlp/yt-dlp" `
              -Location (New-Object System.Drawing.Point(20, 428)) `
              -Size (New-Object System.Drawing.Size(460, 20))
    $lnkFf  = New-LinkLabel -Text "FFmpeg" `
              -Url "https://ffmpeg.org/" `
              -Location (New-Object System.Drawing.Point(20, 452)) `
              -Size (New-Object System.Drawing.Size(460, 20))
    $lnkNd  = New-LinkLabel -Text "Node.js" `
              -Url "https://nodejs.org/" `
              -Location (New-Object System.Drawing.Point(20, 476)) `
              -Size (New-Object System.Drawing.Size(460, 20))
    $btnCerrar = Create-Button -Text "Cerrar" `
        -Location (New-Object System.Drawing.Point(380, 506)) `
        -Size (New-Object System.Drawing.Size(100, 30)) `
        -BackColor ([System.Drawing.Color]::Black) `
        -ForeColor ([System.Drawing.Color]::White) `
        -ToolTipText "Cerrar esta ventana"
    $btnCerrar.Add_Click({ $f.Close() })

    $f.Controls.AddRange(@(
        $lblTitulo,$lblVer,$lblCamb,$txtCamb,
        $lblDeps,$txtDeps,
        $lblLinks,$lnkApp,$lnkYt,$lnkFf,$lnkNd,
        $btnCerrar
    ))
    $f.ShowDialog() | Out-Null
}
$script:videoConsultado   = $false
$script:ultimaURL         = $null
$script:ultimoTitulo      = $null
$script:lastThumbUrl      = $null
$script:formatsEnumerated = $false
$script:cookiesPath = $null
$script:ultimaRutaDescarga = [Environment]::GetFolderPath('Desktop')
$global:UrlPlaceholder = "Escribe la URL del video"
$btnPickCookies = Create-IconButton -Text "🍪" `
    -Location (New-Object System.Drawing.Point(324, 10)) `
    -ToolTipText "Seleccionar cookies.txt (opcional)"
$btnInfo = Create-IconButton -Text "?" `
    -Location (New-Object System.Drawing.Point(354, 10)) `
    -ToolTipText "Información de la aplicación"
$btnInfo.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$btnInfo.Size = New-Object System.Drawing.Size(26, 24)
$btnInfo.Add_Click({ Show-AppInfo })

$lblDestino = Create-Label -Text "Carpeta de destino:" `
    -Location (New-Object System.Drawing.Point(20, 15)) `
    -Size (New-Object System.Drawing.Size(360, 20)) -Font $boldFont
$txtDestino = Create-TextBox `
    -Location (New-Object System.Drawing.Point(20, 38)) `
    -Size (New-Object System.Drawing.Size(330, 26)) `
    -ReadOnly $true `
    -Text $script:ultimaRutaDescarga
$btnPickDestino = Create-IconButton -Text "📁" `
    -Location (New-Object System.Drawing.Point(356, 38)) `
    -ToolTipText "Cambiar carpeta de destino"
$lblVideoFmt = Create-Label -Text "Formato de VIDEO:" `
    -Location (New-Object System.Drawing.Point(20, 70)) `
    -Size (New-Object System.Drawing.Size(360, 20)) -Font $boldFont
$cmbVideoFmt = Create-ComboBox `
    -Location (New-Object System.Drawing.Point(20, 93)) `
    -Size (New-Object System.Drawing.Size(360, 28))
$lblAudioFmt = Create-Label -Text "Formato de AUDIO:" `
    -Location (New-Object System.Drawing.Point(20, 125)) `
    -Size (New-Object System.Drawing.Size(360, 20)) -Font $boldFont
$cmbAudioFmt = Create-ComboBox `
    -Location (New-Object System.Drawing.Point(20, 148)) `
    -Size (New-Object System.Drawing.Size(360, 28))
$txtUrl = Create-TextBox `
    -Location (New-Object System.Drawing.Point(20, 180)) `
    -Size (New-Object System.Drawing.Size(360, 150)) `
    -Font (New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Regular)) `
    -Text $global:UrlPlaceholder `
    -BackColor ([System.Drawing.Color]::White) `
    -ForeColor ([System.Drawing.Color]::Gray)
$ctxUrlHistory = New-Object System.Windows.Forms.ContextMenuStrip
$lblEstadoConsulta = Create-Label `
    -Text "Estado: sin consultar" `
    -Location (New-Object System.Drawing.Point(20, 530)) `
    -Size (New-Object System.Drawing.Size(360, 44)) `
    -Font $defaultFont `
    -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle) `
    -TextAlign ([System.Drawing.ContentAlignment]::TopLeft)
$lblEstadoConsulta.Font = New-Object System.Drawing.Font("Consolas", 9)
    $lblEstadoConsulta.AutoEllipsis = $true
    $lblEstadoConsulta.UseCompatibleTextRendering = $true
$btnConsultar = Create-Button -Text "Consultar" `
    -Location (New-Object System.Drawing.Point(100, 100)) `
    -Size (New-Object System.Drawing.Size(100, 100)) `
    -BackColor ([System.Drawing.Color]::White) `
    -ForeColor ([System.Drawing.Color]::Black) `
    -ToolTipText "Obtener información del video"
    $btnConsultar.Visible = $false
    $btnConsultar.Enabled = $false
$btnDescargar = Create-Button -Text "Descargar" `
    -Location (New-Object System.Drawing.Point(20, 250)) `
    -Size (New-Object System.Drawing.Size(360, 65)) `
    -BackColor ([System.Drawing.Color]::Black) `
    -ForeColor ([System.Drawing.Color]::White) `
    -ToolTipText "Descargar usando bestvideo+bestaudio -> mp4"
    Set-DownloadButtonVisual
$lblPreview = Create-Label -Text "Vista previa:" `
    -Location (New-Object System.Drawing.Point(20, 300)) `
    -Size (New-Object System.Drawing.Size(360, 22)) `
    -Font $boldFont
$picPreview = New-Object System.Windows.Forms.PictureBox
    $picPreview.Location   = New-Object System.Drawing.Point(20, 325)
    $picPreview.Size       = New-Object System.Drawing.Size(360, 203)
    $picPreview.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $picPreview.SizeMode   = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $picPreview.BackColor  = [System.Drawing.Color]::White
$lblTituloDeps = Create-Label -Text "Dependencias:" -Location (New-Object System.Drawing.Point(20, 590)) -Size (New-Object System.Drawing.Size(360, 24)) -Font $boldFont
$lblYtDlp      = Create-Label -Text "yt-dlp: verificando..." -Location (New-Object System.Drawing.Point(80, 620)) -Size (New-Object System.Drawing.Size(300, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$lblFfmpeg     = Create-Label -Text "ffmpeg: verificando..." -Location (New-Object System.Drawing.Point(80, 650)) -Size (New-Object System.Drawing.Size(300, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$lblNode       = Create-Label -Text "Node.js: verificando..." -Location (New-Object System.Drawing.Point(80, 680)) -Size (New-Object System.Drawing.Size(300, 24)) -Font $defaultFont -BorderStyle ([System.Windows.Forms.BorderStyle]::FixedSingle)
$btnExit    = Create-Button -Text "Salir"    -Location (New-Object System.Drawing.Point(20, 720)) -BackColor ([System.Drawing.Color]::Black) -ForeColor ([System.Drawing.Color]::White) -ToolTipText "Cerrar la aplicación" -Size (New-Object System.Drawing.Size(180, 35))
$btnYtRefresh   = Create-IconButton -Text "↻" -Location (New-Object System.Drawing.Point(20, 620)) -ToolTipText "Buscar/actualizar yt-dlp"
$btnYtUninstall = Create-IconButton -Text "✖" -Location (New-Object System.Drawing.Point(48, 620)) -ToolTipText "Desinstalar yt-dlp"
function Show-UrlHistoryMenu {
    $ctxUrlHistory.Items.Clear()
    $items = @(Get-HistoryUrls)
    if (-not $items -or $items.Count -eq 0) {
        $miEmpty = New-Object System.Windows.Forms.ToolStripMenuItem
        $miEmpty.Text = "(Sin historial)"
        $miEmpty.Enabled = $false
        [void]$ctxUrlHistory.Items.Add($miEmpty)
    } else {
        $top = [Math]::Min(12, $items.Count)
        for ($i=0; $i -lt $top; $i++) {
            $urlItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $urlItem.Text = $items[$i]
            $urlItem.ToolTipText = $items[$i]
            $urlItem.add_Click({
                param($sender, $e)
                $url = [string]($sender -as [System.Windows.Forms.ToolStripMenuItem]).Text
                $txtUrl.Text = $url
                $txtUrl.ForeColor = [System.Drawing.Color]::Black
                $txtUrl.SelectionStart = $txtUrl.Text.Length
                $txtUrl.SelectionLength = 0
            })
            [void]$ctxUrlHistory.Items.Add($urlItem)
        }
    }

    if ($ctxUrlHistory.Items.Count -gt 0) {
        [void]$ctxUrlHistory.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    }
    $miClear = New-Object System.Windows.Forms.ToolStripMenuItem
    $miClear.Text = "Borrar historial"
    $miClear.ForeColor = [System.Drawing.Color]::Crimson
    $miClear.add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            "¿Seguro que deseas borrar el historial de URLs?",
            "Confirmar", [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($r -eq [System.Windows.Forms.DialogResult]::Yes) {
            Clear-History
        }
    })
    [void]$ctxUrlHistory.Items.Add($miClear)
    $pt = New-Object System.Drawing.Point(0, $txtUrl.Height)
    $ctxUrlHistory.Show($txtUrl, $pt)
}
$txtUrl.Add_GotFocus({
    if ($this.Text -eq $global:UrlPlaceholder) {
        $this.Text = ""
        $this.ForeColor = [System.Drawing.Color]::Black
    }
    Show-UrlHistoryMenu   # abrir historial al primer foco
})
$txtUrl.Add_MouseUp({
    param($s,$e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        Show-UrlHistoryMenu
    }
})
$txtUrl.ContextMenuStrip = $ctxUrlHistory
$txtUrl.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($this.Text)) {
        $this.Text = $global:UrlPlaceholder
        $this.ForeColor = [System.Drawing.Color]::Gray
    }
})
$txtUrl.Add_TextChanged({ Set-DownloadButtonVisual })

$btnPickCookies.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title = "Selecciona cookies.txt"
    $ofd.Filter = "Cookies (*.txt)|*.txt|Todos (*.*)|*.*"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:cookiesPath = $ofd.FileName
        [System.Windows.Forms.MessageBox]::Show("Cookies configuradas: $($script:cookiesPath)","OK") | Out-Null
    }
})
if ($script:cookiesPath) {
    $args += @("--cookies", $script:cookiesPath)
}
$btnSites = Create-Button -Text "Sitios compatibles" `
    -Location (New-Object System.Drawing.Point(200, 720)) `
    -Size (New-Object System.Drawing.Size(180, 35)) `
    -BackColor ([System.Drawing.Color]::White) `
    -ForeColor ([System.Drawing.Color]::Black) `
    -ToolTipText "Mostrar extractores de yt-dlp"

$btnSites.Add_Click({
    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
        [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible.","Error") | Out-Null
        return
    }
    $res = Invoke-CaptureResponsive -ExePath $yt.Source -Args @("--list-extractors") -WorkingText "Obteniendo sitios…"
        $raw = ($res.StdOut + "`r`n" + $res.StdErr)
        $fmt  = Format-ExtractorsInline -RawText $raw -WrapAt 120
        $allSites = [System.Collections.ArrayList]::new()
        $null = $allSites.AddRange($fmt.List)
        $dlg = Create-Form -Title ("Sitios compatibles — {0} detectados" -f $fmt.Count) `
                           -Size (New-Object System.Drawing.Size(900, 560))
        $txtFiltro = Create-TextBox -Location (New-Object System.Drawing.Point(10,10)) `
                                    -Size (New-Object System.Drawing.Size(780,28)) `
                                    -Text "(buscar sitio)"
        $txtFiltro.ForeColor = [System.Drawing.Color]::Gray
        
        $txtFiltro.Add_GotFocus({
            if ($this.Text -eq "(buscar sitio)") { $this.Text = ""; $this.ForeColor = [System.Drawing.Color]::Black }
        })
        $txtFiltro.Add_LostFocus({
            if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = "(buscar sitio)"; $this.ForeColor = [System.Drawing.Color]::Gray }
        })
        $lblCount = Create-Label -Text ("0/{0}" -f $allSites.Count) `
            -Location (New-Object System.Drawing.Point(800, 12)) `
            -Size (New-Object System.Drawing.Size(80,28)) `
            -TextAlign ([System.Drawing.ContentAlignment]::MiddleRight)
        $lst = New-Object System.Windows.Forms.ListBox
        $lst.Location = New-Object System.Drawing.Point(10, 44)
        $lst.Size     = New-Object System.Drawing.Size(864, 440)
        $lst.Font     = New-Object System.Drawing.Font("Consolas", 9)
        $lst.IntegralHeight = $false
        $btnCopy = Create-Button -Text "Copiar selección" `
            -Location (New-Object System.Drawing.Point(664, 490)) `
            -Size (New-Object System.Drawing.Size(120, 30))
        $btnClose = Create-Button -Text "Cerrar" `
            -Location (New-Object System.Drawing.Point(794, 490)) `
            -Size (New-Object System.Drawing.Size(80, 30))
        function Refresh-List([string]$term) {
            $lst.BeginUpdate()
            try {
                $lst.Items.Clear()
                $items = $allSites
                if ($term -and $term -ne "(buscar sitio)") {
                    $rx = [regex]::Escape($term)
                    $items = $allSites | Where-Object { $_ -match $rx }
                }
                $items | ForEach-Object { [void]$lst.Items.Add($_) }
                $lblCount.Text = ("{0}/{1}" -f $lst.Items.Count, $allSites.Count)
            } finally {
                $lst.EndUpdate()
            }
        }
        Refresh-List $null
        $txtFiltro.Add_TextChanged({
            if ($this.ForeColor -eq [System.Drawing.Color]::Gray) { return } # aún placeholder
            Refresh-List $this.Text.Trim()
        })
        $btnCopy.Add_Click({
            if ($lst.SelectedItem) {
                try { [System.Windows.Forms.Clipboard]::SetText([string]$lst.SelectedItem) } catch {}
            }
        })
        $lst.Add_DoubleClick({ if ($lst.SelectedItem) { try { [System.Windows.Forms.Clipboard]::SetText([string]$lst.SelectedItem) } catch {} } })
        $lst.Add_KeyDown({
            param($s,$e)
            if ($e.KeyCode -eq 'Enter' -and $lst.SelectedItem) {
                try { [System.Windows.Forms.Clipboard]::SetText([string]$lst.SelectedItem) } catch {}
                $e.Handled = $true
            }
        })
        $btnClose.Add_Click({ $dlg.Close() })
        $dlg.Controls.Add($txtFiltro)
        $dlg.Controls.Add($lblCount)
        $dlg.Controls.Add($lst)
        $dlg.Controls.Add($btnCopy)
        $dlg.Controls.Add($btnClose)
        $dlg.ShowDialog() | Out-Null
})
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
$btnYtRefresh.Add_Click({
    Update-Dependency -ChocoPkg "yt-dlp" -FriendlyName "yt-dlp" -CommandName "yt-dlp" -LabelRef ([ref]$lblYtDlp) -VersionArgs "--version" -Parse "FirstLine"
})
$btnYtUninstall.Add_Click({
    Uninstall-Dependency -ChocoPkg "yt-dlp" -FriendlyName "yt-dlp" -LabelRef ([ref]$lblYtDlp)
})
$btnFfmpegRefresh   = Create-IconButton -Text "↻" -Location (New-Object System.Drawing.Point(20, 650)) -ToolTipText "Buscar/actualizar ffmpeg"
$btnFfmpegUninstall = Create-IconButton -Text "✖" -Location (New-Object System.Drawing.Point(48, 650)) -ToolTipText "Desinstalar ffmpeg"
$btnFfmpegRefresh.Add_Click({
    Update-Dependency -ChocoPkg "ffmpeg" -FriendlyName "ffmpeg" -CommandName "ffmpeg" -LabelRef ([ref]$lblFfmpeg) -VersionArgs "-version" -Parse "FirstLine"
})
$btnFfmpegUninstall.Add_Click({
    Uninstall-Dependency -ChocoPkg "ffmpeg" -FriendlyName "ffmpeg" -LabelRef ([ref]$lblFfmpeg)
})

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
    $formPrincipal.Controls.Add($lblTituloDeps)
    $formPrincipal.Controls.Add($lblNode)
    $formPrincipal.Controls.Add($lblYtDlp)
    $formPrincipal.Controls.Add($lblFfmpeg)
    $formPrincipal.Controls.Add($btnExit)
    $formPrincipal.Controls.Add($btnFfmpegRefresh)
    $formPrincipal.Controls.Add($btnFfmpegUninstall)
    $formPrincipal.Controls.Add($btnYtRefresh)
    $formPrincipal.Controls.Add($btnYtUninstall)
    $formPrincipal.Controls.Add($lblVideoFmt)
    $formPrincipal.Controls.Add($cmbVideoFmt)
    $formPrincipal.Controls.Add($lblAudioFmt)
    $formPrincipal.Controls.Add($cmbAudioFmt)
    $formPrincipal.Controls.Add($lblDestino)
    $formPrincipal.Controls.Add($txtDestino)
    $formPrincipal.Controls.Add($btnPickDestino)
    $formPrincipal.Controls.Add($btnSites)
    $formPrincipal.Controls.Add($btnPickCookies)
    $formPrincipal.Controls.Add($lblPreview)
    $formPrincipal.Controls.Add($picPreview)
    $formPrincipal.Controls.Add($txtUrl)
    $formPrincipal.Controls.Add($lblEstadoConsulta)
    $formPrincipal.Controls.Add($btnConsultar)
    $formPrincipal.Controls.Add($btnDescargar)
    $formPrincipal.Controls.Add($btnInfo)
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
    $prevBtnState = $null
    if ($btnConsultar) { $prevBtnState = $btnConsultar.Enabled; $btnConsultar.Enabled = $false }
    $prevLabel = $null
    if ($lblEstadoConsulta) { $prevLabel = $lblEstadoConsulta.Text; $lblEstadoConsulta.Text = $WorkingText }
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
        if ($btnConsultar -and $prevBtnState -ne $null) { $btnConsultar.Enabled = $prevBtnState }
    }
    $stdout = ""; $stderr = ""
    try { if (Test-Path $outFile) { $stdout = [IO.File]::ReadAllText($outFile) } } catch {}
    try { if (Test-Path $errFile) { $stderr = [IO.File]::ReadAllText($errFile) } } catch {}
    try { Remove-Item -Path $outFile,$errFile -ErrorAction SilentlyContinue } catch {}
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
function Save-Bytes {
    param([byte[]]$Bytes,[string]$Path)
    [System.IO.File]::WriteAllBytes($Path, $Bytes)
    return $Path
}
function Convert-WebpUrlToPng {
    param([Parameter(Mandatory=$true)][string]$Url)
    try {
        $ff = Get-Command ffmpeg -ErrorAction Stop | Select-Object -ExpandProperty Source
    } catch { return $null }  # sin ffmpeg no podemos convertir
    $hc = $null
    try {
        $hc = New-HttpClient
        $bytes = $hc.GetByteArrayAsync($Url).Result
        $tmpIn  = Join-Path ([IO.Path]::GetTempPath()) ("ytdll_webp_{0}.webp" -f ([guid]::NewGuid()))
        $tmpOut = [IO.Path]::ChangeExtension($tmpIn, ".png")
        Save-Bytes -Bytes $bytes -Path $tmpIn | Out-Null
        $p = Start-Process -FilePath $ff -ArgumentList @("-y","-hide_banner","-loglevel","error","-i", $tmpIn, $tmpOut) `
                           -NoNewWindow -PassThru
        $p.WaitForExit()
        if ($p.ExitCode -eq 0 -and (Test-Path $tmpOut)) { return $tmpOut }
        return $null
    } catch { return $null }
    finally { if ($hc) { $hc.Dispose() } }
}
function Invoke-YtDlpConsoleProgress {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [Parameter(Mandatory=$true)][string[]]$Args,
        [switch]$UpdateUi
    )
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    $global:ProgressPreference = 'SilentlyContinue'
    $tmpDir  = [System.IO.Path]::GetTempPath()
    $errFile = Join-Path $tmpDir ("yt-dlp-stderr_{0}.log" -f ([guid]::NewGuid()))
    $outFile = Join-Path $tmpDir ("yt-dlp-stdout_{0}.log" -f ([guid]::NewGuid()))
    $argLine = ($Args | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '
    $proc = Start-Process -FilePath $ExePath `
        -ArgumentList $argLine `
        -NoNewWindow -PassThru `
        -RedirectStandardError  $errFile `
        -RedirectStandardOutput $outFile
    $fsErr = [System.IO.File]::Open($errFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $srErr = New-Object System.IO.StreamReader($fsErr)
    $fsOut = [System.IO.File]::Open($outFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $srOut = New-Object System.IO.StreamReader($fsOut)
    $script:lastPct        = -1
    $script:lastLineSig    = $null
    $script:hlsDurationSec = $null
    $phase = "Preparando…"
    function Set-Ui([string]$txt) {
        if ($UpdateUi -and $lblEstadoConsulta) { $lblEstadoConsulta.Text = $txt }
    }
    function _PrintLine([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return }
        $mDur = [regex]::Match($text, 'Duration:\s*(?<h>\d{2}):(?<m>\d{2}):(?<s>\d{2}(?:\.\d+)?)')
        if ($mDur.Success) {
            $h=[int]$mDur.Groups['h'].Value; $m=[int]$mDur.Groups['m'].Value; $s=[double]$mDur.Groups['s'].Value
            $script:hlsDurationSec = ($h*3600 + $m*60 + $s)
            return
        }
        if ($text -match "^\[(?:hls|https)\s@.*\]\s+Opening\s+'.+\.ts'") { return }
        if ($text -match '^\s*(Input\s+#0,|Output\s+#0|Press \[q\] to stop)') { return }
        if ($text -match 'Sleeping\s+(\d+(?:\.\d+)?)\s+seconds') { Set-Ui "Esperando $($Matches[1])s…"; Write-Host "`n$text"; return }
        if ($text -match '^\[download\]\s+Destination:')         { $phase = "Descargando…"; Set-Ui $phase; Write-Host "`n$text"; return }
        if ($text -match '^\[Merger\]\s+Merging formats')        { $phase = "Fusionando…"; Set-Ui $phase; Write-Host "`n$text"; return }
        if ($text -match '^Deleting original file')              { $phase = "Borrando temporales…"; Set-Ui $phase; Write-Host "`n$text"; return }
        if ($text -match '^\[(ExtractAudio|Fixup|EmbedSubtitle|ModifyChapters)\]') { $phase = "Post-procesando…"; Set-Ui $phase; Write-Host "`n$text"; return }
        $m = [regex]::Match($text, 'download:\s*(?<pct>\d+(?:\.\d+)?)%\s*(?:ETA:(?<eta>\S+))?\s*(?:SPEED:(?<spd>.+))?', 'IgnoreCase')
        if (-not $m.Success) { $m = [regex]::Match($text, '(?<pct>\d+(?:\.\d+)?)%\s+of.*?at\s+(?<spd>\S+)\s+ETA\s+(?<eta>\S+)', 'IgnoreCase') }
        if (-not $m.Success) { $m = [regex]::Match($text, '(?<pct>\d+(?:\.\d+)?)%') }
        if ($m.Success) {
            $pct = [int][math]::Min(100,[math]::Round([double]$m.Groups['pct'].Value))
            $eta = $m.Groups['eta'].Value; $spd = $m.Groups['spd'].Value
            if ($pct -ne $script:lastPct) {
                $script:lastPct = $pct
                Set-Ui ("{0} {1}%  ETA {2}  {3}" -f ($phase -replace '\.\.\.$','…'), $pct, ($eta ? $eta : "--:--"), ($spd ? $spd : ""))
                Write-Host ("`r[PROGRESO] {0,3}%  ETA {1,-8}  {2,-16}" -f $pct, $eta, $spd) -NoNewline
            }
            return
        }
        $mFfm = [regex]::Match($text, '^frame=\s*\d+.*time=\d{2}:\d{2}:\d{2}(?:\.\d+)?\s+.*speed=\S+')
        if ($mFfm.Success) {
            $line = ($text -replace '\s+',' ').Trim()
            $sig  = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($line)))
            if ($sig -ne $script:lastLineSig) {
                $script:lastLineSig = $sig
                Set-Ui $line
                Write-Host ("`r[PROGRESO] {0}" -f $line) -NoNewline
            }
            return
        }
        Write-Host "`n$text"
    }
    try {
        Set-Ui "Preparando descarga…"
        $bufErr = ""; $bufOut = ""
        while (-not $proc.HasExited) {
            $bufOut += $srOut.ReadToEnd()
            $bufErr += $srErr.ReadToEnd()
            foreach ($chunk in @($bufOut, $bufErr)) {
                if ([string]::IsNullOrEmpty($chunk)) { continue }
                $parts = [regex]::Split($chunk, "\r\n|\n|\r")
                for ($i=0; $i -lt $parts.Length-1; $i++) { _PrintLine $parts[$i] }
            }
            if ($bufOut) { $bufOut = ([regex]::Split($bufOut, "\r\n|\n|\r") | Select-Object -Last 1) } 
            if ($bufErr) { $bufErr = ([regex]::Split($bufErr, "\r\n|\n|\r") | Select-Object -Last 1) }

            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 80
        }
        $bufOut += $srOut.ReadToEnd()
        $bufErr += $srErr.ReadToEnd()
        foreach ($line in ([regex]::Split(($bufOut + "`n" + $bufErr), "\r\n|\n|\r"))) { _PrintLine $line }
    }
    finally {
        try { $srErr.Close(); $fsErr.Close() } catch {}
        try { $srOut.Close(); $fsOut.Close() } catch {}
        Write-Host ""
    }
    return $proc.ExitCode
}
$btnConsultar.Add_Click({
    $btnConsultar.Enabled = $false
    try {
        Refresh-GateByDeps
        if (-not $btnConsultar.Enabled) { return }
        $url = Get-CurrentUrl
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
        $res = Invoke-CaptureResponsive -ExePath $yt.Source `
                -Args @("--no-playlist","--get-title",$url) `
                -WorkingText "Consultando URL…"
        $titulo = ($res.StdOut + "`n" + $res.StdErr).Trim() -split "`r?`n" |
                  Where-Object { $_.Trim() -ne "" } | Select-Object -First 1
        if ($res.ExitCode -ne 0 -or -not $titulo) {
            $script:videoConsultado = $false; $script:ultimaURL = $null; $script:ultimoTitulo = $null
            $lblEstadoConsulta.Text = "Error al consultar la URL"; $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::Red
            Set-DownloadButtonVisual
            $picPreview.Image = $null
            Write-Host "[ERROR] No se pudo consultar el video. STDOUT/ERR:" -ForegroundColor Red
            Write-Host $res.StdOut
            Write-Host $res.StdErr
            [System.Windows.Forms.MessageBox]::Show("No se pudo consultar el video. Revisa la URL o tu conexión.","Consulta fallida",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }
        $script:videoConsultado = $true; $script:ultimaURL = $url; $script:ultimoTitulo = $titulo
        $lblEstadoConsulta.Text = ("Consultado: {0}" -f $titulo); $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::ForestGreen
        Set-DownloadButtonVisual
        Write-Host ("`t[OK] Video consultado: {0}" -f $titulo) -ForegroundColor Green
        $cmbVideoFmt.Items.Clear()
        $cmbAudioFmt.Items.Clear()
        $prevLabelText = $lblEstadoConsulta.Text
        $meta = Get-Metadata -Url $url
        $script:lastExtractor = $meta?.Extractor
        $script:lastDomain    = $meta?.Domain
        if ($meta -and $meta.Thumbnail) { $script:lastThumbUrl = $meta.Thumbnail }
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
                    $script:formatsEnumerated = $false
                    $cmbVideoFmt.Items.Clear()
                    $cmbAudioFmt.Items.Clear()
                    Write-Host "[WARN] No fue posible extraer formatos. Vuelve a consultar." -ForegroundColor Yellow
                    $lblEstadoConsulta.Text = "No fue posible extraer formatos. Vuelve a consultar."
                    $lblEstadoConsulta.ForeColor = [System.Drawing.Color]::DarkOrange
                    Set-DownloadButtonVisual
                    return
                    if ($script:lastFormats) {
                    Print-FormatsTable -formats $script:lastFormats
                    }
                Add-HistoryUrl -Url $url
                }
        } finally {
            $lblEstadoConsulta.Text = $prevLabelText
        }
    } finally {
        $btnConsultar.Enabled = $true
    }
})
        function Is-ProgressiveOnlySite([string]$extractor) {
            return ($extractor -match '(tiktok|douyin|instagram|twitter|x)')
        }
$btnDescargar.Add_Click({
        if ($script:videoConsultado -and -not $script:formatsEnumerated) {
        $ok = Invoke-ConsultaFromUI -Url (Get-CurrentUrl)
        Set-DownloadButtonVisual
        if ($ok -and $script:formatsEnumerated) {
            [System.Windows.Forms.MessageBox]::Show(
                "Consulta lista. Vuelve a presionar 'Descargar' para iniciar la descarga.",
                "Consulta completada",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No fue posible extraer formatos. Verifica conexión/URL y vuelve a intentar.",
                "Falta de formatos",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
        return
    }
    Refresh-GateByDeps
    $currentUrl = Get-CurrentUrl
    $ready = $script:videoConsultado -and
             -not [string]::IsNullOrWhiteSpace($script:ultimaURL) -and
             ($script:ultimaURL -eq $currentUrl)
    if (-not $ready) {
        if ([string]::IsNullOrWhiteSpace($currentUrl)) {
            [System.Windows.Forms.MessageBox]::Show("Escribe una URL de YouTube.","Falta URL",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $ok = Invoke-ConsultaFromUI -Url $currentUrl
        Set-DownloadButtonVisual
        if ($ok) {
            [System.Windows.Forms.MessageBox]::Show("Consulta lista. Vuelve a presionar Descargar para iniciar la descarga.",
                "Consulta completada",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
        return
    }
    try { $yt = Get-Command yt-dlp -ErrorAction Stop } catch {
        [System.Windows.Forms.MessageBox]::Show("yt-dlp no está disponible. Valídalo en Dependencias.","yt-dlp no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }
    $dest = $script:ultimaRutaDescarga
    if ([string]::IsNullOrWhiteSpace($dest)) {
        $dest = [Environment]::GetFolderPath('Desktop')
        $script:ultimaRutaDescarga = $dest
        try { $txtDestino.Text = $dest } catch {}
    }
    if (-not (Test-Path -LiteralPath $dest)) {
        try { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        catch {
            [System.Windows.Forms.MessageBox]::Show("No se pudo preparar la carpeta de destino.","Error de destino",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }
    }
        function Is-TwitchUrl([string]$u) {
            return $u -match '(^https?://)?([a-z]+\.)?twitch\.tv/'
        }
        $videoSel = Get-SelectedFormatId -Combo $cmbVideoFmt
        $audioSel = Get-SelectedFormatId -Combo $cmbAudioFmt
        $fSelector = $null
        $mergeExt  = "mp4"
        if (Is-TwitchUrl $script:ultimaURL) {
            if ($videoSel -and $videoSel -notmatch '^best(video)?$') {
                $fSelector = $videoSel
            } else {
                $fSelector = "best"
            }
        }
        elseif (Is-ProgressiveOnlySite $script:lastExtractor) {
            if ($videoSel -match '^best(video)?$') {
                $fSelector = ($script:bestProgId ? $script:bestProgId : "best")
            } else {
                $fSelector = $videoSel
            }
            $mergeExt = $null
            try { $cmbAudioFmt.Enabled = $false } catch {}
        }
        else {
            if ($videoSel) {
                if ($videoSel -eq "best") {
                    $fSelector = "best"
                } elseif ($videoSel -eq "bestvideo") {
                    $fSelector = "bestvideo+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
                } else {
                    $klass = $script:formatsIndex[$videoSel]
                    if ($klass -and $klass.Progressive) {
                        $fSelector = $videoSel
                    } elseif ($klass -and $klass.VideoOnly) {
                        $fSelector = $videoSel + "+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
                    } else {
                        $fSelector = $videoSel + "+" + ($(if ($audioSel) { $audioSel } else { "bestaudio" }))
                    }
                }
            } else {
                $fSelector = "best"
            }
        }

    $prevLbl = $lblEstadoConsulta.Text
    $prevPickDest  = $btnPickDestino.Enabled
    $prevCmbVid    = $cmbVideoFmt.Enabled
    $prevCmbAud    = $cmbAudioFmt.Enabled
    $btnPickDestino.Enabled = $false
    $cmbVideoFmt.Enabled = $false
    $cmbAudioFmt.Enabled = $false
    $lblEstadoConsulta.Text = "Preparando descarga…"
    $baseTitle = if ($script:ultimoTitulo) { $script:ultimoTitulo } else {
        $vid = Get-YouTubeVideoId -Url $script:ultimaURL
        if ($vid) { "video_$vid" } else { "video" }
    }
    $baseTitle = Get-SafeFileName -Name $baseTitle
    $finalExt = $mergeExt
    if ([string]::IsNullOrWhiteSpace($finalExt)) { $finalExt = "mp4" }
    $targetPath = Join-Path $dest ("{0}.{1}" -f $baseTitle, $finalExt)
    $idx = 2
    while (Test-Path -LiteralPath $targetPath) {
        $targetPath = Join-Path $dest ("{0}_{1}.{2}" -f $baseTitle, $idx, $finalExt)
        $idx++
    }
    Write-Host ("[OUTPUT] Archivo destino: {0}" -f $targetPath) -ForegroundColor Cyan
        $args = @("--encoding","utf-8","--progress","--no-color","--newline",
                  "-f", $fSelector,
                  "-o", $targetPath,
                  "--progress-template","download:%(progress._percent_str)s ETA:%(progress._eta_str)s SPEED:%(progress._speed_str)s",
                  "--extractor-args","youtube:player_client=default,-web_safari,-web_embedded,-tv")
        
        if ($mergeExt) {
            $args = @("--encoding","utf-8","--progress","--no-color","--newline",
                      "-f", $fSelector,
                      "--merge-output-format", $mergeExt,
                      "-o", $targetPath,
                      "--progress-template","download:%(progress._percent_str)s ETA:%(progress._eta_str)s SPEED:%(progress._speed_str)s",
                      "--extractor-args","youtube:player_client=default,-web_safari,-web_embedded,-tv")
        }
        $args += @(
            "--no-part",               # Evita .part corruptos
            "--ignore-config"          # Ignora errores de configuración externa
        )
    if ($script:cookiesPath) {
            $args += @("--cookies", $script:cookiesPath)
        }
    $args += $script:ultimaURL
    if (Is-TwitchUrl $script:ultimaURL) {
            $args += @(
                "--hls-use-mpegts",
                "--retries","10","--retry-sleep","1",
                "-N","4"
            )
            $args += (Get-DownloadExtras -Extractor $script:lastExtractor -Domain $script:lastDomain)
    }
    $oldCursor = [System.Windows.Forms.Cursor]::Current
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        $exit = Invoke-YtDlpConsoleProgress -ExePath $yt.Source -Args $args -UpdateUi
        if ($exit -ne 0) {
            $lastErr = $lblEstadoConsulta.Text + " "  # opcional, no siempre contiene stderr
            if (Is-ProgressiveOnlySite $script:lastExtractor -and $videoSel -match '^best(video)?$' -and $script:bestProgId) {
                Write-Host "[RETRY] Alias falló; reintento con ID concreto: $($script:bestProgId)" -ForegroundColor Yellow
                $args = @("--encoding","utf-8","--progress","--no-color","--newline",
                          "-f", $script:bestProgId,
                          "-o", $targetPath,
                          "--progress-template","download:%(progress._percent_str)s ETA:%(progress._eta_str)s SPEED:%(progress._speed_str)s",
                          "--extractor-args","youtube:player_client=default,-web_safari,-web_embedded,-tv")
                $exit = Invoke-YtDlpConsoleProgress -ExePath $yt.Source -Args $args -UpdateUi
            }
        }
        if ($exit -eq 0) {
            Add-HistoryUrl -Url $script:ultimaURL
            $lblEstadoConsulta.Text = ("Completado: {0}" -f $script:ultimoTitulo)
            [System.Windows.Forms.MessageBox]::Show(("Descarga finalizada:`n{0}" -f $script:ultimoTitulo),
                "Completado",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        } else {
            $lblEstadoConsulta.Text = "Error durante la descarga"
            [System.Windows.Forms.MessageBox]::Show("Falló la descarga. Revisa conexión/URL/DRM.","Error de descarga",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    } finally {
        [System.Windows.Forms.Cursor]::Current = $oldCursor
        $btnPickDestino.Enabled = $prevPickDest
        $cmbVideoFmt.Enabled    = $prevCmbVid
        $cmbAudioFmt.Enabled    = $prevCmbAud
        Set-DownloadButtonVisual
    }
})
Refresh-DependencyLabel -CommandName "yt-dlp" -FriendlyName "yt-dlp" -LabelRef ([ref]$lblYtDlp) -VersionArgs "--version" -Parse "FirstLine"
Refresh-DependencyLabel -CommandName "ffmpeg" -FriendlyName "ffmpeg" -LabelRef ([ref]$lblFfmpeg) -VersionArgs "-version" -Parse "FirstLine"
if ($script:RequireNode) {
    Refresh-DependencyLabel -CommandName "node" -FriendlyName "Node.js" -LabelRef ([ref]$lblNode) -VersionArgs "--version" -Parse "FirstLine"
}
Refresh-GateByDeps
Set-DownloadButtonVisual
try { $txtDestino.Text = $script:ultimaRutaDescarga } catch {}
$btnExit.Add_Click({
    Write-Host "[EXIT] Cerrando aplicación por solicitud del usuario." -ForegroundColor Yellow
    $formPrincipal.Dispose()
    $formPrincipal.Close()
})
$formPrincipal.Refresh()
$formPrincipal.ShowDialog()
