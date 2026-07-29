<#
  DAEKUN MS — 글로벌 생산 네트워크 지도 생성
  ------------------------------------------------------------------
  OpenStreetMap 타일을 이어붙인 뒤 다크 네이비 듀오톤으로 가공하고,
  한국 본사(R&D)에서 각 생산 거점으로 연결선과 마커를 그린다.

  Map data © OpenStreetMap contributors, ODbL 1.0 — https://osm.org/copyright

  ※ 초안용 정적 이미지다. 정식 오픈 시에는 거점 클릭 인터랙션이 되는
     SVG/지도 라이브러리 기반 그래픽으로 교체하는 것이 맞다.
#>
param(
	[string]$Root = 'C:\Users\PC\Desktop\daekunms',
	[double]$CenterLat = 17.0,
	[double]$CenterLon = 108.5,
	[int]$Zoom = 5,
	[int]$OutW = 2000,
	[int]$OutH = 1400
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dest = Join-Path $Root 'images\content'
$tmp = Join-Path $env:TEMP ('osmworld_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$UA = 'DaekunmsDraftSite/1.0 (static map for internal draft; contact rurumaru@naver.com)'

function Get-PixXY([double]$lat, [double]$lon, [int]$z) {
	$n = [math]::Pow(2, $z)
	$r = $lat * [math]::PI / 180.0
	$x = ($lon + 180.0) / 360.0 * $n * 256.0
	$y = (1.0 - [math]::Log([math]::Tan($r) + (1.0 / [math]::Cos($r))) / [math]::PI) / 2.0 * $n * 256.0
	return @($x, $y)
}

$c = Get-PixXY $CenterLat $CenterLon $Zoom
$left = [int][math]::Floor($c[0] - $OutW / 2.0)
$top = [int][math]::Floor($c[1] - $OutH / 2.0)
$tx0 = [int][math]::Floor($left / 256.0); $tx1 = [int][math]::Floor(($left + $OutW - 1) / 256.0)
$ty0 = [int][math]::Floor($top / 256.0);  $ty1 = [int][math]::Floor(($top + $OutH - 1) / 256.0)

# 1) 타일 합성
$raw = New-Object System.Drawing.Bitmap($OutW, $OutH)
$g = [System.Drawing.Graphics]::FromImage($raw)
$g.Clear([System.Drawing.Color]::FromArgb(170, 200, 225))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$got = 0; $miss = 0
for ($ty = $ty0; $ty -le $ty1; $ty++) {
	for ($tx = $tx0; $tx -le $tx1; $tx++) {
		$n = [int][math]::Pow(2, $Zoom)
		$wx = (($tx % $n) + $n) % $n
		if ($ty -lt 0 -or $ty -ge $n) { continue }
		$f = Join-Path $tmp "t_${wx}_${ty}.png"
		# OSM 타일 서버가 연속 요청을 간헐적으로 거절하므로 재시도한다
		for ($try = 1; $try -le 4; $try++) {
			if ((Test-Path $f) -and (Get-Item $f).Length -gt 60) { break }
			curl.exe -s -L --max-time 25 -A $UA -o $f "https://tile.openstreetmap.org/$Zoom/$wx/$ty.png"
			if (-not ((Test-Path $f) -and (Get-Item $f).Length -gt 60)) { Start-Sleep -Milliseconds (250 * $try) }
		}
		if ((Test-Path $f) -and (Get-Item $f).Length -gt 60) {
			try { $img = [System.Drawing.Image]::FromFile($f); $g.DrawImage($img, ($tx * 256 - $left), ($ty * 256 - $top), 256, 256); $img.Dispose(); $got++ }
			catch { $miss++ }
		} else { $miss++ }
	}
}
$g.Dispose()

# 2) 흑백화 → 네이비 듀오톤
$bmp = New-Object System.Drawing.Bitmap($OutW, $OutH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$cm = New-Object System.Drawing.Imaging.ColorMatrix
$cm.Matrix00 = 0.299; $cm.Matrix01 = 0.299; $cm.Matrix02 = 0.299
$cm.Matrix10 = 0.587; $cm.Matrix11 = 0.587; $cm.Matrix12 = 0.587
$cm.Matrix20 = 0.114; $cm.Matrix21 = 0.114; $cm.Matrix22 = 0.114
$cm.Matrix33 = 1.0; $cm.Matrix44 = 1.0
$ia = New-Object System.Drawing.Imaging.ImageAttributes
$ia.SetColorMatrix($cm)
$rect = New-Object System.Drawing.Rectangle(0, 0, $OutW, $OutH)
$g.DrawImage($raw, $rect, 0, 0, $OutW, $OutH, [System.Drawing.GraphicsUnit]::Pixel, $ia)
$raw.Dispose()
# 네이비 틴트
$brTint = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(188, 16, 24, 52))
$g.FillRectangle($brTint, $rect)
# 스틸블루 미세 발광
$brGlow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 62, 110, 175))
$g.FillRectangle($brGlow, $rect)

# 3) 거점
$sites = @(
	@{ n = '대한민국 서울'; s = '본사 · R&D'; lat = 37.5665; lon = 126.9780; hq = $true },
	@{ n = '베트남 하노이'; s = '4개 공장'; lat = 21.0278; lon = 105.8342; hq = $false },
	@{ n = '중국 상하이'; s = 'R&D · 특수생산'; lat = 31.2304; lon = 121.4737; hq = $false },
	@{ n = '중국 광저우'; s = 'R&D · 특수생산'; lat = 23.1291; lon = 113.2644; hq = $false },
	@{ n = '방글라데시 다카'; s = '1개 공장'; lat = 23.8103; lon = 90.4125; hq = $false },
	@{ n = '인도네시아 자카르타'; s = '1개 공장'; lat = -6.2088; lon = 106.8456; hq = $false }
)
foreach ($s in $sites) {
	$p = Get-PixXY $s.lat $s.lon $Zoom
	$s.x = [int]($p[0] - $left); $s.y = [int]($p[1] - $top)
}
$hq = $sites | Where-Object { $_.hq } | Select-Object -First 1

# 연결선 (본사 → 각 거점)
$penLine = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(165, 92, 143, 208), 3)
$penLine.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
foreach ($s in $sites) {
	if ($s.hq) { continue }
	$g.DrawLine($penLine, $hq.x, $hq.y, $s.x, $s.y)
}

# 마커 + 라벨
$fontN = New-Object System.Drawing.Font('Malgun Gothic', 16, [System.Drawing.FontStyle]::Bold)
$fontS = New-Object System.Drawing.Font('Malgun Gothic', 12)
$brWhite = [System.Drawing.Brushes]::White
$brSub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(196, 214, 240))
foreach ($s in $sites) {
	$col = if ($s.hq) { [System.Drawing.Color]::FromArgb(255, 255, 255) } else { [System.Drawing.Color]::FromArgb(92, 143, 208) }
	$rad = if ($s.hq) { 16 } else { 11 }
	$brHalo = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, $col.R, $col.G, $col.B))
	$g.FillEllipse($brHalo, ($s.x - $rad * 2.6), ($s.y - $rad * 2.6), $rad * 5.2, $rad * 5.2)
	$brDot = New-Object System.Drawing.SolidBrush($col)
	$g.FillEllipse($brDot, ($s.x - $rad), ($s.y - $rad), $rad * 2, $rad * 2)
	if ($s.hq) {
		$penRing = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 92, 143, 208), 3)
		$g.DrawEllipse($penRing, ($s.x - $rad - 7), ($s.y - $rad - 7), ($rad + 7) * 2, ($rad + 7) * 2)
	}
	# 라벨 위치 : 화면 밖으로 나가지 않도록 좌우 반전
	$tw = [math]::Max($g.MeasureString($s.n, $fontN).Width, $g.MeasureString($s.s, $fontS).Width)
	$lx = $s.x + $rad + 12
	if ($lx + $tw + 10 -gt $OutW) { $lx = $s.x - $rad - 12 - $tw }
	$ly = $s.y - 25
	$g.DrawString($s.n, $fontN, $brWhite, $lx, $ly)
	$g.DrawString($s.s, $fontS, $brSub, $lx, ($ly + 26))
}

# 저작권
$fontA = New-Object System.Drawing.Font('Segoe UI', 13)
$attr = '  Map data © OpenStreetMap contributors  '
$asz = $g.MeasureString($attr, $fontA)
$ax = $OutW - [int]$asz.Width - 8; $ay = $OutH - [int]$asz.Height - 8
$g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 8, 13, 28))), $ax, $ay, [int]$asz.Width, [int]$asz.Height)
$g.DrawString($attr, $fontA, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190, 205, 225))), $ax, $ay)

$g.Dispose()
$outFile = Join-Path $dest 'map_network.jpg'
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$prm = New-Object System.Drawing.Imaging.EncoderParameters(1)
$prm.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 88L)
$bmp.Save($outFile, $enc, $prm)
$bmp.Dispose()
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Output ("타일 {0}개 / 실패 {1}" -f $got, $miss)
Write-Output ("생성 : images/content/map_network.jpg  {0}x{1}  {2} KB" -f $OutW, $OutH, [math]::Round((Get-Item $outFile).Length / 1KB, 1))
