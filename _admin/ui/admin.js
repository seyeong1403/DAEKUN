/* =============================================================
   대건엠에스 홈페이지 관리자
   - 원본 HTML을 최소한으로만 건드리도록 설계했다.
     (엔티티는 토큰으로 잠가두고 파싱 → 편집 → 되돌린다)
   ============================================================= */
(function () {
'use strict';

/* -------------------------------------------------- 잘못 연 경우 안내
   index.html 을 더블클릭해서 열면(file://) 서버와 통신할 수 없다.
   반드시 「관리자 실행.cmd」로 띄운 뒤 http://localhost:8880/admin/ 으로 들어와야 한다. */
if (location.protocol === 'file:') {
	document.body.innerHTML =
		'<div style="max-width:620px;margin:14vh auto;padding:38px 40px;font-family:\'Pretendard\',\'Noto Sans KR\',sans-serif;' +
		'background:#fff;border:1px solid #E3E6EC;border-radius:12px;line-height:1.75;word-break:keep-all">' +
		'<h1 style="font-size:22px;font-weight:700;margin-bottom:14px;color:#131C3B">이 방법으로는 열 수 없습니다</h1>' +
		'<p style="color:#5A6172;font-size:15px">지금 파일을 직접 열어서(더블클릭) 들어오셨습니다. 이렇게 열면 관리자가 동작하지 않습니다.</p>' +
		'<p style="color:#5A6172;font-size:15px;margin-top:14px"><b style="color:#1A1E28">_admin</b> 폴더의 ' +
		'<b style="color:#1A1E28">「관리자 실행.cmd」</b> 를 더블클릭해 주세요. 검은 창이 뜨면서 관리자가 자동으로 열립니다.</p>' +
		'<p style="margin-top:22px;padding:14px 16px;background:#F5F6F8;border-radius:8px;font-size:14px;color:#5A6172">' +
		'검은 창을 이미 띄우셨다면 브라우저 주소창에 이 주소를 직접 입력하세요<br>' +
		'<b style="color:#3E6EAF;font-size:15px">http://localhost:8880/admin/</b></p></div>';
	return;
}

/* -------------------------------------------------- 공통 */
const $ = (s, p) => (p || document).querySelector(s);
const $$ = (s, p) => Array.prototype.slice.call((p || document).querySelectorAll(s));

async function api(route, body) {
	const opt = body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {};
	let res;
	try {
		res = await fetch('/api/' + route, opt);
	} catch (e) {
		throw new Error('관리자 서버가 꺼져 있습니다. _admin 폴더의 「관리자 실행.cmd」를 실행한 뒤 새로고침해 주세요.');
	}
	let json;
	try { json = await res.json(); } catch (e) { throw new Error('서버 응답을 읽을 수 없습니다.'); }
	if (!json.ok) throw new Error(json.error || '알 수 없는 오류');
	return json;
}

let toastTimer;
function toast(msg, isErr) {
	const el = $('#toast');
	el.textContent = msg;
	el.className = 'toast' + (isErr ? ' err' : '');
	el.hidden = false;
	clearTimeout(toastTimer);
	toastTimer = setTimeout(() => { el.hidden = true; }, isErr ? 5200 : 2600);
}
function busy(on, msg) {
	$('#busyMsg').textContent = msg || '처리 중…';
	$('#busy').hidden = !on;
}
function fail(e) { console.error(e); toast(e.message || String(e), true); busy(false); }

function esc(s) {
	return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function confirmBox(title, msg, okLabel) {
	return new Promise(resolve => {
		$('#modalBox').innerHTML =
			'<h3>' + esc(title) + '</h3><p style="color:var(--txt-2);font-size:14.5px;line-height:1.7">' + msg + '</p>' +
			'<div class="modal-btns"><button type="button" class="btn ghost" data-r="0">취소</button>' +
			'<button type="button" class="btn primary" data-r="1">' + esc(okLabel || '확인') + '</button></div>';
		$('#modal').hidden = false;
		$('#modalBox').onclick = e => {
			const b = e.target.closest('[data-r]');
			if (!b) return;
			$('#modal').hidden = true;
			resolve(b.dataset.r === '1');
		};
	});
}
function fileToB64(file) {
	return new Promise((res, rej) => {
		const r = new FileReader();
		r.onload = () => res(String(r.result).split(',')[1]);
		r.onerror = rej;
		r.readAsDataURL(file);
	});
}
/* 조각 본문의 앞뒤 빈 줄만 걷어낸다. 첫 줄의 들여쓰기(탭)는 원본 그대로 남긴다. */
function trimBody(s) {
	return String(s).replace(/^[\r\n]+/, '').replace(/[ \t\r\n]+$/, '');
}

/* 브라우저는 novalidate 같은 값 없는 속성을 novalidate="" 로 바꿔 쓴다.
   원본에서 값 없이 쓰인 속성 이름을 모아 두었다가 저장할 때 원래 모양으로 되돌린다. */
function bareAttrNames(src) {
	const names = new Set();
	const tagRe = /<[a-zA-Z][^>]*>/g;
	let t;
	while ((t = tagRe.exec(src))) {
		const inner = t[0].replace(/^<[a-zA-Z][-a-zA-Z0-9]*/, '').replace(/\/?>$/, '');
		const attrRe = /\s([a-zA-Z_:][-a-zA-Z0-9_:.]*)(\s*=\s*("[^"]*"|'[^']*'|[^\s>]+))?/g;
		let a;
		while ((a = attrRe.exec(inner))) { if (!a[2]) names.add(a[1].toLowerCase()); }
	}
	return names;
}
/* 잠가 둔 엔티티를 실제 글자로 되돌린 순수 텍스트.
   미리보기(실제 페이지)의 텍스트와 대조하려면 이 형태여야 한다. */
const ENT_BOX = document.createElement('textarea');
function decodeEnt(s) { ENT_BOX.innerHTML = String(s); return ENT_BOX.value; }
function plainText(el, brAsSpace) {
	let s = '';
	Array.prototype.forEach.call(el.childNodes, n => {
		if (n.nodeType === 3) s += n.nodeValue;
		else if (n.nodeName === 'BR') s += brAsSpace ? ' ' : '';
		else if (n.nodeType === 1) s += plainText(n, brAsSpace);
	});
	return decodeEnt(untok(s)).replace(/\s+/g, ' ').trim();
}
function restoreBareAttrs(html, names) {
	names.forEach(n => {
		const safe = n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
		html = html.replace(new RegExp('\\s' + safe + '=""', 'g'), ' ' + n);
	});
	return html;
}
function today() {
	const d = new Date();
	return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
}

/* -------------------------------------------------- 엔티티 잠금 */
const T0 = '\uE000', T1 = '\uE001';
const tok = s => String(s).replace(/&(#?[0-9a-zA-Z]{1,10});/g, (m, g) => T0 + g + T1);
const untok = s => String(s).replace(/\uE000(#?[0-9a-zA-Z]{1,10})\uE001/g, (m, g) => '&' + g + ';');

/* -------------------------------------------------- 라우팅 */
let STATE = null;
const views = {};

/* raw 는 'content' 또는 'content/01-about-overview' 형태를 받는다 */
function go(raw) {
	const parts = String(raw).split('/');
	const name = parts[0], arg = parts[1];
	$$('.side-nav button').forEach(b => b.classList.toggle('on', b.dataset.view === name));
	$$('.view').forEach(v => { v.hidden = v.dataset.view !== name; });
	if (location.hash.slice(1) !== raw) location.hash = raw;
	if (views[name]) views[name](arg);
}
$$('.side-nav button').forEach(b => b.addEventListener('click', () => go(b.dataset.view)));
$$('[data-go]').forEach(b => b.addEventListener('click', () => go(b.dataset.go)));

/* ============================================================
   1. 대시보드
   ============================================================ */
async function loadState() {
	STATE = await api('state');
	const b = $('#inqBadge');
	b.hidden = !STATE.inqNew;
	b.textContent = STATE.inqNew;
	return STATE;
}

views.dash = async function () {
	try {
		const s = await loadState();
		$('#dashStats').innerHTML = [
			['홈페이지 페이지', s.pageCount, '개'],
			['등록된 이미지', s.imgCount, '장'],
			['전체 문의', s.inqTotal, '건'],
			['공지 · 자료실 글', s.postTotal, '개']
		].map(x => `<div class="stat"><p class="k">${x[0]}</p><p class="v">${x[1]}<small>${x[2]}</small></p></div>`).join('') +
			`<div class="stat${s.inqNew ? ' alert' : ''}"><p class="k">확인 안 한 문의</p><p class="v">${s.inqNew}<small>건</small></p></div>`;

		const inq = (await api('inquiries')).items || [];
		$('#dashInq').innerHTML = inq.length
			? inq.slice(0, 6).map(i => `<div class="row"><span class="d">${esc(String(i.at).slice(2, 10))}</span>
				<span class="c">${esc(i.company || '-')}</span>
				<span class="m">${esc(i.message || '')}</span>
				<span class="st ${i.status}">${stName(i.status)}</span></div>`).join('')
			: '<p class="empty-msg">아직 접수된 문의가 없습니다.</p>';

		const checks = [
			['검색엔진 색인 차단(noindex)을 해제했습니다. 검색에 노출됩니다.', true],
			['약관 · 개인정보처리방침의 [ 대괄호 ] 자리를 채워야 합니다.', false],
			['문의 폼이 실제 서버에 연결되어 있지 않습니다. (현재는 메일 안내로 대체)', false],
			['주소가 daekunms.co.kr 이 아니면 sitemap.xml · og:url 의 도메인을 바꿔야 합니다.', false]
		];
		$('#dashCheck').innerHTML = checks.map(c => `<li class="${c[1] ? 'ok' : ''}">${esc(c[0])}</li>`).join('');
	} catch (e) { fail(e); }
};

/* ============================================================
   2. 콘텐츠 수정
   ============================================================ */
const INLINE = ['B', 'STRONG', 'EM', 'I', 'U', 'SPAN', 'A', 'BR', 'SMALL', 'SUB', 'SUP', 'MARK', 'ABBR', 'WBR'];
const SKIP = ['SCRIPT', 'STYLE', 'SVG', 'IFRAME', 'NOSCRIPT', 'SELECT', 'OPTION'];

let ED = null; // 현재 편집 중인 페이지 상태

function buildPagePicker() {
	const groups = {};
	STATE.pages.forEach(p => { (groups[p.group] = groups[p.group] || []).push(p); });
	$('#pagePicker').innerHTML = Object.keys(groups).map(g =>
		`<div class="pp-group">${esc(g)}</div>` +
		groups[g].map(p => `<button type="button" data-id="${esc(p.id)}">${esc(p.title)}</button>`).join('')
	).join('');
	$('#pagePicker').onclick = e => {
		const b = e.target.closest('button[data-id]');
		if (b) openPage(b.dataset.id);
	};
}

views.content = async function (pageId) {
	try {
		if (!STATE) await loadState();
		if (!$('#pagePicker').children.length) buildPagePicker();
		if (pageId && (!ED || ED.page.id !== pageId)) openPage(pageId);
	} catch (e) { fail(e); }
};

async function openPage(id) {
	if (ED && ED.dirty && !(await confirmBox('저장하지 않은 수정이 있습니다', '저장하지 않고 다른 페이지로 이동할까요?', '이동'))) return;
	const page = STATE.pages.find(p => p.id === id);
	if (!page) return;
	busy(true, '페이지를 불러오는 중…');
	try {
		const r = await api('file?path=' + encodeURIComponent(page.source));
		const src = r.content;

		let head, inner, tail;
		if (page.kind === 'fragment') {
			const lines = src.split('\n');
			let i = 0;
			while (i < lines.length && (/^\s*<!--@\w+/.test(lines[i]) || !lines[i].trim())) i++;
			head = lines.slice(0, i).join('\n').replace(/\s+$/, '') + '\n\n';
			inner = lines.slice(i).join('\n');
			tail = '\n';
		} else {
			const m = src.match(/<body[^>]*>/i);
			const s = m.index + m[0].length;
			const e = src.lastIndexOf('</body>');
			head = src.slice(0, s);
			inner = src.slice(s, e);
			tail = src.slice(e);
		}

		const doc = new DOMParser().parseFromString('<!doctype html><html><body>' + tok(inner) + '</body></html>', 'text/html');
		ED = { page, head, tail, body: doc.body, bare: bareAttrNames(inner), fields: [], dirty: false };
		collectFields();
		renderFields();

		$$('#pagePicker button').forEach(b => b.classList.toggle('on', b.dataset.id === id));
		$('#edTitle').textContent = page.title;
		$('#edPath').textContent = page.source;
		$('#edSave').disabled = true;
		$('#edDirty').hidden = true;
		$('#edPrev').src = '/' + page.view + '?t=' + Date.now();
		applyPreviewWidth();
	} catch (e) { fail(e); } finally { busy(false); }
}

function collectFields() {
	const fields = ED.fields = [];
	const page = ED.page;

	/* --- 페이지 정보(제목/설명) --- */
	if (page.kind === 'fragment') {
		const t = ED.head.match(/<!--@title\s+(.*?)-->/);
		const d = ED.head.match(/<!--@desc\s+(.*?)-->/);
		if (t) fields.push(metaField('페이지 제목', t[1], 'title', '브라우저 탭과 검색 결과에 나오는 이름'));
		if (d) fields.push(metaField('검색용 설명', d[1], 'desc', '검색 결과에 표시되는 두세 줄 소개'));
	} else {
		const t = ED.head.match(/<title>([\s\S]*?)<\/title>/i);
		const d = ED.head.match(/<meta name="description" content="([\s\S]*?)">/i);
		if (t) fields.push(metaField('페이지 제목', t[1], 'htitle', '브라우저 탭과 검색 결과에 나오는 이름'));
		if (d) fields.push(metaField('검색용 설명', d[1], 'hdesc', '검색 결과에 표시되는 두세 줄 소개'));
	}

	/* --- 본문 --- */
	walk(ED.body);

	function walk(node) {
		Array.prototype.forEach.call(node.children, el => {
			if (SKIP.indexOf(el.tagName) >= 0) return;
			/* 자동으로 만들어지는 이동 장치는 건드릴 일이 없다 */
			if (el.matches && el.matches('.sub-lnb, .breadcrumb, .skip-nav, .go-top-btn')) return;
			if (el.tagName === 'IMG') { pushImg(el); return; }
			if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') { pushPlaceholder(el); return; }

			const kids = Array.prototype.slice.call(el.children);
			const leaf = kids.every(c => INLINE.indexOf(c.tagName) >= 0);
			const txt = plainText(el);

			if (leaf && txt) { pushText(el); return; }
			walk(el);
		});
	}

	function pushText(el) {
		/* <li><a href="…">회사 소개</a></li> 처럼 링크가 내용 전부이면
		   링크 태그가 아니라 그 안의 글자만 고치게 한다. */
		while (el.children.length === 1 && el.children[0].tagName === 'A'
			&& plainText(el) === plainText(el.children[0])) {
			el = el.children[0];
		}
		fields.push({
			type: 'html', el,
			group: groupOf(el),
			kind: kindOf(el),
			value: untok(el.innerHTML).trim(),
			text: plainText(el),
			apply(v) { el.innerHTML = tok(v); }
		});
	}
	function pushImg(el) {
		const alt = el.getAttribute('alt') || '';
		fields.push({
			type: 'alt', el,
			group: groupOf(el),
			kind: 'alt',
			label: '사진 설명 · ' + (el.getAttribute('src') || '').split('/').pop(),
			value: untok(alt),
			text: '',
			apply(v) { el.setAttribute('alt', tok(v)); }
		});
	}
	function pushPlaceholder(el) {
		const ph = el.getAttribute('placeholder');
		if (!ph) return;
		fields.push({
			type: 'ph', el,
			group: groupOf(el),
			kind: 'ph',
			label: '입력칸 안내문 · ' + (el.getAttribute('name') || el.id || ''),
			value: untok(ph),
			text: '',
			apply(v) { el.setAttribute('placeholder', tok(v)); }
		});
	}
}

function metaField(label, value, key, note) {
	return {
		type: 'meta', key, label, note,
		group: { key: '__meta', label: '페이지 정보 (검색 · 브라우저 탭)' },
		kind: 'tit',
		value: untok(value), text: '',
		apply(v) {
			const s = tok(v).replace(/-->/g, '--&gt;');
			if (key === 'title') ED.head = ED.head.replace(/(<!--@title\s+)([\s\S]*?)(-->)/, (m, a, b, c) => a + s + c);
			if (key === 'desc') ED.head = ED.head.replace(/(<!--@desc\s+)([\s\S]*?)(-->)/, (m, a, b, c) => a + s + c);
			if (key === 'htitle') ED.head = ED.head.replace(/(<title>)([\s\S]*?)(<\/title>)/i, (m, a, b, c) => a + tok(v) + c);
			if (key === 'hdesc') ED.head = ED.head.replace(/(<meta name="description" content=")([\s\S]*?)(">)/i, (m, a, b, c) => a + tok(v).replace(/"/g, '&quot;') + c);
		}
	};
}

function kindOf(el) {
	if (el.classList.contains('blind')) return 'blind';
	if (/^H[1-6]$/.test(el.tagName) || el.classList.contains('sec-tit') || el.classList.contains('step-tit')) return 'tit';
	return '';
}

const GROUP_CACHE = new WeakMap();
function groupOf(el) {
	let n = el;
	while (n && n !== ED.body) {
		if (n.tagName === 'SECTION' || n.tagName === 'HEADER' || n.tagName === 'FOOTER') break;
		n = n.parentElement;
	}
	if (!n || n === ED.body) return { key: '__etc', label: '기타 영역' };
	if (GROUP_CACHE.has(n)) return GROUP_CACHE.get(n);

	let cm = '';
	let p = n.previousSibling;
	while (p && p.nodeType === 3 && !p.textContent.trim()) p = p.previousSibling;
	if (p && p.nodeType === 8) cm = p.textContent.replace(/[*#]/g, '').replace(/\s+/g, ' ').trim();

	const titEl = n.querySelector('.sec-tit, h2:not(.blind), h3:not(.blind), .sub-visual-tit, .panel-tit');
	let tit = titEl ? plainText(titEl, true) : '';
	if (tit.length > 30) tit = tit.slice(0, 30) + '…';

	let label = tit || cm || n.id || n.className || '섹션';
	if (n.tagName === 'HEADER') label = '상단 메뉴 (전체 페이지 공통)';
	else if (n.tagName === 'FOOTER') label = '하단 정보 (전체 페이지 공통)';
	else if (cm && tit) label = tit;
	else if (cm) label = cm;

	const g = { key: 'g' + (groupOf.n = (groupOf.n || 0) + 1), label, note: cm && cm !== label ? cm : '' };
	GROUP_CACHE.set(n, g);
	return g;
}

function renderFields() {
	const order = [];
	const map = new Map();
	ED.fields.forEach((f, i) => {
		f.i = i;
		if (!map.has(f.group.key)) { map.set(f.group.key, []); order.push(f.group); }
		map.get(f.group.key).push(f);
	});

	$('#edFields').innerHTML = order.map((g, gi) => {
		const list = map.get(g.key);
		return `<details class="fgroup" ${gi < 2 ? 'open' : ''}>
			<summary>${esc(g.label)}<em>${list.length}개 항목</em></summary>
			<div class="fgroup-body">${list.map(fieldHtml).join('')}</div>
		</details>`;
	}).join('') || '<p class="empty-msg">편집할 문구가 없습니다.</p>';

	$$('#edFields textarea').forEach(ta => {
		autoGrow(ta);
		ta.addEventListener('input', () => { autoGrow(ta); onEdit(ta); });
		ta.addEventListener('focus', () => {
			const f = ED.fields[+ta.dataset.i];
			if (f && f.text) highlightPreview(f.text);
		});
	});
	$('#edFields').addEventListener('click', e => {
		const j = e.target.closest('.jump');
		if (j) { const f = ED.fields[+j.dataset.i]; if (f && f.text) highlightPreview(f.text, true); }
	});
}

function fieldHtml(f) {
	const kindLabel = { tit: '제목', blind: '화면에 안 보임(읽기 지원용)', alt: '사진 설명', ph: '입력 안내' }[f.kind] || '';
	return `<div class="field ${f.kind}" data-i="${f.i}">
		<div class="field-head">
			${kindLabel ? `<span class="field-kind ${f.kind}">${esc(kindLabel)}</span>` : ''}
			${f.label ? `<span class="field-note">${esc(f.label)}</span>` : ''}
			${f.note ? `<span class="field-note">${esc(f.note)}</span>` : ''}
			${f.text ? `<button type="button" class="jump" data-i="${f.i}">미리보기에서 보기</button>` : ''}
		</div>
		<textarea data-i="${f.i}" rows="1">${esc(f.value)}</textarea>
	</div>`;
}

function autoGrow(ta) {
	ta.style.height = 'auto';
	ta.style.height = Math.min(ta.scrollHeight + 2, 400) + 'px';
}
function onEdit(ta) {
	const f = ED.fields[+ta.dataset.i];
	f.next = ta.value;
	const changed = ta.value !== f.value;
	ta.closest('.field').classList.toggle('changed', changed);
	ED.dirty = ED.fields.some(x => x.next != null && x.next !== x.value);
	$('#edSave').disabled = !ED.dirty;
	$('#edDirty').hidden = !ED.dirty;
}

/* --- 미리보기 연동 --- */
function previewDoc() {
	try { return $('#edPrev').contentDocument; } catch (e) { return null; }
}
function highlightPreview(text, scroll) {
	const d = previewDoc();
	if (!d || !d.body) return;
	if (!d.getElementById('__adminHl')) {
		const st = d.createElement('style');
		st.id = '__adminHl';
		st.textContent = '.__hl{outline:3px solid #3E6EAF !important;outline-offset:3px;background:rgba(62,110,175,.12) !important;transition:.2s}';
		d.head.appendChild(st);
	}
	$$('.__hl', d).forEach(e => e.classList.remove('__hl'));
	const all = d.querySelectorAll('h1,h2,h3,h4,h5,h6,p,li,td,th,dt,dd,strong,span,a,button,label,caption,figcaption');
	for (const e of all) {
		if (e.textContent.replace(/\s+/g, ' ').trim() === text) {
			e.classList.add('__hl');
			e.scrollIntoView({ block: 'center', behavior: scroll ? 'smooth' : 'auto' });
			return;
		}
	}
}
$('#edPrev').addEventListener('load', () => {
	const d = previewDoc();
	if (!d) return;
	d.addEventListener('click', e => {
		if (!ED) return;
		const t = e.target.textContent.replace(/\s+/g, ' ').trim();
		if (!t) return;
		const f = ED.fields.find(x => x.text === t);
		if (!f) return;
		e.preventDefault();
		const ta = $(`#edFields textarea[data-i="${f.i}"]`);
		if (!ta) return;
		const det = ta.closest('details');
		if (det) det.open = true;
		ta.scrollIntoView({ block: 'center', behavior: 'smooth' });
		ta.focus();
	}, true);
});

/* 미리보기는 실제 화면 폭(PC 1440 등)으로 띄운 뒤 칸에 맞게 축소해 보여준다.
   그래야 편집 화면이 좁아도 PC 에서 보이는 그대로를 확인할 수 있다. */
function applyPreviewWidth() {
	const b = $('.prev-btns button.on');
	if (!b) return;
	const w = +b.dataset.w;
	const stage = $('.prev-stage'), fr = $('#edPrev');
	const avail = stage.clientWidth - 2;
	const scale = Math.min(1, avail / w);
	fr.style.width = w + 'px';
	fr.style.height = (stage.clientHeight / scale) + 'px';
	fr.style.transform = 'scale(' + scale + ')';
	fr.style.marginLeft = Math.max(0, (avail - w * scale) / 2) + 'px';
}
$$('.prev-btns button').forEach(b => b.addEventListener('click', () => {
	$$('.prev-btns button').forEach(x => x.classList.remove('on'));
	b.classList.add('on');
	applyPreviewWidth();
}));
let prevResizeTimer;
window.addEventListener('resize', () => {
	clearTimeout(prevResizeTimer);
	prevResizeTimer = setTimeout(applyPreviewWidth, 150);
});

$('#edReload').addEventListener('click', async () => {
	if (!ED) return;
	if (ED.dirty && !(await confirmBox('되돌리기', '수정한 내용을 모두 버리고 저장된 상태로 되돌립니다.', '되돌리기'))) return;
	openPage(ED.page.id);
});

$('#edSave').addEventListener('click', async () => {
	if (!ED || !ED.dirty) return;
	busy(true, '저장하고 사이트에 반영하는 중…');
	try {
		ED.fields.forEach(f => { if (f.next != null && f.next !== f.value) f.apply(f.next); });
		const inner = restoreBareAttrs(untok(ED.body.innerHTML), ED.bare);
		const out = ED.page.kind === 'fragment'
			? ED.head + trimBody(inner) + ED.tail
			: ED.head + inner + ED.tail;
		await api('save', { path: ED.page.source, content: out, compose: true });
		toast('저장했습니다. 미리보기를 새로 불러옵니다.');
		const id = ED.page.id;
		ED.dirty = false;
		await openPage(id);
	} catch (e) { fail(e); } finally { busy(false); }
});

window.addEventListener('beforeunload', e => {
	if (ED && ED.dirty) { e.preventDefault(); e.returnValue = ''; }
});

/* ============================================================
   3. 이미지 관리
   ============================================================ */
let SLOTS = null, MEDIA = null;

views.media = async function () {
	if (SLOTS) return;
	try {
		busy(true, '이미지를 모으는 중…');
		if (!STATE) await loadState();
		MEDIA = await api('media');
		SLOTS = [];
		for (const p of STATE.pages) {
			const r = await api('file?path=' + encodeURIComponent(p.source));
			const doc = new DOMParser().parseFromString('<!doctype html><html><body>' + r.content + '</body></html>', 'text/html');
			doc.body.querySelectorAll('img').forEach((img, idx) => {
				/* 로고 등 공통 브랜드 자산은 여기서 다루지 않는다 (images/common) */
				if (/images\/common\//.test(img.getAttribute('src') || '')) return;
				if (img.closest('#header, #footer')) return;
				const holder = img.closest('.img-slot, .map-slot') || img.parentElement;
				let cm = '', n = holder.previousSibling;
				while (n && n.nodeType === 3 && !n.textContent.trim()) n = n.previousSibling;
				if (n && n.nodeType === 8) cm = n.textContent.trim();
				const spec = cm.replace(/^이미지\s*슬롯\s*[:：]\s*/, '');
				const src = img.getAttribute('src') || '';
				SLOTS.push({
					page: p, idx,
					label: (spec.split('·')[0] || '이미지').trim(),
					spec: spec.split('·').slice(1).join(' · ').trim(),
					file: src.split('/').pop(),
					url: '/' + src.replace(/^(\.\.\/)+/, ''),
					alt: img.getAttribute('alt') || ''
				});
			});
		}
		const sel = $('#mediaPage');
		sel.innerHTML = '<option value="">전체 페이지</option>' +
			STATE.pages.map(p => `<option value="${esc(p.id)}">${esc(p.group)} · ${esc(p.title)}</option>`).join('');
		sel.onchange = renderSlots;
		renderSlots();
		renderFiles();
	} catch (e) { fail(e); } finally { busy(false); }
};

function renderSlots() {
	const pid = $('#mediaPage').value;
	const list = SLOTS.filter(s => !pid || s.page.id === pid);
	$('#mediaCount').textContent = `이미지 슬롯 ${list.length}곳`;
	$('#slotGrid').innerHTML = list.map(s => {
		const i = SLOTS.indexOf(s);
		return `<div class="slot" data-i="${i}">
			<div class="slot-thumb">
				<img src="${esc(s.url)}" alt="" loading="lazy">
				<div class="drop-hint">클릭하거나 사진을<br>여기로 끌어다 놓으세요</div>
			</div>
			<div class="slot-body">
				<span class="slot-page">${esc(s.page.title)}</span>
				<p class="slot-label">${esc(s.label)}</p>
				${s.spec ? `<p class="slot-spec">${esc(s.spec)}</p>` : ''}
				<p class="slot-file">${esc(s.file)}</p>
				<div class="slot-alt">
					<label>사진 설명 (검색·접근성용)</label>
					<input type="text" value="${esc(s.alt)}" data-alt="${i}">
				</div>
			</div>
		</div>`;
	}).join('') || '<p class="empty-msg">이 페이지에는 이미지가 없습니다.</p>';

	$$('#slotGrid .slot').forEach(card => {
		const i = +card.dataset.i;
		const thumb = $('.slot-thumb', card);
		thumb.addEventListener('click', () => pickFile(i));
		['dragenter', 'dragover'].forEach(ev => card.addEventListener(ev, e => { e.preventDefault(); card.classList.add('drag'); }));
		['dragleave', 'drop'].forEach(ev => card.addEventListener(ev, e => { e.preventDefault(); card.classList.remove('drag'); }));
		card.addEventListener('drop', e => {
			const f = e.dataTransfer.files[0];
			if (f) replaceImage(i, f);
		});
		$('input[data-alt]', card).addEventListener('change', e => saveAlt(i, e.target.value));
	});
}

function pickFile(i) {
	const inp = document.createElement('input');
	inp.type = 'file';
	inp.accept = 'image/*';
	inp.onchange = () => { if (inp.files[0]) replaceImage(i, inp.files[0]); };
	inp.click();
}

async function replaceImage(i, file) {
	const s = SLOTS[i];
	if (!/^image\//.test(file.type)) return toast('이미지 파일만 올릴 수 있습니다.', true);
	busy(true, '사진을 올리는 중…');
	try {
		const up = await api('media-upload', {
			name: s.file.replace(/\.[^.]+$/, '') + file.name.match(/\.[^.]+$/)[0],
			folder: 'content', overwrite: true, data: await fileToB64(file)
		});
		await patchPage(s.page, doc => {
			const img = doc.body.querySelectorAll('img')[s.idx];
			if (!img) throw new Error('이미지 위치를 찾지 못했습니다.');
			img.setAttribute('src', (s.page.kind === 'fragment' ? '../' : '') + up.path);
		});
		s.file = up.path.split('/').pop();
		s.url = '/' + up.path + '?t=' + Date.now();
		toast(`사진을 바꿨습니다. (${up.w}×${up.h})`);
		renderSlots();
		MEDIA = await api('media');
		renderFiles();
	} catch (e) { fail(e); } finally { busy(false); }
}

async function saveAlt(i, val) {
	const s = SLOTS[i];
	if (val === s.alt) return;
	try {
		await patchPage(s.page, doc => {
			const img = doc.body.querySelectorAll('img')[s.idx];
			if (img) img.setAttribute('alt', tok(val));
		});
		s.alt = val;
		toast('사진 설명을 저장했습니다.');
	} catch (e) { fail(e); }
}

/* 페이지 소스를 열어 DOM 을 고친 뒤 그대로 되돌려 쓴다 */
async function patchPage(page, mutate) {
	const r = await api('file?path=' + encodeURIComponent(page.source));
	const src = r.content;
	let head, inner, tail;
	if (page.kind === 'fragment') {
		const lines = src.split('\n');
		let i = 0;
		while (i < lines.length && (/^\s*<!--@\w+/.test(lines[i]) || !lines[i].trim())) i++;
		head = lines.slice(0, i).join('\n').replace(/\s+$/, '') + '\n\n';
		inner = lines.slice(i).join('\n');
		tail = '\n';
	} else {
		const m = src.match(/<body[^>]*>/i);
		const s = m.index + m[0].length, e = src.lastIndexOf('</body>');
		head = src.slice(0, s); inner = src.slice(s, e); tail = src.slice(e);
	}
	const doc = new DOMParser().parseFromString('<!doctype html><html><body>' + tok(inner) + '</body></html>', 'text/html');
	mutate(doc);
	const body = restoreBareAttrs(untok(doc.body.innerHTML), bareAttrNames(inner));
	const out = head + (page.kind === 'fragment' ? trimBody(body) : body) + tail;
	await api('save', { path: page.source, content: out, compose: true });
}

function renderFiles() {
	const used = new Set(SLOTS.map(s => s.file));
	$('#fileGrid').innerHTML = MEDIA.content.map(f => `
		<div class="fcard">
			<div class="th"><img src="/${esc(f.path)}?t=${Date.now()}" alt="" loading="lazy"></div>
			<div class="meta">
				<b>${esc(f.name)}</b>
				${f.w ? f.w + '×' + f.h + ' · ' : ''}${f.kb}KB
				${used.has(f.name) ? '' : ' <span class="tag-unused">미사용</span>'}
			</div>
		</div>`).join('');
}

/* ============================================================
   4. 문의 접수
   ============================================================ */
let INQ = [], INQ_SEL = null, INQ_FILTER = '';
const ST_NAMES = { new: '신규', doing: '확인중', done: '회신완료', hold: '보류' };
function stName(s) { return ST_NAMES[s] || '신규'; }

views.inquiry = async function () {
	try {
		INQ = (await api('inquiries')).items || [];
		renderInqEndpoint();
		renderInqList();
	} catch (e) { fail(e); }
};

async function renderInqEndpoint() {
	const r = await api('file?path=' + encodeURIComponent('_build/pages/13-contact-inquiry.html'));
	const on = /data-endpoint="[^"]+"/.test(r.content);
	$('#inqEndpoint').innerHTML = `
		<h2 class="panel-tit">홈페이지 문의 폼 연결 상태</h2>
		<p class="panel-desc">${on
			? '<b>연결됨</b> — 관리자를 켜 둔 동안 홈페이지에서 넣은 문의가 이 화면으로 바로 들어옵니다. 관리자를 끄면 방문자에게는 기존처럼 메일 안내가 표시됩니다.'
			: '<b>연결 안 됨</b> — 지금은 방문자가 문의 폼을 제출하면 메일로 보내달라는 안내가 뜹니다. 아래 버튼을 누르면 관리자 실행 중에는 실제로 접수됩니다.'}</p>
		<p class="panel-desc" style="color:var(--txt-3)">이 연결은 <b>내 PC에서 열었을 때만</b> 동작하도록 되어 있어, 인터넷에 올려도 방문자에게는 영향을 주지 않습니다. 방문자 문의를 실제로 받으려면 호스팅 업체의 접수 서버(PHP 등)가 필요합니다.</p>
		<button type="button" class="btn ${on ? 'danger' : 'primary'}" id="inqToggle">${on ? '연결 끄기' : '연결 켜기'}</button>`;
	$('#inqToggle').onclick = async () => {
		busy(true, '설정을 바꾸는 중…');
		try {
			const page = STATE.pages.find(p => p.source.indexOf('13-contact-inquiry') >= 0);
			await patchPage(page, doc => {
				const f = doc.querySelector('#inquiryForm');
				f.setAttribute('data-endpoint', on ? '' : '/api/inquiry');
			});
			toast(on ? '연결을 껐습니다.' : '연결을 켰습니다.');
			renderInqEndpoint();
		} catch (e) { fail(e); } finally { busy(false); }
	};
}

$('#inqFilter').addEventListener('click', e => {
	const b = e.target.closest('button');
	if (!b) return;
	$$('#inqFilter button').forEach(x => x.classList.remove('on'));
	b.classList.add('on');
	INQ_FILTER = b.dataset.st;
	renderInqList();
});

function renderInqList() {
	const list = INQ.filter(i => !INQ_FILTER || i.status === INQ_FILTER);
	$('#inqList').innerHTML = list.map(i => `
		<button type="button" class="inq-item ${INQ_SEL === i.id ? 'on' : ''}" data-id="${esc(i.id)}">
			<span class="t"><span class="co">${esc(i.company || '(회사명 없음)')}</span>
			<span class="st ${i.status}">${stName(i.status)}</span>
			<span class="dt">${esc(String(i.at).slice(5, 16))}</span></span>
			<span class="ms">${esc(i.type || '')} · ${esc(i.message || '')}</span>
		</button>`).join('') || '<p class="empty-msg">해당하는 문의가 없습니다.</p>';
	$$('#inqList .inq-item').forEach(b => b.onclick = () => { INQ_SEL = b.dataset.id; renderInqList(); renderInqDetail(); });
	if (INQ_SEL) renderInqDetail();
}

function renderInqDetail() {
	const i = INQ.find(x => x.id === INQ_SEL);
	if (!i) { $('#inqDetail').innerHTML = '<p class="empty-msg">왼쪽에서 문의를 선택하세요.</p>'; return; }
	$('#inqDetail').innerHTML = `
		<h3>${esc(i.company || '(회사명 없음)')} <span class="st ${i.status}">${stName(i.status)}</span></h3>
		<table class="dl-table"><tbody>
			<tr><th>접수 일시</th><td>${esc(i.at)}</td></tr>
			<tr><th>담당자</th><td>${esc(i.name)}</td></tr>
			<tr><th>연락처</th><td><a href="tel:${esc(i.tel)}">${esc(i.tel)}</a></td></tr>
			<tr><th>이메일</th><td><a href="mailto:${esc(i.email)}">${esc(i.email)}</a></td></tr>
			<tr><th>문의 성격</th><td>${esc(i.type)}</td></tr>
			${(i.files && i.files.length) ? `<tr><th>첨부</th><td>${i.files.map(f => esc(f.name)).join('<br>')}<br><span class="hint">_admin\\attachments 폴더에 저장됨</span></td></tr>` : ''}
		</tbody></table>
		<div class="inq-msg">${esc(i.message)}</div>
		<div class="inq-actions">
			${Object.keys(ST_NAMES).map(k => `<button type="button" class="btn ${i.status === k ? 'primary' : 'ghost'} sm" data-set="${k}">${ST_NAMES[k]}</button>`).join('')}
			<a class="btn ghost sm" href="mailto:${esc(i.email)}?subject=${encodeURIComponent('[대건엠에스] 문의 회신')}">메일로 회신</a>
			<button type="button" class="btn danger sm" data-del="1" style="margin-left:auto">삭제</button>
		</div>
		<div class="form-row2"><label>내부 메모</label><textarea id="inqMemo" rows="3">${esc(i.memo || '')}</textarea></div>
		<button type="button" class="btn ghost sm" id="inqMemoSave">메모 저장</button>`;

	$$('#inqDetail [data-set]').forEach(b => b.onclick = async () => { i.status = b.dataset.set; await saveInq(); renderInqList(); renderInqDetail(); loadState(); });
	$('#inqMemoSave').onclick = async () => { i.memo = $('#inqMemo').value; await saveInq(); toast('메모를 저장했습니다.'); };
	$('#inqDetail [data-del]').onclick = async () => {
		if (!(await confirmBox('문의 삭제', '이 문의를 지웁니다. 되돌릴 수 없습니다.', '삭제'))) return;
		INQ = INQ.filter(x => x.id !== i.id);
		INQ_SEL = null;
		await saveInq();
		renderInqList();
		$('#inqDetail').innerHTML = '<p class="empty-msg">왼쪽에서 문의를 선택하세요.</p>';
		loadState();
	};
}
async function saveInq() { await api('inquiries-save', { items: INQ }); }

$('#inqAdd').addEventListener('click', () => {
	$('#modalBox').innerHTML = `<h3>문의 직접 등록</h3>
		<p style="color:var(--txt-2);font-size:14px;margin-bottom:16px">전화나 메일로 받은 문의를 기록해 둡니다.</p>
		${['회사명|company', '담당자명|name', '연락처|tel', '이메일|email'].map(x => {
		const [l, k] = x.split('|');
		return `<div class="form-row2"><label>${l}</label><input type="text" id="m_${k}"></div>`;
	}).join('')}
		<div class="form-row2"><label>문의 성격</label>
			<select id="m_type"><option>소싱 문의</option><option>견적 문의</option><option>제휴 제안</option><option>기타</option></select></div>
		<div class="form-row2"><label>문의 내용</label><textarea id="m_message" rows="5" style="min-height:auto"></textarea></div>
		<div class="modal-btns"><button type="button" class="btn ghost" data-c="1">취소</button><button type="button" class="btn primary" id="m_ok">등록</button></div>`;
	$('#modal').hidden = false;
	$('#modalBox').querySelector('[data-c]').onclick = () => { $('#modal').hidden = true; };
	$('#m_ok').onclick = async () => {
		const now = new Date();
		INQ.unshift({
			id: String(now.getTime()),
			at: now.toISOString().slice(0, 19).replace('T', ' '),
			company: $('#m_company').value, name: $('#m_name').value, tel: $('#m_tel').value,
			email: $('#m_email').value, type: $('#m_type').value, message: $('#m_message').value,
			files: [], status: 'new', memo: '(직접 등록)'
		});
		await saveInq();
		$('#modal').hidden = true;
		renderInqList();
		loadState();
		toast('등록했습니다.');
	};
});

$('#inqCsv').addEventListener('click', () => {
	const head = ['접수일시', '회사명', '담당자', '연락처', '이메일', '문의성격', '내용', '상태', '메모'];
	const rows = INQ.map(i => [i.at, i.company, i.name, i.tel, i.email, i.type, i.message, stName(i.status), i.memo]);
	const csv = [head].concat(rows)
		.map(r => r.map(c => '"' + String(c == null ? '' : c).replace(/"/g, '""') + '"').join(',')).join('\r\n');
	const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' });
	const a = document.createElement('a');
	a.href = URL.createObjectURL(blob);
	a.download = '대건엠에스_문의_' + today() + '.csv';
	a.click();
});

/* ============================================================
   5. 공지 · 자료실
   ============================================================ */
let POSTS = [], POST_SEL = null, BOARD = 'notice';

views.board = async function () {
	try {
		POSTS = (await api('posts')).items || [];
		renderPostList();
	} catch (e) { fail(e); }
};

$('#boardFilter').addEventListener('click', e => {
	const b = e.target.closest('button');
	if (!b) return;
	$$('#boardFilter button').forEach(x => x.classList.remove('on'));
	b.classList.add('on');
	BOARD = b.dataset.b;
	POST_SEL = null;
	renderPostList();
	$('#postEdit').innerHTML = '<p class="empty-msg">글을 선택하거나 <b>새 글 쓰기</b>를 누르세요.</p>';
});

function renderPostList() {
	const list = POSTS.filter(p => p.board === BOARD)
		.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0) || String(b.date).localeCompare(String(a.date)));
	$('#postList').innerHTML = list.map(p => `
		<button type="button" class="post-item ${POST_SEL === p.id ? 'on' : ''}" data-id="${esc(p.id)}">
			<span class="pt">${p.pinned ? '<span class="pin">고정</span>' : ''}${p.published === false ? '<span class="draft">비공개</span>' : ''}${esc(p.title)}</span>
			<span class="pd">${esc(p.date)}${p.files && p.files.length ? ' · 첨부 ' + p.files.length : ''}</span>
		</button>`).join('') || '<p class="empty-msg">등록된 글이 없습니다.</p>';
	$$('#postList .post-item').forEach(b => b.onclick = () => { POST_SEL = b.dataset.id; renderPostList(); editPost(POSTS.find(p => p.id === b.dataset.id)); });
}

$('#postNew').addEventListener('click', () => {
	POST_SEL = null;
	renderPostList();
	editPost({ id: '', board: BOARD, title: '', date: today(), content: '', files: [], pinned: false, published: true });
});

function editPost(p) {
	const cur = JSON.parse(JSON.stringify(p));
	$('#postEdit').innerHTML = `
		<div class="form-row2 row-2col">
			<div><label>제목</label><input type="text" id="p_title" value="${esc(cur.title)}" placeholder="공지 제목을 입력하세요"></div>
			<div style="flex:0 0 170px"><label>작성일</label><input type="date" id="p_date" value="${esc(cur.date)}"></div>
		</div>
		<div class="form-row2"><label>내용</label>
			<textarea id="p_content" placeholder="내용을 입력하세요.&#10;&#10;줄을 비우면 문단이 나뉩니다.">${esc(cur.content)}</textarea>
			<p class="editor-help">엔터로 줄바꿈, 빈 줄로 문단 나눔이 됩니다. 강조는 **굵게**, 링크는 주소를 그대로 적으면 자동으로 연결됩니다.</p>
		</div>
		<div class="form-row2">
			<label>첨부파일</label>
			<button type="button" class="btn ghost sm" id="p_addFile">파일 추가</button>
			<div class="attach-list" id="p_files"></div>
		</div>
		<div class="form-row2" style="display:flex;gap:20px">
			<label class="chk"><input type="checkbox" id="p_pin" ${cur.pinned ? 'checked' : ''}>목록 맨 위에 고정</label>
			<label class="chk"><input type="checkbox" id="p_pub" ${cur.published !== false ? 'checked' : ''}>홈페이지에 공개</label>
		</div>
		<div class="modal-btns" style="justify-content:flex-start">
			<button type="button" class="btn primary" id="p_save">저장하고 사이트에 반영</button>
			${cur.id ? '<button type="button" class="btn danger" id="p_del" style="margin-left:auto">글 삭제</button>' : ''}
		</div>`;

	const drawFiles = () => {
		$('#p_files').innerHTML = cur.files.map((f, i) =>
			`<div class="attach-row"><span>${esc(f.name)}</span><button type="button" class="btn ghost sm" data-rm="${i}">빼기</button></div>`).join('');
		$$('#p_files [data-rm]').forEach(b => b.onclick = () => { cur.files.splice(+b.dataset.rm, 1); drawFiles(); });
	};
	drawFiles();

	$('#p_addFile').onclick = () => {
		const inp = document.createElement('input');
		inp.type = 'file';
		inp.onchange = async () => {
			const f = inp.files[0];
			if (!f) return;
			busy(true, '파일을 올리는 중…');
			try {
				const up = await api('file-upload', { name: f.name, data: await fileToB64(f) });
				cur.files.push({ name: f.name, path: up.path, size: up.size });
				drawFiles();
			} catch (e) { fail(e); } finally { busy(false); }
		};
		inp.click();
	};

	$('#p_save').onclick = async () => {
		cur.title = $('#p_title').value.trim();
		cur.date = $('#p_date').value;
		cur.content = $('#p_content').value;
		cur.pinned = $('#p_pin').checked;
		cur.published = $('#p_pub').checked;
		cur.board = BOARD;
		if (!cur.title) return toast('제목을 입력해 주세요.', true);
		busy(true, '저장하고 사이트에 반영하는 중…');
		try {
			if (!cur.id) { cur.id = String(Date.now()); POSTS.push(cur); }
			else { POSTS[POSTS.findIndex(x => x.id === cur.id)] = cur; }
			await api('posts-save', { items: POSTS, publish: true });
			POST_SEL = cur.id;
			renderPostList();
			toast('저장했습니다. 홈페이지 News 메뉴에 반영되었습니다.');
		} catch (e) { fail(e); } finally { busy(false); }
	};

	if (cur.id) $('#p_del').onclick = async () => {
		if (!(await confirmBox('글 삭제', '이 글을 홈페이지에서 지웁니다.', '삭제'))) return;
		POSTS = POSTS.filter(x => x.id !== cur.id);
		await api('posts-save', { items: POSTS, publish: true });
		POST_SEL = null;
		renderPostList();
		$('#postEdit').innerHTML = '<p class="empty-msg">글을 선택하거나 <b>새 글 쓰기</b>를 누르세요.</p>';
		toast('삭제했습니다.');
	};
}

$('#boardPublish').addEventListener('click', async () => {
	busy(true, '게시판을 다시 만드는 중…');
	try {
		const r = await api('board-build');
		toast('게시판을 사이트에 반영했습니다.');
		console.log(r.log);
	} catch (e) { fail(e); } finally { busy(false); }
});

/* ============================================================
   6. 배포 · 백업
   ============================================================ */
views.deploy = async function () {
	try {
		const r = await api('backups');
		$('#backupList').innerHTML = r.items.length ? r.items.map(b => `
			<div class="bk-row">
				<span class="f">${esc(b.name.replace(/^\d{8}-\d{6}__/, '').replace(/__/g, ' / '))}</span>
				<span class="t">${esc(b.at)}</span>
				<button type="button" class="btn ghost sm" data-bk="${esc(b.name)}">이 시점으로 되돌리기</button>
			</div>`).join('') : '<p class="empty-msg">아직 백업이 없습니다.</p>';
		$$('#backupList [data-bk]').forEach(b => b.onclick = async () => {
			if (!(await confirmBox('되돌리기', '이 시점의 파일로 되돌립니다. 지금 상태는 새 백업으로 보관됩니다.', '되돌리기'))) return;
			busy(true, '되돌리는 중…');
			try { await api('restore', { name: b.dataset.bk }); toast('되돌렸습니다.'); views.deploy(); }
			catch (e) { fail(e); } finally { busy(false); }
		});
	} catch (e) { fail(e); }
};

$('#gitStatus').addEventListener('click', async () => {
	busy(true, '확인 중…');
	try {
		const r = await api('git-status');
		$('#statusLog').hidden = false;
		$('#statusLog').textContent = r.log.trim() || '변경된 파일이 없습니다. (모두 반영됨)';
	} catch (e) { fail(e); } finally { busy(false); }
});

$('#gitPush').addEventListener('click', async () => {
	const msg = $('#gitMsg').value.trim() || '관리자에서 콘텐츠 수정';
	if (!(await confirmBox('사이트에 올리기', '수정한 내용을 인터넷에 공개합니다.<br>1~2분 뒤 반영됩니다.', '올리기'))) return;
	busy(true, '사이트에 올리는 중…');
	try {
		const r = await api('git-push', { message: msg });
		$('#gitLog').hidden = false;
		$('#gitLog').textContent = r.log;
		$('#gitMsg').value = '';
		toast('올렸습니다. 1~2분 뒤 사이트에 반영됩니다.');
	} catch (e) { fail(e); } finally { busy(false); }
});

/* -------------------------------------------------- 시작 */
go((location.hash || '#dash').slice(1));

})();
