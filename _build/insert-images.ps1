<#
  DAEKUN MS — 이미지 슬롯에 샘플 이미지 삽입
  ------------------------------------------------------------------
  .img-slot 안의 규격 라벨(<span class="slot-spec">)을 HTML 주석으로 옮기고
  같은 자리에 <img>를 넣는다. 규격 주석이 남으므로 실제 촬영본으로 교체할 때
  어떤 컷이 들어갈 자리인지 그대로 확인할 수 있다.

  대상 : index.html + _build/pages/*.html  → 실행 후 compose.ps1 재실행 필요
  참고 : 찾아오시는 길 지도는 _build/fetch-map.ps1 로 생성한 정적 지도(OSM). 정식 오픈 시 지도 API 임베드로 교체
#>
param([string]$Root = 'C:\Users\PC\Desktop\daekunms')
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# 파일별로 문서 순서대로 채울 이미지 : "파일명|alt"  ('SKIP' 이면 슬롯 그대로 유지)
$FILES = @(
	'index.html',
	'_build\pages\01-about-overview.html',
	'_build\pages\02-about-history.html',
	'_build\pages\03-about-organization.html',
	'_build\pages\04-about-customers.html',
	'_build\pages\05-about-location.html',
	'_build\pages\06-business-sourcing.html',
	'_build\pages\07-business-network.html',
	'_build\pages\08-products-activewear.html',
	'_build\pages\09-products-sweaters.html',
	'_build\pages\10-products-woven.html',
	'_build\pages\11-products-swimwear.html',
	'_build\pages\12-quality-assurance.html',
	'_build\pages\13-contact-inquiry.html',
	'_build\pages\14-contact-global.html',
	'_build\pages\15-etc-privacy.html',
	'_build\pages\16-etc-agreement.html'
)
$PLAN = @{}
$PLAN['index.html'] = @(
	'hero_01|대규모 봉제 라인에서 진행되는 의류 생산',
	'hero_02|직접 소싱한 원단이 정리된 진열대',
	'main_prod_active|고기능성 니트로 제작한 액티브웨어',
	'main_prod_sweater|프리미엄 니트웨어 스웨터',
	'main_prod_woven|행거에 걸린 우븐 셔츠',
	'main_prod_swim|수영복 제품 플랫레이'
)
$PLAN['_build\pages\01-about-overview.html']     = @('sub_about|원단을 선별하는 생산 현장')
$PLAN['_build\pages\02-about-history.html']      = @('sub_about|원단을 선별하는 생산 현장')
$PLAN['_build\pages\03-about-organization.html'] = @('sub_about|원단을 선별하는 생산 현장')
$PLAN['_build\pages\04-about-customers.html']    = @('sub_about|원단을 선별하는 생산 현장')
$PLAN['_build\pages\05-about-location.html']     = @('sub_about|원단을 선별하는 생산 현장', 'map_location|대건엠에스 본사 위치 지도 — 서울시 성동구 상원12길 34, A1센터 804호')
$PLAN['_build\pages\06-business-sourcing.html']  = @('sub_sourcing|직접 소싱한 원사와 부자재')
$PLAN['_build\pages\07-business-network.html']   = @('sub_network|부두에 접안한 컨테이너선', 'map_network|대건엠에스 글로벌 생산 네트워크 지도 — 한국 본사와 베트남·중국·방글라데시·인도네시아 생산 거점')
$PLAN['_build\pages\08-products-activewear.html'] = @(
	'sub_products|카테고리별로 진열된 의류', 'pi_active|액티브웨어 착장 컷',
	'lb_active_01|액티브웨어 룩북 1', 'lb_active_02|액티브웨어 룩북 2', 'lb_active_03|액티브웨어 룩북 3',
	'lb_active_04|액티브웨어 룩북 4', 'lb_active_05|액티브웨어 룩북 5', 'lb_active_06|액티브웨어 룩북 6'
)
$PLAN['_build\pages\09-products-sweaters.html'] = @(
	'sub_products|카테고리별로 진열된 의류', 'pi_sweater|스웨터 대표 컷',
	'lb_sweater_01|스웨터 룩북 1', 'lb_sweater_02|스웨터 룩북 2', 'lb_sweater_03|스웨터 룩북 3',
	'lb_sweater_04|스웨터 룩북 4', 'lb_sweater_05|스웨터 룩북 5', 'lb_sweater_06|스웨터 룩북 6'
)
$PLAN['_build\pages\10-products-woven.html'] = @(
	'sub_products|카테고리별로 진열된 의류', 'pi_woven|우븐·아우터 대표 컷',
	'lb_woven_01|우븐 룩북 1', 'lb_woven_02|우븐 룩북 2', 'lb_woven_03|우븐 룩북 3',
	'lb_woven_04|우븐 룩북 4', 'lb_woven_05|우븐 룩북 5', 'lb_woven_06|우븐 룩북 6'
)
$PLAN['_build\pages\11-products-swimwear.html'] = @(
	'sub_products|카테고리별로 진열된 의류', 'pi_swim|수영복 대표 컷',
	'lb_swim_01|수영복 룩북 1', 'lb_swim_02|수영복 룩북 2', 'lb_swim_03|수영복 룩북 3',
	'lb_swim_04|이너웨어 소재 컷', 'lb_swim_05|텍스타일 컷', 'lb_swim_06|텍스타일 컷'
)
$PLAN['_build\pages\12-quality-assurance.html'] = @('sub_quality|재봉 공정 품질 확인')
$PLAN['_build\pages\13-contact-inquiry.html']   = @('sub_contact|회의실에서 진행되는 상담')
$PLAN['_build\pages\14-contact-global.html']    = @('sub_contact|회의실에서 진행되는 상담')
$PLAN['_build\pages\15-etc-privacy.html']       = @('sub_etc|원단 텍스처')
$PLAN['_build\pages\16-etc-agreement.html']     = @('sub_etc|원단 텍스처')

# 히어로형(빈 슬롯 div + 형제 span) / 일반형(슬롯 div 안에 span)
$rxHero = [regex]'(?s)<div class="(?<cls>[^"]*img-slot)"(?<attr>[^>]*)></div>\s*<span class="slot-spec">(?<spec>[^<]*)</span>'
$rxIn   = [regex]'(?s)<div class="(?<cls>[^"]*img-slot)"(?<attr>[^>]*)>\s*<span class="slot-spec">(?<spec>[^<]*)</span>\s*</div>'

$totalSlot = 0; $totalImg = 0; $totalSkip = 0
foreach ($rel in $FILES) {
	$path = Join-Path $Root $rel
	if (-not (Test-Path $path)) { Write-Output "MISS $rel"; continue }
	$html = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
	$list = @($PLAN[$rel])
	$prefix = if ($rel -like '_build\*') { '../images/content/' } else { 'images/content/' }

	# 두 패턴의 매치를 모아 문서 순서로 정렬
	$hits = @()
	foreach ($m in $rxHero.Matches($html)) { $hits += [pscustomobject]@{ M = $m; Kind = 'hero' } }
	foreach ($m in $rxIn.Matches($html))   { $hits += [pscustomobject]@{ M = $m; Kind = 'in' } }
	$hits = @($hits | Sort-Object { $_.M.Index })

	if ($hits.Count -ne $list.Count) {
		Write-Output ("WARN {0} : 슬롯 {1}개인데 계획은 {2}개" -f $rel, $hits.Count, $list.Count)
	}

	# 뒤에서부터 치환해야 인덱스가 밀리지 않는다
	$placed = 0; $skipped = 0
	for ($i = $hits.Count - 1; $i -ge 0; $i--) {
		if ($i -ge $list.Count) { continue }
		$entry = [string]$list[$i]
		if ($entry -eq 'SKIP') { $skipped++; continue }
		$parts = $entry.Split('|')
		$file = $parts[0]; $alt = $parts[1]
		$m = $hits[$i].M
		$cls = $m.Groups['cls'].Value
		$attr = $m.Groups['attr'].Value
		$spec = $m.Groups['spec'].Value
		$lazy = if ($hits[$i].Kind -eq 'hero') { '' } else { ' loading="lazy"' }
		$new = '<!-- 이미지 슬롯 : ' + $spec + ' --><div class="' + $cls + ' has-img"' + $attr + '>' +
			'<img src="' + $prefix + $file + '.jpg" alt="' + $alt + '"' + $lazy + '></div>'
		$html = $html.Remove($m.Index, $m.Length).Insert($m.Index, $new)
		$placed++
	}

	[System.IO.File]::WriteAllText($path, $html, $utf8)
	$totalSlot += $hits.Count; $totalImg += $placed; $totalSkip += $skipped
	Write-Output ("OK  {0,-42} 슬롯 {1,2} → 이미지 {2,2} / 유지 {3}" -f $rel, $hits.Count, $placed, $skipped)
}
Write-Output ""
Write-Output "=== 슬롯 $totalSlot / 이미지 삽입 $totalImg / 슬롯 유지 $totalSkip ==="
Write-Output "다음 단계 : powershell -File _build\compose.ps1"
