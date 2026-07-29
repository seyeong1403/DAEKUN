<#
  DAEKUN MS - 공지사항 / 자료실 정적 페이지 생성기
  ---------------------------------------------------------------
  입력 : _admin/data/posts.json   (관리자에서 저장)
  출력 : news/notice.html, news/archive.html, news/view-<id>.html
  헤더/푸터는 compose.ps1 과 같이 index.html 에서 가져온다.
#>
param(
	[string]$Root = 'C:\Users\PC\Desktop\daekunms'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
$utf8 = New-Object System.Text.UTF8Encoding($false)
$nl = "`n"

function Read-Text($path) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }

# ---------- 공통 크롬 ----------
$index = Read-Text (Join-Path $Root 'index.html')
function Get-Block($text, $openMark, $closeMark) {
	$s = $text.IndexOf($openMark); $e = $text.IndexOf($closeMark)
	if ($s -lt 0 -or $e -lt 0) { throw "마커를 찾을 수 없음: $openMark" }
	return $text.Substring($s, $e - $s + $closeMark.Length)
}
function Add-UpPath($block) {
	return [regex]::Replace($block, '(href|src)="(?!#|https?:|mailto:|tel:|//|\.\./|/)([^"]*)"', '$1="../$2"')
}
$header = Add-UpPath (Get-Block $index '<!-- #HEADER#' '<!-- #/HEADER# -->')
$footer = Add-UpPath (Get-Block $index '<!-- #FOOTER#' '<!-- #/FOOTER# -->')

# ---------- 글 데이터 ----------
$postFile = Join-Path $Root '_admin\data\posts.json'
$posts = @()
if (Test-Path -LiteralPath $postFile) {
	$raw = (Read-Text $postFile).Trim()
	# ConvertFrom-Json 결과를 바로 @() 로 감싸면 배열 전체가 원소 1개가 된다. 반드시 먼저 변수에 담을 것.
	if ($raw) { $parsed = ConvertFrom-Json $raw; $posts = @($parsed) }
}
$posts = @($posts | Where-Object { $_ -and $_.published -ne $false })

$BOARDS = @(
	[ordered]@{ key = 'notice'; name = '공지사항'; en = 'Notice'; file = 'notice.html'; desc = '대건엠에스의 소식과 안내 사항을 전해드립니다.' },
	[ordered]@{ key = 'archive'; name = '자료실'; en = 'Archive'; file = 'archive.html'; desc = '회사 소개서와 제품 자료를 내려받으실 수 있습니다.' }
)

# ---------- 본문 변환 ----------
function Convert-Body($text) {
	if (-not $text) { return '<p>내용이 없습니다.</p>' }
	$t = [System.Web.HttpUtility]::HtmlEncode([string]$text) -replace "`r`n", "`n"
	$t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<strong>$1</strong>')
	$t = [regex]::Replace($t, '(https?://[^\s]+)', '<a href="$1" target="_blank" rel="noopener">$1</a>')
	$blocks = [regex]::Split($t, '\n[ \t]*\n')
	$out = foreach ($b in $blocks) {
		$b = $b.Trim()
		if ($b) { '<p>' + ($b -replace '\n', '<br>') + '</p>' }
	}
	return ($out -join $nl)
}
function Get-Summary($text) {
	if (-not $text) { return '' }
	$s = ((([string]$text -replace '\*\*', '') -replace '\s+', ' ')).Trim()
	if ($s.Length -gt 90) { $s = $s.Substring(0, 90) + '…' }
	return [System.Web.HttpUtility]::HtmlEncode($s)
}
function Format-Date($d) {
	if (-not $d) { return '' }
	return ([string]$d -replace '-', '.')
}
function Format-Size($n) {
	if (-not $n) { return '' }
	if ($n -ge 1MB) { return ('{0:N1}MB' -f ($n / 1MB)) }
	return ('{0:N0}KB' -f [math]::Max(1, $n / 1KB))
}
function Enc($s) { return [System.Web.HttpUtility]::HtmlEncode([string]$s) }

# ---------- 페이지 셸 ----------
function New-Page($title, $desc, $lnbOn, $bodyHtml, $visualText) {
	if (-not $visualText) { $visualText = $desc }
	$titleFull = "$title | 대건엠에스 DAEKUN MS"
	$lnb = ($BOARDS | ForEach-Object {
			$on = if ($_.key -eq $lnbOn) { ' class="on"' } else { '' }
			"					<li$on><a href=`"../news/$($_.file)`">$($_.name)</a></li>"
		}) -join $nl
	$crumb = ($BOARDS | Where-Object { $_.key -eq $lnbOn }).name

	return @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<title>$titleFull</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="format-detection" content="telephone=no">
<meta name="description" content="$(Enc $desc)">
<meta property="og:type" content="website">
<meta property="og:title" content="$titleFull">
<meta property="og:description" content="$(Enc $desc)">
<meta property="og:image" content="https://daekunms.co.kr/images/common/logo_navy.png">
<meta name="theme-color" content="#131C3B">
<!-- 임시 검토용 배포 : 검색엔진 색인 차단. 정식 오픈 시 이 줄과 robots.txt 를 제거한다 -->
<meta name="robots" content="noindex, nofollow">
<link rel="stylesheet" href="../css/base.css">
<link rel="stylesheet" href="../css/layout.css">
<link rel="stylesheet" href="../css/common.css">
<link rel="stylesheet" href="../css/main.css">
<link rel="stylesheet" href="../css/sub.css">
<link rel="stylesheet" href="../css/board.css">
<link rel="stylesheet" href="../css/responsive.css">
<script>document.documentElement.classList.add('js-scroll');</script>
</head>
<body data-menu="news">
<div class="skip-nav"><a href="#content">본문 바로가기</a></div>

<div id="wrap" class="sub-wrap">

$header

	<!-- SUB VISUAL -->
	<section id="subVisual">
		<h2 class="blind">$(Enc $title)</h2>
		<!-- 이미지 슬롯 : SUB 비주얼 · 2560×1040 · 사무·문서 컷 · 딥네이비 오버레이 72% --><div class="sub-visual-img img-slot has-img"><img src="../images/content/sub_etc.jpg" alt="대건엠에스 소식" loading="lazy"></div>
		<div class="sub-visual-txt-con">
			<div class="area">
				<p class="sub-visual-tit font-en">NEWS <b>ROOM</b></p>
				<p class="sub-visual-txt">$(Enc $visualText)</p>
			</div>
		</div>
		<div class="sub-lnb">
			<div class="sub-lnb-inner">
				<ul class="lnb-list">
$lnb
				</ul>
				<ul class="breadcrumb">
					<li><a class="home font-en" href="../index.html">HOME</a></li>
					<li class="font-en">News</li>
					<li>$(Enc $crumb)</li>
				</ul>
			</div>
		</div>
	</section>

	<div id="content">
$bodyHtml
	</div>

$footer

	<button type="button" class="go-top-btn" aria-label="맨 위로 이동"></button>
</div>

<script src="../js/main.js"></script>
<script src="../js/sub.js"></script>
</body>
</html>
"@
}

function Save-Page($rel, $html) {
	$dest = Join-Path $Root ($rel -replace '/', '\')
	$dir = Split-Path $dest -Parent
	if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
	[System.IO.File]::WriteAllText($dest, ($html -replace "`r`n", $nl), $utf8)
}

# ---------- 오래된 상세 페이지 정리 ----------
$newsDir = Join-Path $Root 'news'
if (Test-Path -LiteralPath $newsDir) {
	Get-ChildItem $newsDir -Filter 'view-*.html' -ErrorAction SilentlyContinue | Remove-Item -Force
}

$made = 0

foreach ($b in $BOARDS) {
	$items = @($posts | Where-Object { $_.board -eq $b.key })
	$items = @($items | Sort-Object @{E = { if ($_.pinned) { 0 } else { 1 } } }, @{E = { [string]$_.date }; Descending = $true })

	# ---- 목록 ----
	if ($items.Count -eq 0) {
		$listHtml = '					<div class="board-empty"><p>등록된 글이 없습니다.</p></div>'
	} else {
		$rows = foreach ($p in $items) {
			$badge = if ($p.pinned) { '<span class="bl-badge">공지</span>' } else { '' }
			$fileTag = if ($p.files -and @($p.files).Count -gt 0) { '<span class="bl-file">첨부 ' + @($p.files).Count + '</span>' } else { '' }
			@"
						<li>
							<a href="../news/view-$($p.id).html">
								<div class="bl-txt">
									<strong class="bl-tit">$badge$(Enc $p.title)</strong>
									<p class="bl-sum">$(Get-Summary $p.content)</p>
								</div>
								<div class="bl-side">
									$fileTag
									<span class="bl-date font-en">$(Format-Date $p.date)</span>
								</div>
							</a>
						</li>
"@
		}
		$listHtml = @"
					<ul class="board-list">
$($rows -join $nl)
					</ul>
"@
	}

	$body = @"
		<section class="cont-sec">
			<div class="area area-narrow">
				<div class="cont-head" data-scroll="fade-up">
					<span class="sec-sub-tit">$($b.en)</span>
					<h3 class="sec-tit">$($b.name)</h3>
				</div>
				<div data-scroll="fade-up">
$listHtml
				</div>
			</div>
		</section>
"@
	Save-Page ('news/' + $b.file) (New-Page $b.name $b.desc $b.key $body)
	$made++

	# ---- 상세 ----
	for ($i = 0; $i -lt $items.Count; $i++) {
		$p = $items[$i]
		$prev = if ($i -gt 0) { $items[$i - 1] } else { $null }
		$next = if ($i -lt $items.Count - 1) { $items[$i + 1] } else { $null }

		$fileHtml = ''
		if ($p.files -and @($p.files).Count -gt 0) {
			$fr = foreach ($f in @($p.files)) {
				"							<li><a href=`"../$($f.path)`" download>$(Enc $f.name)<span class=`"fsize font-en`">$(Format-Size $f.size)</span></a></li>"
			}
			$fileHtml = @"
					<div class="bv-file">
						<span class="bv-file-tit">첨부파일</span>
						<ul>
$($fr -join $nl)
						</ul>
					</div>
"@
		}

		$navHtml = @"
					<ul class="bv-nav">
						<li class="prev">
							<span class="lb">이전 글</span>
							$(if ($prev) { "<a href=`"../news/view-$($prev.id).html`">$(Enc $prev.title)</a>" } else { '<span class="none">이전 글이 없습니다.</span>' })
						</li>
						<li class="next">
							<span class="lb">다음 글</span>
							$(if ($next) { "<a href=`"../news/view-$($next.id).html`">$(Enc $next.title)</a>" } else { '<span class="none">다음 글이 없습니다.</span>' })
						</li>
					</ul>
"@

		$body = @"
		<section class="cont-sec">
			<div class="area area-narrow">
				<div class="board-view" data-scroll="fade-up">
					<div class="bv-head">
						<h3 class="bv-tit">$(Enc $p.title)</h3>
						<div class="bv-meta">
							<span>$($b.name)</span>
							<span class="font-en">$(Format-Date $p.date)</span>
						</div>
					</div>
					<div class="bv-body">
$(Convert-Body $p.content)
					</div>
$fileHtml
$navHtml
					<div class="bv-btn">
						<a href="../news/$($b.file)" class="cm-btn">
							<span class="txt">목록으로</span>
							<span class="icon"></span>
							<span class="hover-icon"></span>
						</a>
					</div>
				</div>
			</div>
		</section>
"@
		Save-Page ("news/view-$($p.id).html") (New-Page $p.title (Get-Summary $p.content) $b.key $body $b.desc)
		$made++
	}
}

# 기본 진입 : news/index.html 은 공지사항으로 보낸다
Save-Page 'news/index.html' @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=notice.html">
<title>News | 대건엠에스 DAEKUN MS</title>
<link rel="canonical" href="notice.html">
</head>
<body><p><a href="notice.html">공지사항으로 이동</a></p></body>
</html>
"@

Write-Output "=== board : $made pages ==="
