<?php
/**
 * 공지사항 / 자료실 정적 페이지 생성기 — _admin/board.ps1 의 PHP 이식본
 *
 *  입력 : data/posts.json  (관리자에서 저장)
 *  출력 : news/notice.html, news/archive.html, news/view-<id>.html, news/index.html
 *
 * 헤더/푸터는 compose 와 같이 index.html 에서 가져온다.
 */

/** .NET HttpUtility.HtmlEncode 와 결과를 맞춘다. (PHP 는 ' 를 &#039; 로, .NET 은 &#39; 로 쓴다) */
function b_enc($s) {
	$out = htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');
	return str_replace('&#039;', '&#39;', $out);
}

function b_boards() {
	return array(
		array('key' => 'notice',  'name' => '공지사항', 'en' => 'Notice',  'file' => 'notice.html',  'desc' => '대건엠에스의 소식과 안내 사항을 전해드립니다.'),
		array('key' => 'archive', 'name' => '자료실',   'en' => 'Archive', 'file' => 'archive.html', 'desc' => '회사 소개서와 제품 자료를 내려받으실 수 있습니다.'),
	);
}

function b_convert_body($text) {
	if ($text === null || $text === '') { return '<p>내용이 없습니다.</p>'; }
	$t = b_enc($text);
	$t = str_replace("\r\n", "\n", $t);
	$t = preg_replace('~\*\*(.+?)\*\*~', '<strong>$1</strong>', $t);
	$t = preg_replace('~(https?://[^\s]+)~', '<a href="$1" target="_blank" rel="noopener">$1</a>', $t);
	$blocks = preg_split("~\n[ \t]*\n~", $t);
	$out = array();
	foreach ($blocks as $b) {
		$b = trim($b);
		if ($b !== '') { $out[] = '<p>' . str_replace("\n", '<br>', $b) . '</p>'; }
	}
	return implode("\n", $out);
}

function b_summary($text) {
	if ($text === null || $text === '') { return ''; }
	$s = str_replace('**', '', (string)$text);
	$s = preg_replace('~\s+~u', ' ', $s);
	$s = trim($s);
	if (u_len($s) > 90) { $s = u_cut($s, 90) . '…'; }
	return b_enc($s);
}

function b_date($d) {
	if ($d === null || $d === '') { return ''; }
	return str_replace('-', '.', (string)$d);
}

function b_size($n) {
	$n = (int)$n;
	if (!$n) { return ''; }
	if ($n >= 1048576) { return number_format($n / 1048576, 1) . 'MB'; }
	return number_format(max(1, $n / 1024), 0) . 'KB';
}

/** 페이지 셸 */
function b_page($header, $footer, $title, $desc, $lnbOn, $bodyHtml, $visualText, $rel) {
	if ($visualText === null || $visualText === '') { $visualText = $desc; }
	$titleFull = $title . ' | 대건엠에스 DAEKUN MS';
	$url = SITE_URL . '/' . $rel;

	$lnbRows = array();
	$crumb = '';
	foreach (b_boards() as $b) {
		$on = ($b['key'] === $lnbOn) ? ' class="on"' : '';
		$lnbRows[] = "\t\t\t\t\t" . '<li' . $on . '><a href="../news/' . $b['file'] . '">' . $b['name'] . '</a></li>';
		if ($b['key'] === $lnbOn) { $crumb = $b['name']; }
	}
	$lnb = implode("\n", $lnbRows);

	return '<!doctype html>' . "\n"
		. '<html lang="ko">' . "\n"
		. '<head>' . "\n"
		. '<meta charset="utf-8">' . "\n"
		. '<title>' . $titleFull . '</title>' . "\n"
		. '<meta name="viewport" content="width=device-width, initial-scale=1">' . "\n"
		. '<meta name="format-detection" content="telephone=no">' . "\n"
		. '<meta name="description" content="' . $desc . '">' . "\n"
		. '<meta property="og:type" content="website">' . "\n"
		. '<meta property="og:title" content="' . $titleFull . '">' . "\n"
		. '<meta property="og:description" content="' . $desc . '">' . "\n"
		. '<meta property="og:image" content="' . SITE_URL . '/images/common/logo_navy.png">' . "\n"
		. '<meta property="og:url" content="' . $url . '">' . "\n"
		. '<meta name="theme-color" content="#131C3B">' . "\n"
		. '<link rel="canonical" href="' . $url . '">' . "\n"
		. '<link rel="stylesheet" href="../css/base.css">' . "\n"
		. '<link rel="stylesheet" href="../css/layout.css">' . "\n"
		. '<link rel="stylesheet" href="../css/common.css">' . "\n"
		. '<link rel="stylesheet" href="../css/main.css">' . "\n"
		. '<link rel="stylesheet" href="../css/sub.css">' . "\n"
		. '<link rel="stylesheet" href="../css/board.css">' . "\n"
		. '<link rel="stylesheet" href="../css/responsive.css">' . "\n"
		. '<script>document.documentElement.classList.add(\'js-scroll\');</script>' . "\n"
		. '</head>' . "\n"
		. '<body data-menu="news">' . "\n"
		. '<div class="skip-nav"><a href="#content">본문 바로가기</a></div>' . "\n"
		. "\n"
		. '<div id="wrap" class="sub-wrap">' . "\n"
		. "\n"
		. $header . "\n"
		. "\n"
		. "\t" . '<!-- SUB VISUAL -->' . "\n"
		. "\t" . '<section id="subVisual">' . "\n"
		. "\t\t" . '<h2 class="blind">' . b_enc($title) . '</h2>' . "\n"
		. "\t\t" . '<!-- 이미지 슬롯 : SUB 비주얼 · 2560×1040 · 사무·문서 컷 · 딥네이비 오버레이 72% --><div class="sub-visual-img img-slot has-img"><img src="../images/content/sub_etc.jpg" alt="대건엠에스 소식" loading="lazy"></div>' . "\n"
		. "\t\t" . '<div class="sub-visual-txt-con">' . "\n"
		. "\t\t\t" . '<div class="area">' . "\n"
		. "\t\t\t\t" . '<p class="sub-visual-tit font-en">NEWS <b>ROOM</b></p>' . "\n"
		. "\t\t\t\t" . '<p class="sub-visual-txt">' . b_enc($visualText) . '</p>' . "\n"
		. "\t\t\t" . '</div>' . "\n"
		. "\t\t" . '</div>' . "\n"
		. "\t\t" . '<div class="sub-lnb">' . "\n"
		. "\t\t\t" . '<div class="sub-lnb-inner">' . "\n"
		. "\t\t\t\t" . '<ul class="lnb-list">' . "\n"
		. $lnb . "\n"
		. "\t\t\t\t" . '</ul>' . "\n"
		. "\t\t\t\t" . '<ul class="breadcrumb">' . "\n"
		. "\t\t\t\t\t" . '<li><a class="home font-en" href="../index.html">HOME</a></li>' . "\n"
		. "\t\t\t\t\t" . '<li class="font-en">News</li>' . "\n"
		. "\t\t\t\t\t" . '<li>' . b_enc($crumb) . '</li>' . "\n"
		. "\t\t\t\t" . '</ul>' . "\n"
		. "\t\t\t" . '</div>' . "\n"
		. "\t\t" . '</div>' . "\n"
		. "\t" . '</section>' . "\n"
		. "\n"
		. "\t" . '<div id="content">' . "\n"
		. $bodyHtml . "\n"
		. "\t" . '</div>' . "\n"
		. "\n"
		. $footer . "\n"
		. "\n"
		. "\t" . '<button type="button" class="go-top-btn" aria-label="맨 위로 이동"></button>' . "\n"
		. '</div>' . "\n"
		. "\n"
		. '<script src="../js/main.js"></script>' . "\n"
		. '<script src="../js/sub.js"></script>' . "\n"
		. '</body>' . "\n"
		. '</html>';
}

function b_save($rel, $html) {
	$dest = SITE_ROOT . '/' . $rel;
	if (!ensure_dir(dirname($dest))) { throw new Exception('폴더를 만들 수 없습니다 : ' . dirname($dest)); }
	$html = str_replace("\r\n", "\n", $html);
	if (@file_put_contents($dest, $html) === false) {
		throw new Exception($rel . ' 을 저장할 수 없습니다. (폴더 권한 확인)');
	}
}

/**
 * @return string 실행 로그
 */
function run_board() {
	$root = SITE_ROOT;

	$indexPath = $root . '/index.html';
	if (!is_file($indexPath)) { return '(index.html 이 없습니다)'; }
	$index = read_text($indexPath);
	$header = compose_add_up_path(compose_get_block($index, '<!-- #HEADER#', '<!-- #/HEADER# -->'));
	$footer = compose_add_up_path(compose_get_block($index, '<!-- #FOOTER#', '<!-- #/FOOTER# -->'));

	$posts = read_json_array(data_dir() . '/posts.json');
	$live = array();
	foreach ($posts as $p) {
		if (!is_array($p)) { continue; }
		if (isset($p['published']) && $p['published'] === false) { continue; }
		$live[] = $p;
	}

	// 오래된 상세 페이지 정리
	$newsDir = $root . '/news';
	if (is_dir($newsDir)) {
		foreach (glob($newsDir . '/view-*.html') as $old) { @unlink($old); }
	}

	$made = 0;
	foreach (b_boards() as $b) {
		$items = array();
		foreach ($live as $i => $p) {
			$bk = isset($p['board']) ? $p['board'] : '';
			if ($bk === $b['key']) { $items[] = array('i' => $i, 'p' => $p); }
		}
		// 고정글 먼저, 그다음 날짜 내림차순. 같으면 원래 순서를 유지한다. (PHP 7.4 는 정렬이 불안정하다)
		usort($items, function ($x, $y) {
			$px = !empty($x['p']['pinned']) ? 0 : 1;
			$py = !empty($y['p']['pinned']) ? 0 : 1;
			if ($px !== $py) { return $px - $py; }
			$dx = isset($x['p']['date']) ? (string)$x['p']['date'] : '';
			$dy = isset($y['p']['date']) ? (string)$y['p']['date'] : '';
			$c = strcmp($dy, $dx);
			if ($c !== 0) { return $c; }
			return $x['i'] - $y['i'];
		});
		$list = array();
		foreach ($items as $it) { $list[] = $it['p']; }

		// ---- 목록 ----
		if (count($list) === 0) {
			$listHtml = "\t\t\t\t\t" . '<div class="board-empty"><p>등록된 글이 없습니다.</p></div>';
		} else {
			$rows = array();
			foreach ($list as $p) {
				$badge = !empty($p['pinned']) ? '<span class="bl-badge">공지</span>' : '';
				$fc = (isset($p['files']) && is_array($p['files'])) ? count($p['files']) : 0;
				$fileTag = $fc > 0 ? '<span class="bl-file">첨부 ' . $fc . '</span>' : '';
				$rows[] = "\t\t\t\t\t\t" . '<li>' . "\n"
					. "\t\t\t\t\t\t\t" . '<a href="../news/view-' . $p['id'] . '.html">' . "\n"
					. "\t\t\t\t\t\t\t\t" . '<div class="bl-txt">' . "\n"
					. "\t\t\t\t\t\t\t\t\t" . '<strong class="bl-tit">' . $badge . b_enc($p['title']) . '</strong>' . "\n"
					. "\t\t\t\t\t\t\t\t\t" . '<p class="bl-sum">' . b_summary(isset($p['content']) ? $p['content'] : '') . '</p>' . "\n"
					. "\t\t\t\t\t\t\t\t" . '</div>' . "\n"
					. "\t\t\t\t\t\t\t\t" . '<div class="bl-side">' . "\n"
					. "\t\t\t\t\t\t\t\t\t" . $fileTag . "\n"
					. "\t\t\t\t\t\t\t\t\t" . '<span class="bl-date font-en">' . b_date(isset($p['date']) ? $p['date'] : '') . '</span>' . "\n"
					. "\t\t\t\t\t\t\t\t" . '</div>' . "\n"
					. "\t\t\t\t\t\t\t" . '</a>' . "\n"
					. "\t\t\t\t\t\t" . '</li>';
			}
			$listHtml = "\t\t\t\t\t" . '<ul class="board-list">' . "\n"
				. implode("\n", $rows) . "\n"
				. "\t\t\t\t\t" . '</ul>';
		}

		$body = "\t\t" . '<section class="cont-sec">' . "\n"
			. "\t\t\t" . '<div class="area area-narrow">' . "\n"
			. "\t\t\t\t" . '<div class="cont-head" data-scroll="fade-up">' . "\n"
			. "\t\t\t\t\t" . '<span class="sec-sub-tit">' . $b['en'] . '</span>' . "\n"
			. "\t\t\t\t\t" . '<h3 class="sec-tit">' . $b['name'] . '</h3>' . "\n"
			. "\t\t\t\t" . '</div>' . "\n"
			. "\t\t\t\t" . '<div data-scroll="fade-up">' . "\n"
			. $listHtml . "\n"
			. "\t\t\t\t" . '</div>' . "\n"
			. "\t\t\t" . '</div>' . "\n"
			. "\t\t" . '</section>';

		b_save('news/' . $b['file'], b_page($header, $footer, $b['name'], $b['desc'], $b['key'], $body, null, 'news/' . $b['file']));
		$made++;

		// ---- 상세 ----
		$n = count($list);
		for ($i = 0; $i < $n; $i++) {
			$p    = $list[$i];
			$prev = $i > 0 ? $list[$i - 1] : null;
			$next = $i < $n - 1 ? $list[$i + 1] : null;

			$fileHtml = '';
			if (isset($p['files']) && is_array($p['files']) && count($p['files']) > 0) {
				$fr = array();
				foreach ($p['files'] as $f) {
					$fr[] = "\t\t\t\t\t\t\t" . '<li><a href="../' . $f['path'] . '" download>' . b_enc($f['name'])
						. '<span class="fsize font-en">' . b_size(isset($f['size']) ? $f['size'] : 0) . '</span></a></li>';
				}
				$fileHtml = "\t\t\t\t\t" . '<div class="bv-file">' . "\n"
					. "\t\t\t\t\t\t" . '<span class="bv-file-tit">첨부파일</span>' . "\n"
					. "\t\t\t\t\t\t" . '<ul>' . "\n"
					. implode("\n", $fr) . "\n"
					. "\t\t\t\t\t\t" . '</ul>' . "\n"
					. "\t\t\t\t\t" . '</div>';
			}

			$prevHtml = $prev
				? '<a href="../news/view-' . $prev['id'] . '.html">' . b_enc($prev['title']) . '</a>'
				: '<span class="none">이전 글이 없습니다.</span>';
			$nextHtml = $next
				? '<a href="../news/view-' . $next['id'] . '.html">' . b_enc($next['title']) . '</a>'
				: '<span class="none">다음 글이 없습니다.</span>';

			$navHtml = "\t\t\t\t\t" . '<ul class="bv-nav">' . "\n"
				. "\t\t\t\t\t\t" . '<li class="prev">' . "\n"
				. "\t\t\t\t\t\t\t" . '<span class="lb">이전 글</span>' . "\n"
				. "\t\t\t\t\t\t\t" . $prevHtml . "\n"
				. "\t\t\t\t\t\t" . '</li>' . "\n"
				. "\t\t\t\t\t\t" . '<li class="next">' . "\n"
				. "\t\t\t\t\t\t\t" . '<span class="lb">다음 글</span>' . "\n"
				. "\t\t\t\t\t\t\t" . $nextHtml . "\n"
				. "\t\t\t\t\t\t" . '</li>' . "\n"
				. "\t\t\t\t\t" . '</ul>';

			$body = "\t\t" . '<section class="cont-sec">' . "\n"
				. "\t\t\t" . '<div class="area area-narrow">' . "\n"
				. "\t\t\t\t" . '<div class="board-view" data-scroll="fade-up">' . "\n"
				. "\t\t\t\t\t" . '<div class="bv-head">' . "\n"
				. "\t\t\t\t\t\t" . '<h3 class="bv-tit">' . b_enc($p['title']) . '</h3>' . "\n"
				. "\t\t\t\t\t\t" . '<div class="bv-meta">' . "\n"
				. "\t\t\t\t\t\t\t" . '<span>' . $b['name'] . '</span>' . "\n"
				. "\t\t\t\t\t\t\t" . '<span class="font-en">' . b_date(isset($p['date']) ? $p['date'] : '') . '</span>' . "\n"
				. "\t\t\t\t\t\t" . '</div>' . "\n"
				. "\t\t\t\t\t" . '</div>' . "\n"
				. "\t\t\t\t\t" . '<div class="bv-body">' . "\n"
				. b_convert_body(isset($p['content']) ? $p['content'] : '') . "\n"
				. "\t\t\t\t\t" . '</div>' . "\n"
				. $fileHtml . "\n"
				. $navHtml . "\n"
				. "\t\t\t\t\t" . '<div class="bv-btn">' . "\n"
				. "\t\t\t\t\t\t" . '<a href="../news/' . $b['file'] . '" class="cm-btn">' . "\n"
				. "\t\t\t\t\t\t\t" . '<span class="txt">목록으로</span>' . "\n"
				. "\t\t\t\t\t\t\t" . '<span class="icon"></span>' . "\n"
				. "\t\t\t\t\t\t\t" . '<span class="hover-icon"></span>' . "\n"
				. "\t\t\t\t\t\t" . '</a>' . "\n"
				. "\t\t\t\t\t" . '</div>' . "\n"
				. "\t\t\t\t" . '</div>' . "\n"
				. "\t\t\t" . '</div>' . "\n"
				. "\t\t" . '</section>';

			$rel = 'news/view-' . $p['id'] . '.html';
			b_save($rel, b_page($header, $footer, $p['title'], b_summary(isset($p['content']) ? $p['content'] : ''), $b['key'], $body, $b['desc'], $rel));
			$made++;
		}
	}

	// 기본 진입 : news/index.html 은 공지사항으로 보낸다
	b_save('news/index.html',
		'<!doctype html>' . "\n"
		. '<html lang="ko">' . "\n"
		. '<head>' . "\n"
		. '<meta charset="utf-8">' . "\n"
		. '<meta http-equiv="refresh" content="0; url=notice.html">' . "\n"
		. '<title>News | 대건엠에스 DAEKUN MS</title>' . "\n"
		. '<link rel="canonical" href="notice.html">' . "\n"
		. '</head>' . "\n"
		. '<body><p><a href="notice.html">공지사항으로 이동</a></p></body>' . "\n"
		. '</html>');

	return '=== board : ' . $made . ' pages ===' . "\n";
}
