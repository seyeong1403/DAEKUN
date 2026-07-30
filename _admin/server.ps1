<#
  DAEKUN MS - 관리자 로컬 서버
  ---------------------------------------------------------------
  실행 : _admin\관리자 실행.cmd  (또는)  powershell -File _admin\server.ps1
  주소 : http://localhost:8880/admin/     ← 관리자
         http://localhost:8880/           ← 실제 사이트(미리보기)

  이 서버는 내 PC 안에서만 동작한다. 외부에서는 접속할 수 없다.
  배포 폴더에는 _admin 을 포함하지 않는다.

  외부에 잠깐 보여줄 때 (회의 데모)
  ---------------------------------------------------------------
  -Password 를 주면 모든 요청에 아이디/비밀번호를 묻는다.
  터널로 외부에 열 때는 반드시 이 옵션을 써야 한다.
      powershell -File _admin\server.ps1 -Password "원하는비번"
  아이디는 admin 이다. 비밀번호를 안 주면 예전처럼 그냥 열린다.
#>
param(
	[int]$Port = 8880,
	[string]$Root = '',
	[switch]$NoBrowser,
	[string]$Password = '',
	[string]$User = 'admin',
	[switch]$ReadOnly
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Web
try { Add-Type -AssemblyName System.Drawing } catch {}

# ---------- 경로 ----------
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
$AdminDir = Join-Path $Root '_admin'
$UiDir = Join-Path $AdminDir 'ui'
$DataDir = Join-Path $AdminDir 'data'
$BackupDir = Join-Path $AdminDir 'backups'
$UploadDir = Join-Path $Root 'files'
$ComposePs = Join-Path $Root '_build\compose.ps1'
$BoardPs = Join-Path $AdminDir 'board.ps1'

foreach ($d in @($DataDir, $BackupDir)) {
	if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 로그인 세션 표. 서버를 끄면 사라진다. (-Password 를 쓸 때만 의미가 있다)
$SessionToken = [Guid]::NewGuid().ToString('N')

function Get-LoginPage($msg) {
	$warn = ''
	if ($msg) { $warn = '<p class="err">' + $msg + '</p>' }
	return @"
<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>대건엠에스 홈페이지 관리자</title>
<style>
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
 background:#101828;font:16px/1.7 'Malgun Gothic',system-ui,sans-serif;word-break:keep-all;padding:24px}
.box{width:100%;max-width:380px;background:#fff;border-radius:14px;padding:40px 34px;
 box-shadow:0 20px 60px rgba(0,0,0,.35)}
h1{margin:0 0 4px;font-size:20px;color:#101828;letter-spacing:-.02em}
.sub{margin:0 0 28px;font-size:14px;color:#667085}
label{display:block;font-size:14px;font-weight:700;color:#344054;margin:0 0 7px}
input{width:100%;padding:12px 14px;font-size:16px;border:1px solid #d0d5dd;border-radius:8px;
 margin-bottom:18px;font-family:inherit}
input:focus{outline:none;border-color:#1e5eff;box-shadow:0 0 0 3px rgba(30,94,255,.14)}
button{width:100%;padding:13px;font-size:16px;font-weight:700;color:#fff;background:#1e5eff;
 border:0;border-radius:8px;cursor:pointer;font-family:inherit}
button:hover{background:#1a52e0}
.err{margin:0 0 18px;padding:11px 14px;background:#fef3f2;border:1px solid #fda29b;
 border-radius:8px;color:#b42318;font-size:14px}
.foot{margin:24px 0 0;font-size:13px;color:#98a2b3;text-align:center}
</style></head><body>
<div class="box">
 <h1>대건엠에스 홈페이지 관리자</h1>
 <p class="sub">아이디와 비밀번호를 입력해 주세요.</p>
 $warn
 <form method="post" action="/login">
  <label for="u">아이디</label>
  <input id="u" name="user" autocomplete="username" autofocus>
  <label for="p">비밀번호</label>
  <input id="p" name="pass" type="password" autocomplete="current-password">
  <button type="submit">들어가기</button>
 </form>
 <p class="foot">담당자에게 받은 아이디와 비밀번호가 필요합니다.</p>
</div></body></html>
"@
}

# ---------- 공통 함수 ----------
function Read-TextFile($path) {
	return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}
function Write-TextFile($path, $text) {
	$dir = Split-Path $path -Parent
	if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
	# 원래 파일이 CRLF 였으면 CRLF 로 되돌려 쓴다. (안 그러면 파일 전체가 바뀐 것으로 잡힌다)
	$text = $text -replace "`r`n", "`n"
	if (Test-Path -LiteralPath $path -PathType Leaf) {
		$old = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
		if ($old.Contains("`r`n")) { $text = $text -replace "`n", "`r`n" }
	}
	[System.IO.File]::WriteAllText($path, $text, $Utf8NoBom)
}
function Resolve-Safe($rel) {
	if (-not $rel) { throw '경로가 비어 있습니다.' }
	$rel = ($rel -replace '\\', '/').TrimStart('/')
	if ($rel -match '(^|/)\.\.(/|$)') { throw "허용되지 않는 경로입니다 : $rel" }
	$full = [System.IO.Path]::GetFullPath((Join-Path $Root ($rel -replace '/', '\')))
	if (-not $full.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { throw "작업 폴더 밖입니다 : $rel" }
	return $full
}
function Get-Stamp { return (Get-Date).ToString('yyyyMMdd-HHmmss') }

function Backup-File($rel) {
	$full = Resolve-Safe $rel
	if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return '' }
	$safeName = ($rel -replace '[\\/]', '__')
	$dest = Join-Path $BackupDir ((Get-Stamp) + '__' + $safeName)
	Copy-Item -LiteralPath $full -Destination $dest -Force
	return (Split-Path $dest -Leaf)
}

# 항상 배열로 돌려준다. (ConvertFrom-Json 결과를 바로 @() 로 감싸면 배열 전체가 원소 1개가 된다)
function Read-JsonArray($path) {
	if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
	$raw = (Read-TextFile $path).Trim()
	if (-not $raw) { return @() }
	try { $parsed = ConvertFrom-Json $raw } catch { return @() }
	return @($parsed)
}
function Save-Json($path, $obj) {
	Write-TextFile $path (ConvertTo-Json $obj -Depth 20)
}

# ---------- 페이지 목록 ----------
function Get-PageList {
	$list = New-Object System.Collections.ArrayList
	# 메인
	[void]$list.Add([ordered]@{
			id     = 'index'
			source = 'index.html'
			view   = 'index.html'
			title  = '메인 (홈)'
			group  = '메인'
			kind   = 'page'
		})
	# 서브 조각
	$pagesDir = Join-Path $Root '_build\pages'
	if (Test-Path -LiteralPath $pagesDir) {
		foreach ($f in (Get-ChildItem $pagesDir -Filter '*.html' | Sort-Object Name)) {
			$raw = Read-TextFile $f.FullName
			$meta = @{}
			foreach ($m in [regex]::Matches($raw, '(?m)^\s*<!--@(\w+)\s+(.*?)-->\s*$')) {
				$meta[$m.Groups[1].Value] = $m.Groups[2].Value.Trim()
			}
			$out = $meta['out']
			$grp = '기타'
			if ($out -match '^about/') { $grp = '회사 소개' }
			elseif ($out -match '^business/') { $grp = '사업 영역' }
			elseif ($out -match '^products/') { $grp = '제품' }
			elseif ($out -match '^quality/') { $grp = '품질' }
			elseif ($out -match '^contact/') { $grp = '문의' }
			elseif ($out -match '^etc/') { $grp = '약관·정책' }
			[void]$list.Add([ordered]@{
					id     = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
					source = '_build/pages/' + $f.Name
					view   = $out
					title  = $meta['title']
					group  = $grp
					kind   = 'fragment'
				})
		}
	}
	return $list.ToArray()
}
function Get-PageById($id) {
	foreach ($p in (Get-PageList)) { if ($p.id -eq $id) { return $p } }
	return $null
}

# ---------- 이미지 ----------
function Get-ImageSize($path) {
	$res = [ordered]@{ w = 0; h = 0 }
	try {
		$fs = [System.IO.File]::Open($path, 'Open', 'Read', 'Read')
		try {
			$img = [System.Drawing.Image]::FromStream($fs, $false, $false)
			$res.w = $img.Width; $res.h = $img.Height
			$img.Dispose()
		} finally { $fs.Dispose() }
	} catch {}
	return $res
}
function Get-MediaList($sub) {
	$dir = Join-Path $Root ('images\' + $sub)
	$out = New-Object System.Collections.ArrayList
	if (Test-Path -LiteralPath $dir) {
		foreach ($f in (Get-ChildItem $dir -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|gif|webp|svg)$' } | Sort-Object Name)) {
			$sz = Get-ImageSize $f.FullName
			[void]$out.Add([ordered]@{
					name  = $f.Name
					path  = 'images/' + $sub + '/' + $f.Name
					size  = $f.Length
					kb    = [math]::Round($f.Length / 1KB)
					w     = $sz.w
					h     = $sz.h
					mtime = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
				})
		}
	}
	return , $out.ToArray()
}

# ---------- 스크립트 실행 ----------
function Invoke-Compose {
	if (-not (Test-Path -LiteralPath $ComposePs)) { return '(compose.ps1 없음)' }
	$log = & $ComposePs -Root $Root 2>&1 | Out-String
	return $log
}
function Invoke-BoardBuild {
	if (-not (Test-Path -LiteralPath $BoardPs)) { return '(board.ps1 없음)' }
	$log = & $BoardPs -Root $Root 2>&1 | Out-String
	return $log
}

# ---------- MIME ----------
$mime = @{
	'.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'
	'.css' = 'text/css; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
	'.json' = 'application/json; charset=utf-8'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'
	'.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.webp' = 'image/webp'
	'.mp4' = 'video/mp4'; '.ico' = 'image/x-icon'; '.woff' = 'font/woff'; '.woff2' = 'font/woff2'
	'.ttf' = 'font/ttf'; '.otf' = 'font/otf'; '.pdf' = 'application/pdf'; '.txt' = 'text/plain; charset=utf-8'
	'.zip' = 'application/zip'; '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
	'.docx' = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
	'.hwp' = 'application/x-hwp'; '.csv' = 'text/csv; charset=utf-8'
}

# ---------- 응답 ----------
function Send-Bytes($ctx, [byte[]]$bytes, $type, $code) {
	$ctx.Response.StatusCode = $code
	$ctx.Response.ContentType = $type
	$ctx.Response.Headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
	$ctx.Response.Headers['Pragma'] = 'no-cache'
	$ctx.Response.Headers['Expires'] = '0'
	$ctx.Response.ContentLength64 = $bytes.Length
	$ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
}
function Send-Json($ctx, $obj, $code = 200) {
	$json = ConvertTo-Json $obj -Depth 25
	Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($json)) 'application/json; charset=utf-8' $code
}
function Send-Text($ctx, $text, $type = 'text/plain; charset=utf-8', $code = 200) {
	Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($text)) $type $code
}
function Send-FileOnDisk($ctx, $file) {
	$ext = [System.IO.Path]::GetExtension($file).ToLower()
	$ct = $mime[$ext]; if (-not $ct) { $ct = 'application/octet-stream' }
	Send-Bytes $ctx ([System.IO.File]::ReadAllBytes($file)) $ct 200
}
function Get-Body($ctx) {
	$sr = New-Object System.IO.StreamReader($ctx.Request.InputStream, [System.Text.Encoding]::UTF8)
	$txt = $sr.ReadToEnd()
	$sr.Close()
	if (-not $txt) { return $null }
	return (ConvertFrom-Json $txt)
}

# ---------- 서버 시작 ----------
# 이미 관리자가 떠 있으면 새로 띄우지 않고 그 주소를 열어준다.
function Test-AdminAlive($p) {
	try {
		$req = [System.Net.WebRequest]::Create("http://localhost:$p/api/ping")
		$req.Timeout = 1200
		$res = $req.GetResponse()
		$txt = (New-Object System.IO.StreamReader($res.GetResponseStream())).ReadToEnd()
		$res.Close()
		return ($txt -match '"ok"')
	} catch { return $false }
}

if (Test-AdminAlive $Port) {
	Write-Host ""
	Write-Host "  관리자가 이미 실행 중입니다. 그 창을 그대로 쓰시면 됩니다." -ForegroundColor Yellow
	Write-Host "  주소 : http://localhost:$Port/admin/" -ForegroundColor White
	Write-Host ""
	if (-not $NoBrowser) { Start-Process "http://localhost:$Port/admin/" | Out-Null }
	Start-Sleep -Seconds 4
	exit 0
}

# 포트가 막혀 있으면 다음 번호로 자동으로 옮겨 간다.
$listener = $null
$startPort = $Port
foreach ($try in $startPort..($startPort + 9)) {
	$l = New-Object System.Net.HttpListener
	$l.Prefixes.Add("http://localhost:$try/")
	$l.Prefixes.Add("http://127.0.0.1:$try/")
	try {
		$l.Start()
		$listener = $l
		$Port = $try
		break
	} catch {
		try { $l.Close() } catch {}
	}
}
if (-not $listener) {
	Write-Host ""
	Write-Host "  [오류] $startPort ~ $($startPort + 9) 번 포트를 모두 열 수 없습니다." -ForegroundColor Red
	Write-Host "  PC를 다시 시작한 뒤 실행해 보세요." -ForegroundColor Yellow
	Write-Host ""
	Read-Host "  엔터를 누르면 닫힙니다"
	exit 1
}
if ($Port -ne $startPort) {
	Write-Host ""
	Write-Host "  ※ $startPort 번 포트가 사용 중이라 $Port 번으로 열었습니다." -ForegroundColor Yellow
}

$adminUrl = "http://localhost:$Port/admin/"
Write-Host ""
Write-Host "  ┌────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
Write-Host "  │  대건엠에스 홈페이지 관리자                      │" -ForegroundColor Cyan
Write-Host "  └────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
Write-Host "   관리자   $adminUrl" -ForegroundColor White
Write-Host "   사이트   http://localhost:$Port/" -ForegroundColor Gray
Write-Host "   폴더     $Root" -ForegroundColor DarkGray
if ($Password) {
	Write-Host ""
	Write-Host "   비밀번호 켜짐   아이디 $User  /  비밀번호 $Password" -ForegroundColor Yellow
}
if ($ReadOnly) {
	Write-Host "   구경만 모드     저장 · 배포가 잠겨 있습니다." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "   ※ 이 창을 닫으면 관리자가 종료됩니다." -ForegroundColor DarkYellow
Write-Host ""

if (-not $NoBrowser) { Start-Process $adminUrl | Out-Null }

# ---------- 요청 루프 ----------
while ($listener.IsListening) {
	$ctx = $null
	try { $ctx = $listener.GetContext() } catch { break }
	if (-not $ctx) { continue }

	try {
		$req = $ctx.Request
		$path = [System.Web.HttpUtility]::UrlDecode($req.Url.AbsolutePath)
		$q = $req.QueryString
		$method = $req.HttpMethod

		$ctx.Response.Headers['Access-Control-Allow-Origin'] = '*'
		$ctx.Response.Headers['Access-Control-Allow-Headers'] = 'Content-Type'
		if ($method -eq 'OPTIONS') { $ctx.Response.StatusCode = 204; $ctx.Response.OutputStream.Close(); continue }

		# ---------- 로그인 (외부에 열어 둔 동안) ----------
		# -Password 를 준 경우에만 동작한다. 안 주면 예전과 똑같이 그냥 열린다.
		if ($Password) {
			$okAuth = $false

			# 1) 로그인 쿠키
			$ck = $req.Headers['Cookie']
			if ($ck -and $ck -match 'dkadmin=([0-9a-f]{32})') {
				if ($Matches[1] -ceq $SessionToken) { $okAuth = $true }
			}
			# 2) Basic 헤더 (점검 · 스크립트용. 브라우저는 위 쿠키를 쓴다)
			if (-not $okAuth) {
				$hdr = $req.Headers['Authorization']
				if ($hdr -and $hdr.StartsWith('Basic ', [StringComparison]::OrdinalIgnoreCase)) {
					try {
						$dec = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($hdr.Substring(6).Trim()))
						$sep = $dec.IndexOf(':')
						if ($sep -ge 0 -and $dec.Substring(0, $sep) -ceq $User -and $dec.Substring($sep + 1) -ceq $Password) { $okAuth = $true }
					} catch {}
				}
			}

			if (-not $okAuth) {
				# 로그인 제출
				if ($path -eq '/login' -and $method -eq 'POST') {
					$rawForm = ''
					try {
						$sr = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
						$rawForm = $sr.ReadToEnd()
					} catch {}
					$form = [System.Web.HttpUtility]::ParseQueryString($rawForm)
					if ($form['user'] -ceq $User -and $form['pass'] -ceq $Password) {
						$ctx.Response.AddHeader('Set-Cookie', "dkadmin=$SessionToken; Path=/; HttpOnly; SameSite=Lax")
						$ctx.Response.StatusCode = 302
						$ctx.Response.AddHeader('Location', '/admin/')
						$ctx.Response.OutputStream.Close()
						continue
					}
					$bz = $Utf8NoBom.GetBytes((Get-LoginPage '아이디 또는 비밀번호가 맞지 않습니다.'))
					$ctx.Response.StatusCode = 401
					$ctx.Response.ContentType = 'text/html; charset=utf-8'
					$ctx.Response.OutputStream.Write($bz, 0, $bz.Length)
					$ctx.Response.OutputStream.Close()
					continue
				}
				# 그 밖의 모든 요청 → 로그인 화면 (API 는 401 만 돌려준다)
				if ($path.StartsWith('/api/')) {
					$ctx.Response.StatusCode = 401
					$ctx.Response.ContentType = 'application/json; charset=utf-8'
					$bz = $Utf8NoBom.GetBytes('{"ok":false,"error":"로그인이 필요합니다."}')
				} else {
					$ctx.Response.StatusCode = 401
					$ctx.Response.ContentType = 'text/html; charset=utf-8'
					$bz = $Utf8NoBom.GetBytes((Get-LoginPage ''))
				}
				$ctx.Response.OutputStream.Write($bz, 0, $bz.Length)
				$ctx.Response.OutputStream.Close()
				continue
			}
		}

		# ---------- 읽기 전용 (구경만 시킬 때) ----------
		# 저장·업로드·배포는 모두 POST 라서 POST 만 막으면 된다.
		if ($ReadOnly -and $method -eq 'POST') {
			$ctx.Response.StatusCode = 403
			$ctx.Response.ContentType = 'application/json; charset=utf-8'
			$bz = $Utf8NoBom.GetBytes('{"ok":false,"error":"구경만 할 수 있는 모드입니다. 저장·배포는 잠겨 있습니다."}')
			$ctx.Response.OutputStream.Write($bz, 0, $bz.Length)
			$ctx.Response.OutputStream.Close()
			continue
		}

		# ============================ API ============================
		if ($path.StartsWith('/api/')) {
			$route = $path.Substring(5).TrimEnd('/')
			$body = $null
			if ($method -eq 'POST') { $body = Get-Body $ctx }

			switch ($route) {

				# --- 상태 ---
				'ping' { Send-Json $ctx ([ordered]@{ ok = $true; root = $Root }) }

				'state' {
					$inq = @(Read-JsonArray (Join-Path $DataDir 'inquiries.json'))
					$posts = @(Read-JsonArray (Join-Path $DataDir 'posts.json'))
					$newCnt = @($inq | Where-Object { $_.status -eq 'new' }).Count
					$pages = @(Get-PageList)
					$imgs = Get-MediaList 'content'
					Send-Json $ctx ([ordered]@{
							ok        = $true
							root      = $Root
							pages     = $pages
							pageCount = $pages.Count
							imgCount  = $imgs.Count
							inqTotal  = $inq.Count
							inqNew    = $newCnt
							postTotal = $posts.Count
							port      = $Port
						})
				}

				# --- 파일 읽기/쓰기 ---
				'file' {
					$rel = $q['path']
					$full = Resolve-Safe $rel
					if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Send-Json $ctx ([ordered]@{ ok = $false; error = "파일이 없습니다 : $rel" }) 404; break }
					Send-Json $ctx ([ordered]@{ ok = $true; path = $rel; content = (Read-TextFile $full) })
				}

				'save' {
					$rel = $body.path
					$full = Resolve-Safe $rel
					$bk = Backup-File $rel
					Write-TextFile $full $body.content
					$log = ''
					if ($body.compose) { $log = Invoke-Compose }
					Send-Json $ctx ([ordered]@{ ok = $true; backup = $bk; log = $log })
				}

				'compose' { Send-Json $ctx ([ordered]@{ ok = $true; log = (Invoke-Compose) }) }

				# --- 이미지 ---
				'media' {
					Send-Json $ctx ([ordered]@{
							ok      = $true
							content = (Get-MediaList 'content')
							common  = (Get-MediaList 'common')
							main    = (Get-MediaList 'main')
						})
				}

				'media-upload' {
					$name = ($body.name -replace '[^A-Za-z0-9._-]', '_')
					if (-not $name) { throw '파일명이 없습니다.' }
					$sub = $body.folder; if (-not $sub) { $sub = 'content' }
					if ($sub -notin @('content', 'common', 'main')) { throw '허용되지 않는 폴더입니다.' }
					$dir = Join-Path $Root ('images\' + $sub)
					if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
					$dest = Join-Path $dir $name
					if ((Test-Path -LiteralPath $dest) -and -not $body.overwrite) {
						$base = [System.IO.Path]::GetFileNameWithoutExtension($name)
						$ext = [System.IO.Path]::GetExtension($name)
						$i = 2
						while (Test-Path -LiteralPath $dest) { $name = "$base`_$i$ext"; $dest = Join-Path $dir $name; $i++ }
					} elseif (Test-Path -LiteralPath $dest) {
						Copy-Item -LiteralPath $dest -Destination (Join-Path $BackupDir ((Get-Stamp) + '__images__' + $sub + '__' + $name)) -Force
					}
					[System.IO.File]::WriteAllBytes($dest, [Convert]::FromBase64String($body.data))
					$sz = Get-ImageSize $dest
					Send-Json $ctx ([ordered]@{ ok = $true; name = $name; path = 'images/' + $sub + '/' + $name; w = $sz.w; h = $sz.h })
				}

				'media-delete' {
					$rel = $body.path
					if ($rel -notmatch '^images/(content|common|main)/') { throw '이미지 폴더의 파일만 삭제할 수 있습니다.' }
					$full = Resolve-Safe $rel
					if (Test-Path -LiteralPath $full) {
						Move-Item -LiteralPath $full -Destination (Join-Path $BackupDir ((Get-Stamp) + '__deleted__' + (Split-Path $rel -Leaf))) -Force
					}
					Send-Json $ctx ([ordered]@{ ok = $true })
				}

				# --- 첨부파일(게시판) ---
				'file-upload' {
					$name = $body.name
					$name = $name -replace '[\\/:*?"<>|]', '_'
					if (-not (Test-Path -LiteralPath $UploadDir)) { New-Item -ItemType Directory -Force -Path $UploadDir | Out-Null }
					$dest = Join-Path $UploadDir $name
					$base = [System.IO.Path]::GetFileNameWithoutExtension($name)
					$ext = [System.IO.Path]::GetExtension($name)
					$i = 2
					while (Test-Path -LiteralPath $dest) { $name = "$base`_$i$ext"; $dest = Join-Path $UploadDir $name; $i++ }
					[System.IO.File]::WriteAllBytes($dest, [Convert]::FromBase64String($body.data))
					Send-Json $ctx ([ordered]@{ ok = $true; name = $name; path = 'files/' + $name; size = (Get-Item -LiteralPath $dest).Length })
				}

				# --- 문의 ---
				'inquiries' {
					Send-Json $ctx ([ordered]@{ ok = $true; items = @(Read-JsonArray (Join-Path $DataDir 'inquiries.json')) })
				}

				'inquiries-save' {
					Save-Json (Join-Path $DataDir 'inquiries.json') @($body.items)
					Send-Json $ctx ([ordered]@{ ok = $true })
				}

				# 사이트 문의 폼이 실제로 호출하는 접수 엔드포인트
				'inquiry' {
					$file = Join-Path $DataDir 'inquiries.json'
					$items = @(Read-JsonArray $file)
					$att = New-Object System.Collections.ArrayList
					if ($body.files) {
						$inqDir = Join-Path $AdminDir 'attachments'
						if (-not (Test-Path -LiteralPath $inqDir)) { New-Item -ItemType Directory -Force -Path $inqDir | Out-Null }
						foreach ($f in @($body.files)) {
							$fn = (Get-Stamp) + '_' + ($f.name -replace '[\\/:*?"<>|]', '_')
							[System.IO.File]::WriteAllBytes((Join-Path $inqDir $fn), [Convert]::FromBase64String($f.data))
							[void]$att.Add([ordered]@{ name = $f.name; stored = $fn })
						}
					}
					$id = (Get-Date).ToString('yyyyMMddHHmmssfff')
					$new = [ordered]@{
						id      = $id
						at      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
						company = [string]$body.company
						name    = [string]$body.name
						tel     = [string]$body.tel
						email   = [string]$body.email
						type    = [string]$body.type
						message = [string]$body.message
						files   = @($att.ToArray())
						status  = 'new'
						memo    = ''
					}
					$items = @($new) + $items
					Save-Json $file $items
					Write-Host ("  [문의 접수] {0} / {1}" -f $new.company, $new.name) -ForegroundColor Green
					Send-Json $ctx ([ordered]@{ ok = $true; id = $id })
				}

				# --- 게시판 ---
				'posts' {
					Send-Json $ctx ([ordered]@{ ok = $true; items = @(Read-JsonArray (Join-Path $DataDir 'posts.json')) })
				}

				'posts-save' {
					Save-Json (Join-Path $DataDir 'posts.json') @($body.items)
					$log = ''
					if ($body.publish) { $log = Invoke-BoardBuild }
					Send-Json $ctx ([ordered]@{ ok = $true; log = $log })
				}

				'board-build' { Send-Json $ctx ([ordered]@{ ok = $true; log = (Invoke-BoardBuild) }) }

				# --- 백업 ---
				'backups' {
					$items = New-Object System.Collections.ArrayList
					foreach ($f in (Get-ChildItem $BackupDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 200)) {
						[void]$items.Add([ordered]@{ name = $f.Name; at = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'); kb = [math]::Round($f.Length / 1KB, 1) })
					}
					Send-Json $ctx ([ordered]@{ ok = $true; items = @($items.ToArray()) })
				}

				'restore' {
					$name = $body.name
					$src = Join-Path $BackupDir $name
					if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw '백업 파일이 없습니다.' }
					$rel = ($name -replace '^\d{8}-\d{6}__', '') -replace '__', '/'
					$dest = Resolve-Safe $rel
					Backup-File $rel | Out-Null
					Copy-Item -LiteralPath $src -Destination $dest -Force
					Send-Json $ctx ([ordered]@{ ok = $true; restored = $rel; log = (Invoke-Compose) })
				}

				# --- Git ---
				'git-status' {
					Push-Location $Root
					try { $out = (git status --porcelain 2>&1 | Out-String) } catch { $out = 'git 사용 불가' }
					Pop-Location
					Send-Json $ctx ([ordered]@{ ok = $true; log = $out })
				}

				'git-push' {
					$msg = $body.message; if (-not $msg) { $msg = '관리자에서 콘텐츠 수정' }
					Push-Location $Root
					$out = ''
					try {
						$out += (git add -A 2>&1 | Out-String)
						$out += (git commit -m $msg 2>&1 | Out-String)
						$out += (git push 2>&1 | Out-String)
					} catch { $out += $_.Exception.Message }
					Pop-Location
					Send-Json $ctx ([ordered]@{ ok = $true; log = $out })
				}

				default { Send-Json $ctx ([ordered]@{ ok = $false; error = "없는 API : $route" }) 404 }
			}
			$ctx.Response.OutputStream.Close()
			continue
		}

		# ======================== 관리자 UI ========================
		# 상대 주소로 보낸다. (localhost 절대주소로 보내면 외부에서 열었을 때 깨진다)
		if ($path -eq '/admin' ) { $ctx.Response.StatusCode = 302; $ctx.Response.AddHeader('Location', '/admin/'); $ctx.Response.OutputStream.Close(); continue }
		if ($path.StartsWith('/admin/')) {
			$sub = $path.Substring(7)
			if (-not $sub) { $sub = 'index.html' }
			$file = Join-Path $UiDir ($sub -replace '/', '\')
			if (Test-Path -LiteralPath $file -PathType Leaf) { Send-FileOnDisk $ctx $file }
			else { Send-Text $ctx "관리자 파일 없음 : $sub" 'text/plain; charset=utf-8' 404 }
			$ctx.Response.OutputStream.Close()
			continue
		}

		# ========================= 사이트 =========================
		$p = $path
		if ($p.EndsWith('/')) { $p += 'index.html' }
		$file = Join-Path $Root ($p.TrimStart('/') -replace '/', '\')
		if (Test-Path -LiteralPath $file -PathType Leaf) { Send-FileOnDisk $ctx $file }
		else { Send-Text $ctx "404 Not Found : $path" 'text/plain; charset=utf-8' 404 }
		$ctx.Response.OutputStream.Close()

	} catch {
		try {
			Send-Json $ctx ([ordered]@{ ok = $false; error = $_.Exception.Message }) 500
			$ctx.Response.OutputStream.Close()
		} catch {}
		Write-Host ("  [오류] " + $_.Exception.Message) -ForegroundColor Red
	}
}
