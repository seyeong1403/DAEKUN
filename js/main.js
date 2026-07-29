/* ========================================================
 * DAEKUN MS — main.js
======================================================== */
(function () {
	'use strict';

	/* 모션 최소화 설정 존중 */
	var reduceMotion = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);

	/* 현재 메뉴 활성화 : body[data-menu] ↔ #gnb li[data-menu] */
	var curMenu = document.body.getAttribute('data-menu');
	if (curMenu) {
		var curLi = document.querySelector('#gnb > ul > li[data-menu="' + curMenu + '"]');
		if (curLi) curLi.classList.add('on');
	}

	/* ----------------------------------------------------
	 * 1. 헤더 : 스크롤 시 고정 스타일
	 * -------------------------------------------------- */
	var headerWrap = document.getElementById('headerInnerWrap');
	var goTopBtn = document.querySelector('.go-top-btn');

	function onScroll() {
		var y = window.pageYOffset || document.documentElement.scrollTop;
		if (headerWrap) headerWrap.classList.toggle('fixed', y > 80);
		if (goTopBtn) goTopBtn.classList.toggle('on', y > 600);
	}
	window.addEventListener('scroll', onScroll, { passive: true });
	onScroll();

	if (goTopBtn) {
		goTopBtn.addEventListener('click', function () {
			window.scrollTo({ top: 0, behavior: 'smooth' });
		});
	}

	/* ----------------------------------------------------
	 * 2. 메인 비주얼 : 자동 롤링 + 페이징
	 * -------------------------------------------------- */
	var visualItems = document.querySelectorAll('#mainVisual .main-visual-item');
	var pagingBtns = document.querySelectorAll('.main-visual-paging button');
	var visualIndex = 0;
	var visualTimer = null;
	var VISUAL_DELAY = 7000;

	function goVisual(idx) {
		if (!visualItems.length) return;
		visualIndex = (idx + visualItems.length) % visualItems.length;
		for (var i = 0; i < visualItems.length; i++) {
			visualItems[i].classList.toggle('active-item', i === visualIndex);
		}
		for (var j = 0; j < pagingBtns.length; j++) {
			pagingBtns[j].classList.toggle('on', j === visualIndex);
		}
	}
	function startVisual() {
		stopVisual();
		if (visualItems.length < 2 || reduceMotion) return;
		visualTimer = window.setInterval(function () { goVisual(visualIndex + 1); }, VISUAL_DELAY);
	}
	function stopVisual() {
		if (visualTimer) { window.clearInterval(visualTimer); visualTimer = null; }
	}
	for (var p = 0; p < pagingBtns.length; p++) {
		(function (index) {
			pagingBtns[index].addEventListener('click', function () {
				goVisual(index);
				startVisual();
			});
		})(p);
	}
	startVisual();
	document.addEventListener('visibilitychange', function () {
		if (document.hidden) { stopVisual(); } else { startVisual(); }
	});

	/* ----------------------------------------------------
	 * 3. 숫자 카운트업
	 * -------------------------------------------------- */
	function countUp(el) {
		if (el.dataset.done === 'true') return;
		el.dataset.done = 'true';
		var target = parseInt(el.getAttribute('data-count'), 10) || 0;
		if (reduceMotion) { el.textContent = String(target); return; }
		var duration = 1600;
		var startTime = null;

		function step(now) {
			if (startTime === null) startTime = now;
			var progress = Math.min((now - startTime) / duration, 1);
			var eased = 1 - Math.pow(1 - progress, 3);
			el.textContent = String(Math.round(target * eased));
			if (progress < 1) window.requestAnimationFrame(step);
			else el.textContent = String(target);
		}
		window.requestAnimationFrame(step);
	}

	/* ----------------------------------------------------
	 * 4. 스크롤 진입 모션 (IntersectionObserver)
	 * -------------------------------------------------- */
	var scrollTargets = document.querySelectorAll('[data-scroll], [data-animate], .about-copy .line');

	if ('IntersectionObserver' in window) {
		var io = new IntersectionObserver(function (entries) {
			entries.forEach(function (entry) {
				if (!entry.isIntersecting) return;
				var el = entry.target;

				if (el.classList.contains('line')) {
					el.classList.add('on');
				} else {
					el.classList.add('animated');
				}

				var counters = el.querySelectorAll('.count');
				for (var c = 0; c < counters.length; c++) countUp(counters[c]);

				io.unobserve(el);
			});
		}, { root: null, rootMargin: '0px 0px -14% 0px', threshold: 0.12 });

		for (var s = 0; s < scrollTargets.length; s++) io.observe(scrollTargets[s]);
	} else {
		/* 폴백 : 모션 없이 즉시 표시 */
		for (var f = 0; f < scrollTargets.length; f++) {
			scrollTargets[f].classList.add('animated');
			scrollTargets[f].classList.add('on');
			var cs = scrollTargets[f].querySelectorAll('.count');
			for (var k = 0; k < cs.length; k++) countUp(cs[k]);
		}
	}

	/* ----------------------------------------------------
	 * 5. 모바일 전체메뉴 토글
	 * -------------------------------------------------- */
	var sitemapBtn = document.querySelector('.sitemap-btn');
	var gnb = document.getElementById('gnb');
	if (sitemapBtn && gnb) {
		sitemapBtn.addEventListener('click', function () {
			var opened = gnb.classList.toggle('open');
			sitemapBtn.classList.toggle('active', opened);
			document.body.style.overflow = opened ? 'hidden' : '';
		});
		/* 모바일 : 1depth 탭하면 2depth 아코디언 */
		var depth1Links = gnb.querySelectorAll(':scope > ul > li > a');
		for (var d = 0; d < depth1Links.length; d++) {
			depth1Links[d].addEventListener('click', function (e) {
				if (window.innerWidth > 1180) return;
				var li = this.parentNode;
				if (!li.querySelector('.gnb-2dep')) return;
				e.preventDefault();
				li.classList.toggle('open');
			});
		}
	}
})();
