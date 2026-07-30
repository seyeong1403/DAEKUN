<?php
/**
 * 관리자 API — server.ps1 의 API 19개를 그대로 옮겼다.
 * 응답 형태(JSON 키 이름)가 같아야 ui/admin.js 가 수정 없이 동작한다.
 *
 * 호출 : api.php?r=<라우트>
 */

require __DIR__ . '/config.php';
require __DIR__ . '/lib/util.php';
require __DIR__ . '/lib/auth.php';
require __DIR__ . '/lib/compose.php';
require __DIR__ . '/lib/board.php';

header('X-Robots-Tag: noindex, nofollow');
header('X-Content-Type-Options: nosniff');

$route  = isset($_GET['r']) ? (string)$_GET['r'] : '';
$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET';

// ── 로그인 확인 ────────────────────────────────────────────
if (!auth_ok()) {
	fail('로그인이 필요합니다.', 401);
}

// ── 본문 읽기 ──────────────────────────────────────────────
$body = array();
if ($method === 'POST') {
	$raw = file_get_contents('php://input');
	if ($raw !== '' && $raw !== false) {
		$parsed = json_decode($raw, true);
		if (is_array($parsed)) { $body = $parsed; }
	}
	// 다른 사이트에서 몰래 보내는 요청을 막는다.
	$tok = isset($_SERVER['HTTP_X_CSRF']) ? $_SERVER['HTTP_X_CSRF'] : '';
	if (!auth_check_token($tok)) {
		fail('요청이 만료되었습니다. 새로고침 후 다시 시도해 주세요.', 403);
	}
}
function bget($k, $d = null) {
	global $body;
	return isset($body[$k]) ? $body[$k] : $d;
}

ensure_dir(data_dir());
ensure_dir(backup_dir());

try {
	switch ($route) {

		// ── 상태 ──────────────────────────────────────────
		case 'ping':
			send_json(array('ok' => true, 'root' => SITE_ROOT));
			break;

		case 'state':
			$inq   = read_json_array(data_dir() . '/inquiries.json');
			$posts = read_json_array(data_dir() . '/posts.json');
			$newCnt = 0;
			foreach ($inq as $q) {
				if (isset($q['status']) && $q['status'] === 'new') { $newCnt++; }
			}
			$pages = get_page_list();
			$imgs  = get_media_list('content');
			// 사이트 문의 폼이 이 서버의 inquiry.php 로 연결돼 있는지 확인한다.
			$wired = false;
			$formPage = SITE_ROOT . '/contact/inquiry.html';
			if (is_file($formPage)) {
				$wired = strpos(read_text($formPage), 'inquiry.php') !== false;
			}
			send_json(array(
				'ok'        => true,
				'root'      => SITE_ROOT,
				'inqWired'  => $wired,
				'pages'     => $pages,
				'pageCount' => count($pages),
				'imgCount'  => count($imgs),
				'inqTotal'  => count($inq),
				'inqNew'    => $newCnt,
				'postTotal' => count($posts),
				'port'      => 0,
			));
			break;

		// ── 파일 읽기 / 쓰기 ──────────────────────────────
		case 'file':
			$rel  = isset($_GET['path']) ? (string)$_GET['path'] : '';
			$full = resolve_safe($rel);
			if (!is_file($full)) { fail('파일이 없습니다 : ' . $rel, 404); }
			send_json(array('ok' => true, 'path' => $rel, 'content' => read_text($full)));
			break;

		case 'save':
			$rel  = (string)bget('path', '');
			$full = resolve_safe($rel);
			$bk   = backup_file($rel);
			write_text($full, (string)bget('content', ''));
			$log = '';
			if (bget('compose')) { $log = run_compose(); }
			send_json(array('ok' => true, 'backup' => $bk, 'log' => $log));
			break;

		case 'compose':
			send_json(array('ok' => true, 'log' => run_compose()));
			break;

		// ── 이미지 ────────────────────────────────────────
		case 'media':
			send_json(array(
				'ok'      => true,
				'content' => get_media_list('content'),
				'common'  => get_media_list('common'),
				'main'    => get_media_list('main'),
			));
			break;

		case 'media-upload':
			$name = safe_filename(bget('name', ''), true);
			$sub  = (string)bget('folder', 'content');
			if ($sub === '') { $sub = 'content'; }
			if (!in_array($sub, array('content', 'common', 'main'), true)) {
				throw new Exception('허용되지 않는 폴더입니다.');
			}
			$ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
			if (!in_array($ext, array('jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'), true)) {
				throw new Exception('이미지 파일만 올릴 수 있습니다. (jpg, png, gif, webp, svg)');
			}
			$bin = base64_decode((string)bget('data', ''), true);
			if ($bin === false || $bin === '') { throw new Exception('파일 내용을 읽을 수 없습니다.'); }
			if (strlen($bin) > MAX_IMAGE_BYTES) {
				throw new Exception('이미지가 너무 큽니다. (최대 ' . round(MAX_IMAGE_BYTES / 1048576) . 'MB)');
			}
			$dir = SITE_ROOT . '/images/' . $sub;
			ensure_dir($dir);
			$dest = $dir . '/' . $name;
			if (is_file($dest) && !bget('overwrite')) {
				$base = pathinfo($name, PATHINFO_FILENAME);
				$e2   = pathinfo($name, PATHINFO_EXTENSION);
				$i = 2;
				while (is_file($dest)) {
					$name = $base . '_' . $i . '.' . $e2;
					$dest = $dir . '/' . $name;
					$i++;
				}
			} elseif (is_file($dest)) {
				@copy($dest, backup_dir() . '/' . stamp() . '__images__' . $sub . '__' . $name);
			}
			if (@file_put_contents($dest, $bin) === false) {
				throw new Exception('이미지를 저장할 수 없습니다. images/' . $sub . ' 폴더 권한을 확인하세요.');
			}
			$sz = image_size($dest);
			send_json(array('ok' => true, 'name' => $name, 'path' => 'images/' . $sub . '/' . $name, 'w' => $sz['w'], 'h' => $sz['h']));
			break;

		case 'media-delete':
			$rel = (string)bget('path', '');
			if (!preg_match('~^images/(content|common|main)/~', $rel)) {
				throw new Exception('이미지 폴더의 파일만 삭제할 수 있습니다.');
			}
			$full = resolve_safe($rel);
			if (is_file($full)) {
				// 지우지 않고 백업 폴더로 옮긴다. 되돌릴 수 있게.
				@rename($full, backup_dir() . '/' . stamp() . '__deleted__' . basename($rel));
			}
			send_json(array('ok' => true));
			break;

		// ── 첨부파일 (게시판) ─────────────────────────────
		case 'file-upload':
			$name = safe_filename(bget('name', ''));
			$bin  = base64_decode((string)bget('data', ''), true);
			if ($bin === false || $bin === '') { throw new Exception('파일 내용을 읽을 수 없습니다.'); }
			if (strlen($bin) > MAX_FILE_BYTES) {
				throw new Exception('파일이 너무 큽니다. (최대 ' . round(MAX_FILE_BYTES / 1048576) . 'MB)');
			}
			ensure_dir(upload_dir());
			$dest = upload_dir() . '/' . $name;
			$base = pathinfo($name, PATHINFO_FILENAME);
			$e2   = pathinfo($name, PATHINFO_EXTENSION);
			$i = 2;
			while (is_file($dest)) {
				$name = $base . '_' . $i . ($e2 !== '' ? '.' . $e2 : '');
				$dest = upload_dir() . '/' . $name;
				$i++;
			}
			if (@file_put_contents($dest, $bin) === false) {
				throw new Exception('파일을 저장할 수 없습니다. files 폴더 권한을 확인하세요.');
			}
			send_json(array('ok' => true, 'name' => $name, 'path' => 'files/' . $name, 'size' => strlen($bin)));
			break;

		// ── 문의 ──────────────────────────────────────────
		case 'inquiries':
			send_json(array('ok' => true, 'items' => read_json_array(data_dir() . '/inquiries.json')));
			break;

		case 'inquiries-save':
			$items = bget('items', array());
			if (!is_array($items)) { $items = array(); }
			save_json(data_dir() . '/inquiries.json', $items);
			send_json(array('ok' => true));
			break;

		// ── 게시판 ────────────────────────────────────────
		case 'posts':
			send_json(array('ok' => true, 'items' => read_json_array(data_dir() . '/posts.json')));
			break;

		case 'posts-save':
			$items = bget('items', array());
			if (!is_array($items)) { $items = array(); }
			save_json(data_dir() . '/posts.json', $items);
			$log = '';
			if (bget('publish')) { $log = run_board(); }
			send_json(array('ok' => true, 'log' => $log));
			break;

		case 'board-build':
			send_json(array('ok' => true, 'log' => run_board()));
			break;

		// ── 백업 ──────────────────────────────────────────
		case 'backups':
			$items = array();
			$files = glob(backup_dir() . '/*');
			if (!is_array($files)) { $files = array(); }
			$rows = array();
			foreach ($files as $f) {
				if (!is_file($f)) { continue; }
				$rows[] = array('f' => $f, 't' => (int)@filemtime($f));
			}
			usort($rows, function ($a, $b) { return $b['t'] - $a['t']; });
			$rows = array_slice($rows, 0, 200);
			foreach ($rows as $r) {
				$items[] = array(
					'name' => basename($r['f']),
					'at'   => date('Y-m-d H:i:s', $r['t']),
					'kb'   => round(@filesize($r['f']) / 1024, 1),
				);
			}
			send_json(array('ok' => true, 'items' => $items));
			break;

		case 'restore':
			$name = basename((string)bget('name', ''));
			if ($name === '') { throw new Exception('백업 이름이 없습니다.'); }
			$src = backup_dir() . '/' . $name;
			if (!is_file($src)) { throw new Exception('백업 파일이 없습니다.'); }
			// 20260730-165757__about__overview.html  ->  about/overview.html
			$rel = preg_replace('~^\d{8}-\d{6}__~', '', $name);
			if ($rel === $name) { throw new Exception('이 백업은 자동으로 되돌릴 수 없습니다 : ' . $name); }
			if (strpos($rel, 'deleted__') === 0) { throw new Exception('삭제된 이미지는 FTP 로 직접 옮겨 주세요.'); }
			$rel  = str_replace('__', '/', $rel);
			$dest = resolve_safe($rel);
			backup_file($rel);
			if (!@copy($src, $dest)) { throw new Exception($rel . ' 을 되돌릴 수 없습니다. (권한 확인)'); }
			send_json(array('ok' => true, 'restored' => $rel, 'log' => run_compose()));
			break;

		// ── 반영 상태 (카페24에는 git 이 없다) ────────────
		case 'git-status':
			$n = 0;
			$files = glob(backup_dir() . '/*');
			if (is_array($files)) { $n = count($files); }
			$log = "카페24 서버에서는 저장하는 즉시 실제 사이트에 반영됩니다.\n"
				. "따로 「사이트 반영」을 누를 필요가 없습니다.\n\n"
				. "저장할 때마다 이전 파일이 백업되며, 지금까지 " . $n . "개가 쌓여 있습니다.\n"
				. "잘못 고쳤을 때는 아래 목록에서 되돌리면 됩니다.";
			send_json(array('ok' => true, 'log' => $log));
			break;

		case 'git-push':
			// 파일은 이미 라이브다. 대신 전체를 다시 빌드해 어긋남을 없앤다.
			$log = "카페24는 저장 즉시 반영되므로 따로 올릴 것이 없습니다.\n"
				. "혹시 어긋난 페이지가 없도록 전체를 다시 생성했습니다.\n\n"
				. run_compose() . "\n" . run_board();
			send_json(array('ok' => true, 'log' => $log));
			break;

		default:
			fail('없는 API : ' . $route, 404);
	}
} catch (Exception $e) {
	fail($e->getMessage(), 400);
} catch (Throwable $e) {
	fail('서버 오류 : ' . $e->getMessage(), 500);
}
