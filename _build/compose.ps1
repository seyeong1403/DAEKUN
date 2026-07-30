<#
  DAEKUN MS — 서브 페이지 생성기
  - 헤더/푸터 원본 : index.html 의 <!-- #HEADER# --> ~ <!-- #/HEADER# -->, <!-- #FOOTER# --> ~ <!-- #/FOOTER# -->
  - 본문 조각      : _build/pages/*.html  (맨 위 메타 주석 + 본문)
  - 결과           : 메타의 @out 경로에 완성된 HTML 작성

  ※ 서브 페이지 본문을 수정할 때는 반드시 _build/pages/ 의 조각을 고치고 이 스크립트를 다시 실행할 것.
     루트에 생성된 HTML을 직접 고치면 다음 실행 때 덮어써진다.
     GNB·푸터를 바꿀 때는 index.html 만 고치고 이 스크립트를 실행하면 전 페이지에 반영된다.
#>
param(
	[string]$Root = 'C:\Users\PC\Desktop\daekunms'
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$nl = "`n"

function Read-Text($path) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }

# ---------- 1. index.html 에서 공통 크롬 추출 ----------
$indexPath = Join-Path $Root 'index.html'
$index = Read-Text $indexPath

function Get-Block($text, $openMark, $closeMark) {
	$s = $text.IndexOf($openMark)
	$e = $text.IndexOf($closeMark)
	if ($s -lt 0 -or $e -lt 0) { throw "마커를 찾을 수 없음: $openMark" }
	return $text.Substring($s, $e - $s + $closeMark.Length)
}
$header = Get-Block $index '<!-- #HEADER#' '<!-- #/HEADER# -->'
$footer = Get-Block $index '<!-- #FOOTER#' '<!-- #/FOOTER# -->'

# ---------- 2. 한 단계 아래 폴더용으로 경로에 ../ 붙이기 ----------
function Add-UpPath($block) {
	return [regex]::Replace($block, '(href|src)="(?!#|https?:|mailto:|tel:|//|\.\./|/)([^"]*)"', '$1="../$2"')
}
$headerSub = Add-UpPath $header
$footerSub = Add-UpPath $footer

# ---------- 3. 조각 순회 ----------
$pagesDir = Join-Path $Root '_build\pages'
$fragments = Get-ChildItem $pagesDir -Filter '*.html' | Sort-Object Name
$made = 0

foreach ($f in $fragments) {
	$raw = Read-Text $f.FullName
	$meta = @{}
	$lines = $raw -split "`r?`n"
	$bodyStart = 0
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$m = [regex]::Match($lines[$i], '^\s*<!--@(\w+)\s+(.*?)-->\s*$')
		if ($m.Success) { $meta[$m.Groups[1].Value] = $m.Groups[2].Value.Trim(); $bodyStart = $i + 1 }
		elseif ($lines[$i].Trim() -ne '') { break }
	}
	foreach ($k in @('title', 'desc', 'menu', 'out')) {
		if (-not $meta.ContainsKey($k)) { throw "$($f.Name) : @$k 메타가 없음" }
	}
	$body = ($lines[$bodyStart..($lines.Count - 1)] -join $nl).Trim()

	$titleFull = "$($meta.title) | 대건엠에스 DAEKUN MS"
	$page = @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<title>$titleFull</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="format-detection" content="telephone=no">
<meta name="description" content="$($meta.desc)">
<meta property="og:type" content="website">
<meta property="og:title" content="$titleFull">
<meta property="og:description" content="$($meta.desc)">
<meta property="og:image" content="https://daekunms.co.kr/images/common/logo_navy.png">
<meta property="og:url" content="https://daekunms.co.kr/$($meta.out)">
<meta name="theme-color" content="#131C3B">
<link rel="canonical" href="https://daekunms.co.kr/$($meta.out)">
<link rel="stylesheet" href="../css/base.css">
<link rel="stylesheet" href="../css/layout.css">
<link rel="stylesheet" href="../css/common.css">
<link rel="stylesheet" href="../css/main.css">
<link rel="stylesheet" href="../css/sub.css">
<link rel="stylesheet" href="../css/responsive.css">
<script>document.documentElement.classList.add('js-scroll');</script>
</head>
<body data-menu="$($meta.menu)">
<div class="skip-nav"><a href="#content">본문 바로가기</a></div>

<div id="wrap" class="sub-wrap">

$headerSub

$body

$footerSub

	<button type="button" class="go-top-btn" aria-label="맨 위로 이동"></button>
</div>

<script src="../js/main.js"></script>
<script src="../js/sub.js"></script>
</body>
</html>
"@
	$page = $page -replace "`r`n", $nl
	$dest = Join-Path $Root ($meta.out -replace '/', '\')
	$destDir = Split-Path $dest -Parent
	if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
	[System.IO.File]::WriteAllText($dest, $page, $utf8)
	$made++
	Write-Output ("OK  {0,-34} <- {1}" -f $meta.out, $f.Name)
}
Write-Output "=== $made pages composed ==="
