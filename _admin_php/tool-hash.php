<?php
/**
 * 비밀번호 해시 만들기 (설치할 때 한 번만 쓰는 도구)
 *
 *  1) 이 파일을 브라우저로 열고 원하는 비밀번호를 입력한다
 *  2) 나온 한 줄을 config.php 의 ADMIN_PASS_HASH 자리에 붙여넣는다
 *  3) 다 끝나면 이 파일을 서버에서 반드시 지운다
 */

header('Content-Type: text/html; charset=utf-8');
header('X-Robots-Tag: noindex, nofollow');

$hash = '';
$pw   = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['pw'])) {
	$pw = (string)$_POST['pw'];
	if ($pw !== '') { $hash = password_hash($pw, PASSWORD_DEFAULT); }
}
$e = function ($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); };
?>
<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>비밀번호 해시 만들기</title>
<style>
body{font:16px/1.7 'Malgun Gothic',system-ui,sans-serif;max-width:640px;margin:8vh auto;padding:0 20px;
 color:#334;word-break:keep-all}
h1{font-size:20px;margin:0 0 6px}
p{color:#667085;font-size:14px}
input{width:100%;padding:12px 14px;font-size:16px;border:1px solid #d0d5dd;border-radius:8px;margin:14px 0}
button{padding:12px 22px;font-size:15px;font-weight:700;color:#fff;background:#1e5eff;border:0;border-radius:8px;cursor:pointer}
pre{background:#101828;color:#a6f4c5;padding:16px;border-radius:8px;overflow-x:auto;font-size:13px}
.warn{margin-top:28px;padding:14px 16px;background:#fef3f2;border:1px solid #fda29b;border-radius:8px;
 color:#b42318;font-size:14px}
</style></head><body>
<h1>비밀번호 해시 만들기</h1>
<p>관리자 로그인에 쓸 비밀번호를 넣으면, <b>config.php</b> 에 붙여넣을 값을 만들어 줍니다.</p>

<form method="post">
	<input type="text" name="pw" placeholder="쓰고 싶은 비밀번호" value="<?php echo $e($pw); ?>" autofocus>
	<button type="submit">만들기</button>
</form>

<?php if ($hash !== ''): ?>
<p style="margin-top:26px">아래 한 줄을 <b>config.php</b> 의 같은 줄과 바꿔 주세요.</p>
<pre>define('ADMIN_PASS_HASH', '<?php echo $e($hash); ?>');</pre>
<p>확인 : <?php echo password_verify($pw, $hash) ? '정상 (이 해시로 로그인됩니다)' : '오류'; ?></p>
<?php endif; ?>

<div class="warn">
	작업이 끝나면 <b>이 파일(tool-hash.php)을 서버에서 지워 주세요.</b>
	남겨 두면 누구나 열 수 있습니다.
</div>
</body></html>
