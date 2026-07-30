<#
  DAEKUN MS — 찾아오시는 길 지도 이미지 생성
  ------------------------------------------------------------------
  본사 주소(서울 성동구 상원12길 34)를 중심으로 OpenStreetMap 타일을 이어붙여
  정적 지도 이미지를 만든다. 지도 데이터 저작권 표기를 이미지 안에 함께 넣는다.

  Map data © OpenStreetMap contributors, ODbL 1.0 — https://osm.org/copyright

  ※ 초안용 정적 이미지다. 정식 오픈 시에는 카카오맵/네이버지도 API 임베드로
     교체해 길찾기·확대축소가 되도록 하는 것이 맞다.
#>
param(
	[string]$Root = 'C:\Users\PC\Desktop\daekunms',
	[double]$Lat = 37.5495302,
	[double]$Lon = 127.0504935,
	[int]$Zoom = 17,
	[int]$OutW = 1600,
	[int]$OutH = 700
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dest = Join-Path $Root 'images\content'
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
$tmp = Join-Path $env:TEMP ('osmtile_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$UA = 'DaekunmsDraftSite/1.0 (static map for internal draft; contact rurumaru@naver.com)'

# 위경도 → 전역 픽셀 좌표 (웹 메르카토르)
$n = [math]::Pow(2, $Zoom)
$latRad = $Lat * [math]::PI / 180.0
$fx = ($Lon + 180.0) / 360.0 * $n
$fy = (1.0 - [math]::Log([math]::Tan($latRad) + (1.0 / [math]::Cos($latRad))) / [math]::PI) / 2.0 * $n
$cx = $fx * 256.0
$cy = $fy * 256.0
$left = [int][math]::Floor($cx - $OutW / 2.0)
$top = [int][math]::Floor($cy - $OutH / 2.0)
$tx0 = [int][math]::Floor($left / 256.0)
$ty0 = [int][math]::Floor($top / 256.0)
$tx1 = [int][math]::Floor(($left + $OutW - 1) / 256.0)
$ty1 = [int][math]::Floor(($top + $OutH - 1) / 256.0)

$bmp = New-Object System.Drawing.Bitmap($OutW, $OutH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(233, 237, 242))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$got = 0; $miss = 0
for ($ty = $ty0; $ty -le $ty1; $ty++) {
	for ($tx = $tx0; $tx -le $tx1; $tx++) {
		$url = "https://tile.openstreetmap.org/$Zoom/$tx/$ty.png"
		$f = Join-Path $tmp "t_${tx}_${ty}.png"
		curl.exe -s -L --max-time 20 -A $UA -o $f $url
		if ((Test-Path $f) -and (Get-Item $f).Length -gt 60) {
			try {
				$img = [System.Drawing.Image]::FromFile($f)
				$g.DrawImage($img, ($tx * 256 - $left), ($ty * 256 - $top), 256, 256)
				$img.Dispose(); $got++
			} catch { $miss++ }
		} else { $miss++ }
	}
}

# 마커 — 브랜드 네이비 핀
$navy = [System.Drawing.Color]::FromArgb(19, 28, 59)
$steel = [System.Drawing.Color]::FromArgb(62, 110, 175)
$mx = [int]($OutW / 2); $my = [int]($OutH / 2)
$brNavy = New-Object System.Drawing.SolidBrush($navy)
$brWhite = [System.Drawing.Brushes]::White
$penWhite = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)
# 후광
$brHalo = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(46, 62, 110, 175))
$g.FillEllipse($brHalo, ($mx - 44), ($my - 44), 88, 88)
# 핀 꼬리
$tail = @(
	(New-Object System.Drawing.Point(($mx - 11), ($my + 8))),
	(New-Object System.Drawing.Point(($mx + 11), ($my + 8))),
	(New-Object System.Drawing.Point($mx, ($my + 30)))
)
$g.FillPolygon($brNavy, $tail)
# 핀 머리
$g.FillEllipse($brNavy, ($mx - 20), ($my - 20), 40, 40)
$g.DrawEllipse($penWhite, ($mx - 20), ($my - 20), 40, 40)
$g.FillEllipse($brWhite, ($mx - 7), ($my - 7), 14, 14)

# 라벨
$fontLabel = New-Object System.Drawing.Font('Malgun Gothic', 13, [System.Drawing.FontStyle]::Bold)
$label = '대건엠에스 본사 · R&D 센터'
$sz = $g.MeasureString($label, $fontLabel)
$lw = [int]$sz.Width + 28; $lh = [int]$sz.Height + 14
$lx = $mx - [int]($lw / 2); $ly = $my - 34 - $lh
$brLabelBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 19, 28, 59))
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$rad = 10
$path.AddArc($lx, $ly, $rad * 2, $rad * 2, 180, 90)
$path.AddArc(($lx + $lw - $rad * 2), $ly, $rad * 2, $rad * 2, 270, 90)
$path.AddArc(($lx + $lw - $rad * 2), ($ly + $lh - $rad * 2), $rad * 2, $rad * 2, 0, 90)
$path.AddArc($lx, ($ly + $lh - $rad * 2), $rad * 2, $rad * 2, 90, 90)
$path.CloseFigure()
$g.FillPath($brLabelBg, $path)
$g.DrawString($label, $fontLabel, $brWhite, ($lx + 14), ($ly + 6))

# 저작권 표기 (ODbL 준수)
$fontAttr = New-Object System.Drawing.Font('Segoe UI', 10)
$attr = '  Map data © OpenStreetMap contributors  '
$asz = $g.MeasureString($attr, $fontAttr)
$ax = $OutW - [int]$asz.Width - 8; $ay = $OutH - [int]$asz.Height - 8
$brAttrBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 255, 255))
$g.FillRectangle($brAttrBg, $ax, $ay, [int]$asz.Width, [int]$asz.Height)
$g.DrawString($attr, $fontAttr, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 78, 96))), $ax, $ay)

$g.Dispose()
$outFile = Join-Path $dest 'map_location.jpg'
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$prm = New-Object System.Drawing.Imaging.EncoderParameters(1)
$prm.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 88L)
$bmp.Save($outFile, $enc, $prm)
$bmp.Dispose()
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Output ("타일 {0}개 수신 / 실패 {1}" -f $got, $miss)
Write-Output ("생성 : images/content/map_location.jpg  {0}x{1}  {2} KB" -f $OutW, $OutH, [math]::Round((Get-Item $outFile).Length / 1KB, 1))
