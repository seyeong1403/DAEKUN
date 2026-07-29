<#
  DAEKUN MS — 임시 보고용 샘플 이미지 수집
  ------------------------------------------------------------------
  ⚠ 여기 내려받는 이미지는 전부 Unsplash 무료 스톡이며 **초안 검토용 임시 이미지**다.
     대건엠에스의 실제 제품/공장 사진이 아니므로, 대외 오픈 전에는 반드시
     실제 촬영본 또는 정식 라이선스 이미지로 교체해야 한다.
     Unsplash License : 상업·비상업 무료 사용, 출처 표기 의무 없음(권장).
     https://unsplash.com/license
  ------------------------------------------------------------------
  실행 : powershell -File _build\fetch-images.ps1
  결과 : images/content/*.jpg + images/_credits.md (출처 기록)
#>
param([string]$Root = 'C:\Users\PC\Desktop\daekunms')
$ErrorActionPreference = 'Continue'
$dest = Join-Path $Root 'images\content'
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }

# file | unsplash photo id | 가로 | 세로 | 용도 설명
$MANIFEST = @'
hero_01|1741176505800-caaa3a52631a|2000|900|메인 히어로 01 — 대규모 봉제 공장
hero_02|1640767760729-7bfb6ce43ad4|2000|900|메인 히어로 02 — 원단 볼트 진열
sub_about|1741176506261-73218298e4d8|2000|900|회사소개 서브 비주얼 — 원단 선별 작업
sub_sourcing|1517146783983-418c681b56c5|2000|900|글로벌 소싱 서브 비주얼 — 실·부자재
sub_network|1670121180530-cfcba4438038|2000|900|생산 네트워크 서브 비주얼 — 부두 컨테이너선
sub_products|1542060748-10c28b62716f|2000|900|제품 서브 비주얼 — 의류 진열
sub_quality|1673201229733-69d19c5c4a87|2000|900|품질 서브 비주얼 — 재봉 작업
sub_contact|1573164574572-cb89e39749b4|2000|900|문의 서브 비주얼 — 회의
sub_etc|1601056639638-c53c50e13ead|2000|900|약관 서브 비주얼 — 원단 패턴
main_prod_active|1618259181324-86a49fe68099|800|1067|메인 제품카드 — 액티브웨어
main_prod_sweater|1574201635302-388dd92a4c3f|800|1067|메인 제품카드 — 스웨터
main_prod_woven|1489987707025-afc232f7ea0f|800|1067|메인 제품카드 — 우븐·아우터
main_prod_swim|1492709560992-3fa75e9e887b|800|1067|메인 제품카드 — 수영복 제품 플랫레이
pi_active|1699065186298-7f963b0d8c81|900|1125|액티브웨어 대표 컷
pi_sweater|1641642231157-0849081598a2|900|1125|스웨터 대표 컷
pi_woven|1523199455310-87b16c0eed11|900|1125|우븐·아우터 대표 컷
pi_swim|1571425046076-94af69bd4201|900|1125|수영복 대표 컷 — 제품 플랫레이
lb_active_01|1645318801217-143533cb559f|800|1067|액티브웨어 룩북 01
lb_active_02|1645207803533-e2cfe1382f2c|800|1067|액티브웨어 룩북 02
lb_active_03|1645318800735-737d3a422de6|800|1067|액티브웨어 룩북 03
lb_active_04|1668260920944-ec171ceb8633|800|1067|액티브웨어 룩북 04
lb_active_05|1699065186329-097ea2d9c07f|800|1067|액티브웨어 룩북 05
lb_active_06|1515614557830-ae0df9016e19|800|1067|액티브웨어 룩북 06
lb_sweater_01|1631541909061-71e349d1f203|800|1067|스웨터 룩북 01
lb_sweater_02|1601379327928-bedfaf9da2d0|800|1067|스웨터 룩북 02
lb_sweater_03|1643015862949-5c8d15a4242e|800|1067|스웨터 룩북 03
lb_sweater_04|1588271968087-4c51abe05afc|800|1067|스웨터 룩북 04
lb_sweater_05|1610973310510-82f514ea1986|800|1067|스웨터 룩북 05
lb_sweater_06|1636146049394-0924c2b66104|800|1067|스웨터 룩북 06
lb_woven_01|1490481651871-ab68de25d43d|800|1067|우븐 룩북 01
lb_woven_02|1603252109303-2751441dd157|800|1067|우븐 룩북 02
lb_woven_03|1561053720-76cd73ff22c3|800|1067|우븐 룩북 03
lb_woven_04|1529720317453-c8da503f2051|800|1067|우븐 룩북 04
lb_woven_05|1629426958003-35a5583b2977|800|1067|우븐 룩북 05
lb_woven_06|1612423284934-2850a4ea6b0f|800|1067|우븐 룩북 06
lb_swim_01|1749220781965-b745d9efd3ce|800|1067|수영복 룩북 01 — 제품 컷
lb_swim_02|1783347337250-895996a354b3|800|1067|수영복 룩북 02 — 제품 플랫레이
lb_swim_03|1749104371559-5930065852be|800|1067|수영복 룩북 03 — 제품 플랫레이
lb_swim_04|1595026525047-dfa997df8a4a|800|1067|수영복 룩북 04 — 니트 소재 컷
lb_swim_05|1624516268152-1e48624026ed|800|1067|수영복 룩북 05 — 텍스타일 컷
lb_swim_06|1615806528302-05c722d51e0d|800|1067|수영복 룩북 06 — 텍스타일 컷
'@ -split "`r?`n" | Where-Object { $_.Trim() -ne '' }

$ok = 0; $fail = @()
$credits = New-Object System.Collections.Generic.List[string]
$credits.Add('# 이미지 출처 및 라이선스')
$credits.Add('')
$credits.Add('> **주의 — 전부 임시 검토용 샘플입니다.**')
$credits.Add('> 아래 이미지는 Unsplash 무료 스톡이며 대건엠에스의 실제 제품·공장 사진이 아닙니다.')
$credits.Add('> 대외 오픈 전 실제 촬영본 또는 정식 라이선스 이미지로 교체해야 합니다.')
$credits.Add('> Unsplash License : 상업·비상업 무료 사용, 출처 표기 의무 없음 — https://unsplash.com/license')
$credits.Add('')
$credits.Add('| 파일 | 용도 | 원본 |')
$credits.Add('| --- | --- | --- |')

foreach ($line in $MANIFEST) {
	$p = $line -split '\|'
	$name = $p[0]; $id = $p[1]; $w = $p[2]; $h = $p[3]; $desc = $p[4]
	$url = "https://images.unsplash.com/photo-$id" + "?w=$w&h=$h&fit=crop&crop=entropy&q=72&fm=jpg"
	$out = Join-Path $dest "$name.jpg"
	curl.exe -s -L --max-time 30 -o $out $url
	if ((Test-Path $out) -and (Get-Item $out).Length -gt 8000) {
		$ok++
		$kb = [math]::Round((Get-Item $out).Length / 1KB, 1)
		Write-Output ("OK   {0,-20} {1,7} KB  {2}" -f "$name.jpg", $kb, $desc)
		$credits.Add("| ``images/content/$name.jpg`` | $desc | https://unsplash.com/photos/$id |")
	} else {
		$fail += $name
		Write-Output ("FAIL {0,-20} {1}" -f "$name.jpg", $url)
	}
}

$credits.Add('| `images/content/map_location.jpg` | 찾아오시는 길 본사 위치 지도 | Map data © OpenStreetMap contributors, ODbL 1.0 — _build/fetch-map.ps1 로 생성 |')
$credits.Add('| `images/content/map_network.jpg` | 글로벌 생산 네트워크 다크 지도 | Map data © OpenStreetMap contributors, ODbL 1.0 — _build/fetch-map-world.ps1 로 생성 |')
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $Root 'images\_credits.md'), ($credits -join "`n") + "`n", $utf8)

Write-Output ""
Write-Output "=== 성공 $ok / 실패 $($fail.Count) ==="
if ($fail.Count) { Write-Output ("실패 : " + ($fail -join ', ')) }
