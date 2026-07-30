<?php
/**
 * 공통 함수
 * PHP 7.4 이상에서 동작한다. mbstring 이 없어도 돌아가게 작성했다.
 */

function admin_dir()   { return dirname(__DIR__); }
function data_dir()    { return admin_dir() . '/data'; }
function backup_dir()  { return admin_dir() . '/backups'; }
function attach_dir()  { return admin_dir() . '/attachments'; }
function upload_dir()  { return SITE_ROOT . '/files'; }

function ensure_dir($d) {
	if (!is_dir($d)) { @mkdir($d, 0777, true); }
	return is_dir($d);
}

/** 응답 */
function send_json($obj, $code = 200) {
	http_response_code($code);
	header('Content-Type: application/json; charset=utf-8');
	header('Cache-Control: no-store, no-cache, must-revalidate');
	header('X-Robots-Tag: noindex, nofollow');
	echo json_encode($obj, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
	exit;
}
function fail($msg, $code = 400) {
	send_json(array('ok' => false, 'error' => $msg), $code);
}

/** 파일 읽기 · 쓰기 (UTF-8, BOM 없음, 줄바꿈 보존) */
function read_text($path) {
	$s = @file_get_contents($path);
	if ($s === false) { return ''; }
	// BOM 이 있으면 떼어낸다.
	if (substr($s, 0, 3) === "\xEF\xBB\xBF") { $s = substr($s, 3); }
	return $s;
}
function write_text($path, $text) {
	$dir = dirname($path);
	if (!ensure_dir($dir)) { throw new Exception('폴더를 만들 수 없습니다 : ' . $dir); }

	// 원래 파일이 CRLF 였으면 CRLF 로 되돌려 쓴다.
	$text = str_replace("\r\n", "\n", $text);
	if (is_file($path)) {
		$old = read_text($path);
		if (strpos($old, "\r\n") !== false) { $text = str_replace("\n", "\r\n", $text); }
	}
	if (@file_put_contents($path, $text) === false) {
		throw new Exception('파일을 저장할 수 없습니다 : ' . basename($path) . ' (폴더 권한을 확인하세요)');
	}
	return true;
}

/**
 * 작업 폴더 밖으로 나가지 못하게 막는다.
 * 공개 서버에서 도는 코드이므로 이 검사가 가장 중요하다.
 */
function resolve_safe($rel) {
	if ($rel === null || $rel === '') { throw new Exception('경로가 비어 있습니다.'); }
	$rel = str_replace('\\', '/', $rel);
	$rel = ltrim($rel, '/');
	if ($rel === '' || preg_match('#(^|/)\.\.(/|$)#', $rel)) {
		throw new Exception('허용되지 않는 경로입니다 : ' . $rel);
	}
	if (preg_match('#[\x00-\x1f]#', $rel)) { throw new Exception('허용되지 않는 경로입니다.'); }

	$root = rtrim(str_replace('\\', '/', realpath(SITE_ROOT)), '/');
	$full = $root . '/' . $rel;

	// 이미 있는 파일이면 realpath 로 한 번 더 검증한다. (심볼릭 링크 우회 차단)
	$check = realpath($full);
	if ($check !== false) {
		$check = str_replace('\\', '/', $check);
		if (strpos($check, $root . '/') !== 0 && $check !== $root) {
			throw new Exception('작업 폴더 밖입니다 : ' . $rel);
		}
		return $check;
	}
	// 새로 만드는 파일이면 부모 폴더로 검증한다.
	$parent = realpath(dirname($full));
	if ($parent === false) { throw new Exception('상위 폴더가 없습니다 : ' . $rel); }
	$parent = str_replace('\\', '/', $parent);
	if (strpos($parent, $root) !== 0) { throw new Exception('작업 폴더 밖입니다 : ' . $rel); }
	return $full;
}

function stamp() { return date('Ymd-His'); }

/** 파일을 백업 폴더에 복사한다. 복사한 파일명을 돌려준다. */
function backup_file($rel) {
	try { $full = resolve_safe($rel); } catch (Exception $e) { return ''; }
	if (!is_file($full)) { return ''; }
	ensure_dir(backup_dir());
	$safe = str_replace(array('/', '\\'), '__', ltrim(str_replace('\\', '/', $rel), '/'));
	$name = stamp() . '__' . $safe;
	@copy($full, backup_dir() . '/' . $name);
	return $name;
}

/** JSON 목록 읽기 — 언제나 배열을 돌려준다. */
function read_json_array($path) {
	if (!is_file($path)) { return array(); }
	$raw = trim(read_text($path));
	if ($raw === '') { return array(); }
	$v = json_decode($raw, true);
	if (!is_array($v)) { return array(); }
	// 빈 배열을 먼저 걸러낸다. range(0,-1) 은 [0,-1] 이 되므로
	// 아래 검사에 그냥 넘기면 빈 배열이 원소 1개짜리로 감싸진다.
	if (count($v) === 0) { return array(); }
	// 객체 하나만 들어 있으면 배열로 감싼다.
	if (array_keys($v) !== range(0, count($v) - 1)) { return array($v); }
	return $v;
}
function save_json($path, $arr) {
	write_text($path, json_encode($arr, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT));
}

/** UTF-8 안전 자르기 (mbstring 없어도 동작) */
function u_cut($s, $len) {
	if (function_exists('mb_substr')) {
		return mb_substr($s, 0, $len, 'UTF-8');
	}
	$out = preg_split('//u', $s, -1, PREG_SPLIT_NO_EMPTY);
	if (!is_array($out)) { return substr($s, 0, $len); }
	return implode('', array_slice($out, 0, $len));
}
function u_len($s) {
	if (function_exists('mb_strlen')) { return mb_strlen($s, 'UTF-8'); }
	$a = preg_split('//u', $s, -1, PREG_SPLIT_NO_EMPTY);
	return is_array($a) ? count($a) : strlen($s);
}

function enc($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

/** 파일명 정리 */
function safe_filename($name, $imageOnly = false) {
	$name = basename(str_replace('\\', '/', (string)$name));
	$name = preg_replace('#[\x00-\x1f]#', '', $name);
	if ($imageOnly) {
		$name = preg_replace('/[^A-Za-z0-9._-]/', '_', $name);
	} else {
		$name = preg_replace('#[\\\\/:*?"<>|]#', '_', $name);
	}
	$name = ltrim($name, '.');
	if ($name === '') { throw new Exception('파일명이 없습니다.'); }
	// 서버에서 실행될 수 있는 확장자는 막는다.
	if (preg_match('/\.(php\d?|phtml|phar|cgi|pl|py|sh|htaccess)$/i', $name)) {
		throw new Exception('이 확장자는 올릴 수 없습니다 : ' . $name);
	}
	return $name;
}

/** 이미지 크기 — getimagesize 는 gd 확장 없이도 동작한다. */
function image_size($path) {
	$r = array('w' => 0, 'h' => 0);
	$s = @getimagesize($path);
	if (is_array($s)) { $r['w'] = (int)$s[0]; $r['h'] = (int)$s[1]; }
	return $r;
}

/** 페이지 목록 (메인 + _build/pages 조각) */
function get_page_list() {
	$list = array();
	$list[] = array(
		'id' => 'index', 'source' => 'index.html', 'view' => 'index.html',
		'title' => '메인 (홈)', 'group' => '메인', 'kind' => 'page',
	);
	$dir = SITE_ROOT . '/_build/pages';
	if (is_dir($dir)) {
		$files = glob($dir . '/*.html');
		if (!is_array($files)) { $files = array(); }
		sort($files);
		foreach ($files as $f) {
			$raw = read_text($f);
			$meta = array();
			if (preg_match_all('/^[ \t]*<!--@(\w+)\s+(.*?)-->[ \t]*$/m', $raw, $ms, PREG_SET_ORDER)) {
				foreach ($ms as $m) { $meta[$m[1]] = trim($m[2]); }
			}
			$out = isset($meta['out']) ? $meta['out'] : '';
			$grp = '기타';
			if (strpos($out, 'about/') === 0)         { $grp = '회사 소개'; }
			elseif (strpos($out, 'business/') === 0)  { $grp = '사업 영역'; }
			elseif (strpos($out, 'products/') === 0)  { $grp = '제품'; }
			elseif (strpos($out, 'quality/') === 0)   { $grp = '품질'; }
			elseif (strpos($out, 'contact/') === 0)   { $grp = '문의'; }
			elseif (strpos($out, 'etc/') === 0)       { $grp = '약관·정책'; }
			$list[] = array(
				'id'     => pathinfo($f, PATHINFO_FILENAME),
				'source' => '_build/pages/' . basename($f),
				'view'   => $out,
				'title'  => isset($meta['title']) ? $meta['title'] : basename($f),
				'group'  => $grp,
				'kind'   => 'fragment',
			);
		}
	}
	return $list;
}

/** 이미지 목록 */
function get_media_list($sub) {
	$dir = SITE_ROOT . '/images/' . $sub;
	$out = array();
	if (!is_dir($dir)) { return $out; }
	$files = glob($dir . '/*');
	if (!is_array($files)) { return $out; }
	sort($files);
	foreach ($files as $f) {
		if (!is_file($f)) { continue; }
		$ext = strtolower(pathinfo($f, PATHINFO_EXTENSION));
		if (!in_array($ext, array('jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'), true)) { continue; }
		$sz = image_size($f);
		$len = (int)@filesize($f);
		$out[] = array(
			'name'  => basename($f),
			'path'  => 'images/' . $sub . '/' . basename($f),
			'size'  => $len,
			'kb'    => round($len / 1024),
			'w'     => $sz['w'],
			'h'     => $sz['h'],
			'mtime' => date('Y-m-d H:i', (int)@filemtime($f)),
		);
	}
	return $out;
}
