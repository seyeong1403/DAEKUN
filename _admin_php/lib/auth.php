<?php
/**
 * 로그인 · 세션
 */

function auth_start() {
	if (session_status() === PHP_SESSION_ACTIVE) { return; }
	session_name('dkadmin');
	$secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
		|| (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');
	if (PHP_VERSION_ID >= 70300) {
		session_set_cookie_params(array(
			'lifetime' => 0,
			'path'     => '/',
			'httponly' => true,
			'samesite' => 'Lax',
			'secure'   => $secure,
		));
	} else {
		session_set_cookie_params(0, '/', '', $secure, true);
	}
	session_start();
}

function auth_ok() {
	auth_start();
	if (empty($_SESSION['dk_login'])) { return false; }
	$at = isset($_SESSION['dk_at']) ? (int)$_SESSION['dk_at'] : 0;
	if ($at <= 0 || (time() - $at) > SESSION_MAX_AGE) {
		auth_logout();
		return false;
	}
	// 활동이 있으면 시간을 갱신한다.
	$_SESSION['dk_at'] = time();
	return true;
}

function auth_login($user, $pass) {
	auth_start();
	$okUser = hash_equals(ADMIN_USER, (string)$user);
	$okPass = password_verify((string)$pass, ADMIN_PASS_HASH);
	// 아이디가 틀려도 비밀번호 검사를 수행해 응답 시간 차이를 줄인다.
	if (!$okUser || !$okPass) { return false; }
	session_regenerate_id(true);
	$_SESSION['dk_login'] = true;
	$_SESSION['dk_at']    = time();
	$_SESSION['dk_token'] = bin2hex(random_bytes(16));
	return true;
}

function auth_logout() {
	auth_start();
	$_SESSION = array();
	if (ini_get('session.use_cookies')) {
		$p = session_get_cookie_params();
		setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], !empty($p['secure']), true);
	}
	session_destroy();
}

function auth_token() {
	auth_start();
	if (empty($_SESSION['dk_token'])) { $_SESSION['dk_token'] = bin2hex(random_bytes(16)); }
	return $_SESSION['dk_token'];
}

/** 다른 사이트에서 몰래 요청을 보내는 것(CSRF)을 막는다. */
function auth_check_token($given) {
	auth_start();
	if (empty($_SESSION['dk_token'])) { return false; }
	return is_string($given) && hash_equals($_SESSION['dk_token'], $given);
}
