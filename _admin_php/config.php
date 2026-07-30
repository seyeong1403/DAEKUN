<?php
/**
 * 대건엠에스 홈페이지 관리자 — 설정
 * ---------------------------------------------------------------
 * 카페24(또는 PHP 7.4 이상) 서버용.
 *
 * 처음 설치할 때 아래 두 곳만 고치면 된다.
 *   1) ADMIN_USER  — 로그인 아이디
 *   2) ADMIN_PASS_HASH — 로그인 비밀번호 (해시)
 *
 * 비밀번호 해시 만드는 법
 *   서버에서 _admin/tool-hash.php 를 브라우저로 한 번 열면
 *   원하는 비밀번호의 해시를 만들어 준다. 만든 뒤 그 파일은 지운다.
 */

// ── 로그인 ──────────────────────────────────────────────────
define('ADMIN_USER', 'admin');

// 아래는 비밀번호  DaekunMS!2026  의 해시다. 설치 후 반드시 바꿀 것.
define('ADMIN_PASS_HASH', '$2y$12$FQkbr1OMK9/NgH87bvsRnenMY06lY6E2OOr4cgdHzUgOgf8yWG/E2');

// 로그인 상태 유지 시간 (초). 기본 4시간.
define('SESSION_MAX_AGE', 4 * 60 * 60);

// ── 사이트 위치 ────────────────────────────────────────────
// 이 폴더(_admin)의 부모가 사이트 루트다. 폴더 이름을 바꿔도 그대로 동작한다.
define('SITE_ROOT', dirname(__DIR__));

// ── 사이트 주소 (canonical · og:url · sitemap 에 쓰인다) ────
define('SITE_URL', 'https://daekunms.co.kr');

// ── 업로드 제한 ────────────────────────────────────────────
define('MAX_IMAGE_BYTES', 10 * 1024 * 1024);   // 이미지 10MB
define('MAX_FILE_BYTES', 20 * 1024 * 1024);    // 첨부 20MB

// ── 문의 알림 메일 (비우면 보내지 않는다) ──────────────────
define('INQUIRY_MAIL_TO', '');
