<?php
/**
 * 서브 페이지 생성기 — _build/compose.ps1 의 PHP 이식본
 *
 *  - 헤더/푸터 원본 : index.html 의 <!-- #HEADER# --> ~ <!-- #/HEADER# -->,
 *                     <!-- #FOOTER# --> ~ <!-- #/FOOTER# -->
 *  - 본문 조각      : _build/pages/*.html  (맨 위 메타 주석 + 본문)
 *  - 결과           : 메타의 @out 경로에 완성된 HTML 작성
 *
 * ※ 결과물이 PowerShell 판과 한 글자도 다르지 않아야 한다.
 *    (다르면 git 에서 전 페이지가 바뀐 것으로 잡힌다)
 */

function compose_get_block($text, $openMark, $closeMark) {
	$s = strpos($text, $openMark);
	$e = strpos($text, $closeMark);
	if ($s === false || $e === false) {
		throw new Exception('마커를 찾을 수 없음: ' . $openMark);
	}
	return substr($text, $s, $e - $s + strlen($closeMark));
}

/** 한 단계 아래 폴더용으로 상대 경로에 ../ 를 붙인다. */
function compose_add_up_path($block) {
	// 구분자로 ~ 를 쓴다. # 를 쓰면 패턴 안의 # 와 충돌해 조용히 깨진다.
	return preg_replace(
		'~(href|src)="(?!#|https?:|mailto:|tel:|//|\.\./|/)([^"]*)"~',
		'$1="../$2"',
		$block
	);
}

/**
 * @return string 실행 로그 (관리자 화면에 그대로 보여준다)
 */
function run_compose() {
	$root = SITE_ROOT;
	$log  = '';

	$indexPath = $root . '/index.html';
	if (!is_file($indexPath)) { return '(index.html 이 없습니다)'; }
	$index = read_text($indexPath);

	$header = compose_get_block($index, '<!-- #HEADER#', '<!-- #/HEADER# -->');
	$footer = compose_get_block($index, '<!-- #FOOTER#', '<!-- #/FOOTER# -->');
	$headerSub = compose_add_up_path($header);
	$footerSub = compose_add_up_path($footer);

	$pagesDir = $root . '/_build/pages';
	if (!is_dir($pagesDir)) { return '(_build/pages 폴더가 없습니다)'; }
	$fragments = glob($pagesDir . '/*.html');
	if (!is_array($fragments)) { $fragments = array(); }
	sort($fragments);

	$made = 0;
	foreach ($fragments as $path) {
		$raw   = read_text($path);
		$lines = preg_split("/\r?\n/", $raw);
		$meta  = array();
		$bodyStart = 0;

		for ($i = 0; $i < count($lines); $i++) {
			if (preg_match('/^\s*<!--@(\w+)\s+(.*?)-->\s*$/', $lines[$i], $m)) {
				$meta[$m[1]] = trim($m[2]);
				$bodyStart = $i + 1;
			} elseif (trim($lines[$i]) !== '') {
				break;
			}
		}
		foreach (array('title', 'desc', 'menu', 'out') as $k) {
			if (!isset($meta[$k])) {
				throw new Exception(basename($path) . ' : @' . $k . ' 메타가 없음');
			}
		}
		$body = trim(implode("\n", array_slice($lines, $bodyStart)));

		$titleFull = $meta['title'] . ' | 대건엠에스 DAEKUN MS';
		$url       = SITE_URL . '/' . $meta['out'];

		$page = '<!doctype html>' . "\n"
			. '<html lang="ko">' . "\n"
			. '<head>' . "\n"
			. '<meta charset="utf-8">' . "\n"
			. '<title>' . $titleFull . '</title>' . "\n"
			. '<meta name="viewport" content="width=device-width, initial-scale=1">' . "\n"
			. '<meta name="format-detection" content="telephone=no">' . "\n"
			. '<meta name="description" content="' . $meta['desc'] . '">' . "\n"
			. '<meta property="og:type" content="website">' . "\n"
			. '<meta property="og:title" content="' . $titleFull . '">' . "\n"
			. '<meta property="og:description" content="' . $meta['desc'] . '">' . "\n"
			. '<meta property="og:image" content="' . SITE_URL . '/images/common/logo_navy.png">' . "\n"
			. '<meta property="og:url" content="' . $url . '">' . "\n"
			. '<meta name="theme-color" content="#131C3B">' . "\n"
			. '<link rel="canonical" href="' . $url . '">' . "\n"
			. '<link rel="stylesheet" href="../css/base.css">' . "\n"
			. '<link rel="stylesheet" href="../css/layout.css">' . "\n"
			. '<link rel="stylesheet" href="../css/common.css">' . "\n"
			. '<link rel="stylesheet" href="../css/main.css">' . "\n"
			. '<link rel="stylesheet" href="../css/sub.css">' . "\n"
			. '<link rel="stylesheet" href="../css/responsive.css">' . "\n"
			. '<script>document.documentElement.classList.add(\'js-scroll\');</script>' . "\n"
			. '</head>' . "\n"
			. '<body data-menu="' . $meta['menu'] . '">' . "\n"
			. '<div class="skip-nav"><a href="#content">본문 바로가기</a></div>' . "\n"
			. "\n"
			. '<div id="wrap" class="sub-wrap">' . "\n"
			. "\n"
			. $headerSub . "\n"
			. "\n"
			. $body . "\n"
			. "\n"
			. $footerSub . "\n"
			. "\n"
			. '	<button type="button" class="go-top-btn" aria-label="맨 위로 이동"></button>' . "\n"
			. '</div>' . "\n"
			. "\n"
			. '<script src="../js/main.js"></script>' . "\n"
			. '<script src="../js/sub.js"></script>' . "\n"
			. '</body>' . "\n"
			// PowerShell here-string 은 끝에 개행을 남기지 않는다. 여기도 붙이지 않는다.
			. '</html>';

		// 전체를 LF 로 맞춘다. index.html 이 CRLF 면 헤더·푸터에 CRLF 가 섞여 들어온다.
		$page = str_replace("\r\n", "\n", $page);

		$dest    = $root . '/' . $meta['out'];
		$destDir = dirname($dest);
		if (!ensure_dir($destDir)) { throw new Exception('폴더를 만들 수 없습니다 : ' . $destDir); }
		if (@file_put_contents($dest, $page) === false) {
			throw new Exception($meta['out'] . ' 을 저장할 수 없습니다. (폴더 권한 확인)');
		}
		$made++;
		$log .= sprintf("OK  %-34s <- %s\n", $meta['out'], basename($path));
	}
	$log .= '=== ' . $made . ' pages composed ===' . "\n";
	return $log;
}
