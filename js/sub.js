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
		}
	});
})();
