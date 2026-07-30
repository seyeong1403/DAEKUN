<?php
/**
 * 사이트 문의 폼 접수 — 방문자가 호출하는 유일한 공개 파일
 *
 * 사이트의 문의 폼에서 이 파일로 보내면 문의가 관리자 「문의 접수」에 쌓인다.
 * contact/inquiry.html 의 data-endpoint 를 아래처럼 바꿔야 동작한다.
 *      data-endpoint="/_admin/inquiry.php"
 *
 * 로그인이 필요 없는 대신, 아래를 막아 둔다.
 *   - 같은 IP 에서 연속 전송 (1분에 3건까지)
 *   - 지나치게 긴 내용
 *   - 실행 가능한 확장자 첨부
 */

require __DIR__ . '/config.php';
require __DIR__ . '/lib/util.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Robots-Tag: noindex, nofollow');
header('X-Content-Type-Options: nosniff');

function out($ok, $msg = '', $extra = array()) {
	$r = array_merge(array('ok' => $ok), $extra);
	if ($msg !== '') { $r['error'] = $msg; }
	echo json_encode($r, JSON_UNESCAPED_UNICODE);
	exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
	http_response_code(405);
	out(false, '잘못된 요청입니다.');
}

// ── 같은 IP 연속 전송 막기 ─────────────────────────────────
$ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '0.0.0.0';
$throttleDir = admin_dir() . '/data/throttle';
ensure_dir($throttleDir);
$key  = $throttleDir . '/' . sha1($ip) . '.txt';
$hits = array();
if (is_file($key)) {
	$prev = json_decode((string)@file_get_contents($key), true);
	if (is_array($prev)) { $hits = $prev; }
}
$now  = time();
$hits = array_values(array_filter($hits, function ($t) use ($now) { return ($now - (int)$t) < 60; }));
if (count($hits) >= 3) {
	http_response_code(429);
	out(false, '잠시 후 다시 시도해 주세요.');
}
$hits[] = $now;
@file_put_contents($key, json_encode($hits));

// 오래된 기록 청소 (10% 확률로)
if (mt_rand(1, 10) === 1) {
	foreach ((array)glob($throttleDir . '/*.txt') as $old) {
		if (is_file($old) && ($now - (int)@filemtime($old)) > 3600) { @unlink($old); }
	}
}

// ── 본문 읽기 ──────────────────────────────────────────────
$raw = file_get_contents('php://input');
if ($raw === false) { $raw = ''; }
if (strlen($raw) > 25 * 1024 * 1024) { out(false, '보내신 내용이 너무 큽니다.'); }

$in = json_decode($raw, true);
if (!is_array($in)) {
	// JSON 이 아니면 일반 폼 전송으로도 받아 준다.
	$in = $_POST;
}
if (!is_array($in)) { out(false, '내용을 읽을 수 없습니다.'); }

function fld($in, $k, $max) {
	$v = isset($in[$k]) ? (string)$in[$k] : '';
	$v = str_replace(array("\0", "\r"), '', $v);
	$v = trim($v);
	if (u_len($v) > $max) { $v = u_cut($v, $max); }
	return $v;
}

$company = fld($in, 'company', 100);
$name    = fld($in, 'name', 50);
$tel     = fld($in, 'tel', 40);
$email   = fld($in, 'email', 120);
$type    = fld($in, 'type', 40);
$message = fld($in, 'message', 5000);

if ($name === '' || $message === '') { out(false, '성명과 문의 내용을 입력해 주세요.'); }
if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
	out(false, '이메일 주소를 확인해 주세요.');
}

// ── 첨부파일 ───────────────────────────────────────────────
$att = array();
if (isset($in['files']) && is_array($in['files'])) {
	ensure_dir(attach_dir());
	$count = 0;
	foreach ($in['files'] as $f) {
		if (!is_array($f) || !isset($f['name'], $f['data'])) { continue; }
		if (++$count > 5) { break; }
		try {
			$fn = safe_filename($f['name']);
		} catch (Exception $e) {
			continue; // 위험한 확장자는 조용히 건너뛴다.
		}
		$bin = base64_decode((string)$f['data'], true);
		if ($bin === false || $bin === '') { continue; }
		if (strlen($bin) > MAX_FILE_BYTES) { continue; }
		$stored = stamp() . '_' . mt_rand(1000, 9999) . '_' . $fn;
		if (@file_put_contents(attach_dir() . '/' . $stored, $bin) !== false) {
			$att[] = array('name' => $fn, 'stored' => $stored);
		}
	}
}

// ── 저장 ───────────────────────────────────────────────────
ensure_dir(data_dir());
$file  = data_dir() . '/inquiries.json';
$items = read_json_array($file);

$id  = date('YmdHis') . substr((string)microtime(true), -3);
$new = array(
	'id'      => $id,
	'at'      => date('Y-m-d H:i:s'),
	'company' => $company,
	'name'    => $name,
	'tel'     => $tel,
	'email'   => $email,
	'type'    => $type,
	'message' => $message,
	'files'   => $att,
	'status'  => 'new',
	'memo'    => '',
	'ip'      => $ip,
);
array_unshift($items, $new);

try {
	save_json($file, $items);
} catch (Exception $e) {
	out(false, '접수 중 문제가 생겼습니다. 잠시 후 다시 시도해 주세요.');
}

// ── 알림 메일 (설정했을 때만) ──────────────────────────────
if (INQUIRY_MAIL_TO !== '') {
	$subject = '[홈페이지 문의] ' . ($company !== '' ? $company : $name);
	$lines = array(
		'회사명 : ' . $company,
		'담당자 : ' . $name,
		'연락처 : ' . $tel,
		'이메일 : ' . $email,
		'구분   : ' . $type,
		'',
		$message,
		'',
		'접수 시각 : ' . $new['at'],
	);
	$headers = "MIME-Version: 1.0\r\n"
		. "Content-Type: text/plain; charset=UTF-8\r\n"
		. "Content-Transfer-Encoding: 8bit\r\n";
	@mail(INQUIRY_MAIL_TO, $subject, implode("\n", $lines), $headers);
}

out(true, '', array('id' => $id));
