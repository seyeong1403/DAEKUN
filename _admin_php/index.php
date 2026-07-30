<?php
/**
 * 관리자 진입점 — 로그인 화면 + 관리자 화면
 */

require __DIR__ . '/config.php';
require __DIR__ . '/lib/util.php';
require __DIR__ . '/lib/auth.php';

header('X-Robots-Tag: noindex, nofollow');
header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');

$action = isset($_GET['a']) ? (string)$_GET['a'] : '';

// ── 로그아웃 ───────────────────────────────────────────────
if ($action === 'logout') {
	auth_logout();
	header('Location: index.php');
	exit;
}

// ── 로그인 처리 ────────────────────────────────────────────
$err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $action === 'login') {
	$u = isset($_POST['user']) ? (string)$_POST['user'] : '';
	$p = isset($_POST['pass']) ? (string)$_POST['pass'] : '';
	if (auth_login($u, $p)) {
		header('Location: index.php');
		exit;
	}
	// 무작위 대입을 늦춘다.
	sleep(1);
	$err = '아이디 또는 비밀번호가 맞지 않습니다.';
}

// ── 로그인 안 된 상태 : 로그인 화면 ────────────────────────
if (!auth_ok()) {
	$warn = $err !== '' ? '<p class="err">' . enc($err) . '</p>' : '';
	header('Content-Type: text/html; charset=utf-8');
	if ($err !== '') { http_response_code(401); }
	echo <<<HTML
<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>대건엠에스 홈페이지 관리자</title>
<style>
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
 background:#101828;font:16px/1.7 'Malgun Gothic',system-ui,sans-serif;word-break:keep-all;padding:20px}
.box{width:100%;max-width:360px;background:#fff;border-radius:14px;padding:38px 32px;
 box-shadow:0 20px 60px rgba(0,0,0,.35)}
h1{margin:0 0 4px;font-size:19px;color:#101828;letter-spacing:-.02em}
.sub{margin:0 0 26px;font-size:14px;color:#667085}
label{display:block;font-size:14px;font-weight:700;color:#344054;margin:0 0 7px}
input{width:100%;padding:12px 14px;font-size:16px;border:1px solid #d0d5dd;border-radius:8px;
 margin-bottom:18px;font-family:inherit}
input:focus{outline:none;border-color:#1e5eff;box-shadow:0 0 0 3px rgba(30,94,255,.14)}
button{width:100%;padding:13px;font-size:16px;font-weight:700;color:#fff;background:#1e5eff;
 border:0;border-radius:8px;cursor:pointer;font-family:inherit}
button:hover{background:#1a52e0}
.err{margin:0 0 18px;padding:11px 14px;background:#fef3f2;border:1px solid #fda29b;
 border-radius:8px;color:#b42318;font-size:14px}
.foot{margin:22px 0 0;font-size:13px;color:#98a2b3;text-align:center}
</style></head><body>
<div class="box">
 <h1>대건엠에스 홈페이지 관리자</h1>
 <p class="sub">아이디와 비밀번호를 입력해 주세요.</p>
 {$warn}
 <form method="post" action="index.php?a=login">
  <label for="u">아이디</label>
  <input id="u" name="user" autocomplete="username" autofocus>
  <label for="p">비밀번호</label>
  <input id="p" name="pass" type="password" autocomplete="current-password">
  <button type="submit">들어가기</button>
 </form>
 <p class="foot">담당자에게 받은 아이디와 비밀번호가 필요합니다.</p>
</div></body></html>
HTML;
	exit;
}

// ── 로그인 된 상태 : 관리자 화면 ───────────────────────────
$uiFile = __DIR__ . '/ui/index.html';
if (!is_file($uiFile)) {
	header('Content-Type: text/plain; charset=utf-8');
	echo 'ui/index.html 이 없습니다. 업로드가 빠졌는지 확인해 주세요.';
	exit;
}
$html = read_text($uiFile);

// 다른 사이트에서 몰래 요청을 보내지 못하게 하는 값을 심는다.
$inject = '<meta name="dk-csrf" content="' . enc(auth_token()) . '">';
if (strpos($html, '</head>') !== false) {
	$html = str_replace('</head>', $inject . "\n</head>", $html);
} else {
	$html = $inject . $html;
}

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');
echo $html;
