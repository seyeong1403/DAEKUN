/* ========================================================
 * DAEKUN MS — sub.js (서브 페이지 전용)
======================================================== */
(function () {
	'use strict';

	/* ----------------------------------------------------
	 * 1. 국가 탭 (글로벌 생산 네트워크)
	 * -------------------------------------------------- */
	var tabWrap = document.querySelector('.country-tab');
	var panelWrap = document.querySelector('.country-panel');

	if (tabWrap && panelWrap) {
		var tabBtns = tabWrap.querySelectorAll('button');
		var panels = panelWrap.querySelectorAll('.panel');

		Array.prototype.forEach.call(tabBtns, function (btn) {
			btn.addEventListener('click', function () {
				var key = btn.getAttribute('data-country');
				Array.prototype.forEach.call(tabBtns, function (b) {
					var on = b === btn;
					b.classList.toggle('on', on);
					b.setAttribute('aria-selected', on ? 'true' : 'false');
				});
				Array.prototype.forEach.call(panels, function (p) {
					p.classList.toggle('on', p.getAttribute('data-country') === key);
				});
			});
		});
	}

	/* ----------------------------------------------------
	 * 2. 문의 폼 검증
	 * -------------------------------------------------- */
	var form = document.getElementById('inquiryForm');
	if (!form) return;

	var notice = document.getElementById('formNotice');
	var endpoint = form.getAttribute('data-endpoint') || '';

	/* 로컬 관리자(내 PC)로 접수하도록 설정된 경우, 실제 방문자에게는 적용하지 않는다.
	   실서버 주소(/inquiry.php 등)를 넣으면 어디서든 그대로 전송된다. */
	var isLocal = /^(localhost|127\.0\.0\.1)$/.test(location.hostname);
	if (endpoint.indexOf('/api/') === 0 && !isLocal) endpoint = '';

	function rowOf(el) {
		return el.closest('.form-row') || el.closest('.form-agree');
	}
	function setError(el, on) {
		var row = rowOf(el);
		if (row) row.classList.toggle('has-error', !!on);
	}
	function isEmail(v) {
		return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
	}

	/* 입력하면 에러 해제 */
	form.addEventListener('input', function (e) {
		if (e.target.matches('input, textarea, select')) setError(e.target, false);
	});
	form.addEventListener('change', function (e) {
		if (e.target.matches('input, textarea, select')) setError(e.target, false);
	});

	form.addEventListener('submit', function (e) {
		var firstBad = null;

		/* 필수 텍스트 항목 */
		Array.prototype.forEach.call(form.querySelectorAll('[data-required]'), function (el) {
			var bad = false;
			if (el.type === 'checkbox') {
				bad = !el.checked;
			} else {
				bad = el.value.trim() === '';
				if (!bad && el.type === 'email' && !isEmail(el.value.trim())) bad = true;
			}
			setError(el, bad);
			if (bad && !firstBad) firstBad = el;
		});

		if (firstBad) {
			e.preventDefault();
			var row = rowOf(firstBad);
			if (row) window.scrollTo({ top: row.getBoundingClientRect().top + window.scrollY - 160, behavior: 'smooth' });
			if (firstBad.focus) firstBad.focus({ preventScroll: true });
			return;
		}

		/* 접수 서버가 아직 연결되지 않은 경우 : 메일 안내로 대체 */
		if (!endpoint) {
			e.preventDefault();
			if (notice) {
				notice.classList.add('on');
				window.scrollTo({ top: notice.getBoundingClientRect().top + window.scrollY - 200, behavior: 'smooth' });
			}
			return;
		}

		/* 접수 서버가 연결된 경우 : JSON 으로 전송한다 */
		e.preventDefault();
		send();
	});

	function send() {
		var btn = form.querySelector('.btn-submit');
		var label = btn ? btn.textContent : '';
		if (btn) { btn.disabled = true; btn.textContent = '접수하는 중…'; }

		var data = {
			company: form.company.value.trim(),
			name: form.name.value.trim(),
			tel: form.tel.value.trim(),
			email: form.email.value.trim(),
			type: (form.querySelector('input[name="type"]:checked') || {}).value || '',
			message: form.message.value.trim(),
			files: []
		};

		var picked = Array.prototype.slice.call((form.querySelector('#fFile') || {}).files || []);
		var jobs = picked.map(function (f) {
			return new Promise(function (res) {
				var r = new FileReader();
				r.onload = function () { data.files.push({ name: f.name, data: String(r.result).split(',')[1] }); res(); };
				r.onerror = function () { res(); };
				r.readAsDataURL(f);
			});
		});

		Promise.all(jobs).then(function () {
			return fetch(endpoint, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(data)
			});
		}).then(function (r) {
			return r.json();
		}).then(function (j) {
			if (!j || !j.ok) throw new Error('접수 실패');
			done(true);
		}).catch(function () {
			done(false);
		}).then(function () {
			if (btn) { btn.disabled = false; btn.textContent = label; }
		});
	}

	function done(ok) {
		if (!notice) return;
		notice.classList.add('on');
		notice.innerHTML = ok
			? '문의가 정상적으로 접수되었습니다. 담당자가 확인 후 회신드리겠습니다. 감사합니다.'
			: '접수 중 오류가 발생했습니다. 번거로우시겠지만 <a href="mailto:jesse@daekunms.co.kr">jesse@daekunms.co.kr</a> 로 보내주시면 확인 후 회신드리겠습니다.';
		if (ok) form.reset();
		window.scrollTo({ top: notice.getBoundingClientRect().top + window.scrollY - 200, behavior: 'smooth' });
	}
})();
