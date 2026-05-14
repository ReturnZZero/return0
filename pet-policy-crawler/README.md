# pet-policy-crawler — MyPetTrip 반려견 정책 크롤링 파이프라인

반려견 동반 장소의 정책 정보(체중 제한, 견종 제한, 실내/실외 이용 여부 등)를
다중 출처에서 수집하고, GPT로 구조화하여 Firestore DB에 저장하는 오프라인 파이프라인입니다.
Flutter 앱과는 독립적으로 동작합니다.

## 파일 구조

```
pet-policy-crawler/
├── crawlers.py      ← Step 1: 출처별 크롤링
├── extractor.py     ← Step 2-4: GPT 추출 + Confidence Score + 충돌 감지
├── db_writer.py     ← Step 5: Firestore Upsert + 관리자 큐 등록
├── pipeline.py      ← 전체 파이프라인 오케스트레이터
├── requirements.txt
└── README.md
```

## 전체 흐름

```
장소 목록 (PlaceTarget)
  │
  ▼
[crawlers.py] 출처별 크롤링
  ├─ OfficialWebCrawler     → 공식 홈페이지      (source_score: 1.00)
  ├─ InstagramCrawler       → bio + 공식 포스트
  │    ├─ INSTAGRAM_BIO     → 소개란             (source_score: 0.85)
  │    └─ INSTAGRAM_POST    → 포스트 캡션 최대 5건 (source_score: 0.80)
  ├─ NaverBlogCrawler       → 네이버 블로그       (source_score: 0.55)
  └─ KakaoReviewCrawler     → 카카오맵 후기       (source_score: 0.40)
          │
          ▼  list[RawDocument]
[extractor.py] GPT 구조화 추출
  └─ 출처별 맞춤 source_hint + 인라인 JSON 스키마 + 8개 추출 규칙
     temperature=0.0 (결정론적 추출)
     → pet_allowed, weight_limit_kg, breed_restriction,
       indoor_allowed, outdoor_allowed, leash_required,
       carrier_required, extra_notes
          │
          ▼  PolicyExtraction
[extractor.py] Confidence Score 계산
  ├─ 출처 신뢰도  (가중치 40%)
  ├─ 최신성       (가중치 30%) — 최대 2년
  └─ 키워드 명확성 (가중치 30%) — pet_allowed 2배 가중
          │
          ▼  scored PolicyExtraction
[extractor.py] 충돌 감지 & NEEDS_REVIEW 판정
  ├─ confidence < 0.45 → NEEDS_REVIEW
  ├─ pet_allowed / weight_limit_kg / indoor_allowed / outdoor_allowed 충돌 → NEEDS_REVIEW
  └─ 정상이면 최고 신뢰도 출처로 merged_policy 생성
          │
          ▼  PlaceReviewStatus
[db_writer.py] Firestore 저장
  ├─ places/{place_id}/raw_extractions/{hash}  ← 개별 원본
  ├─ places/{place_id}                         ← 최종 정책 + 상태
  └─ admin_review_queue/{place_id}             ← NEEDS_REVIEW이면 자동 등록
```

## 환경변수 설정 (.env)

```
OPENAI_API_KEY=sk-...
NAVER_CLIENT_ID=...
NAVER_CLIENT_SECRET=...
FIREBASE_CREDENTIALS_PATH=serviceAccountKey.json
```

## 실행 방법

```python
from pipeline import run_batch, PlaceTarget

places = [
    PlaceTarget(
        place_id         = "cafe_001",
        place_name       = "실제 카페 이름",
        official_url     = "https://실제홈페이지.com",
        instagram_handle = "실제_인스타계정",
        kakao_place_id   = "카카오맵_장소ID",
    ),
]

# dry_run=True: Firestore 저장 없이 결과만 출력 (개발/디버깅용)
run_batch(places, dry_run=True)

# 실제 저장
run_batch(places, dry_run=False)
```

## Confidence Score 기준

| 출처                | source_score |
|---------------------|-------------|
| 공식 홈페이지        | 1.00        |
| 인스타그램 bio       | 0.85        |
| 인스타그램 포스트    | 0.80        |
| 네이버 블로그        | 0.55        |
| 후기 (카카오맵)      | 0.40        |

- **최종 score = 출처(40%) + 최신성(30%) + 명확성(30%)**
- score < 0.45 → 자동 NEEDS_REVIEW

## NEEDS_REVIEW 트리거 조건

1. confidence_score < 0.45
2. pet_allowed, weight_limit_kg, indoor_allowed, outdoor_allowed 중 하나라도 출처 간 충돌

## GPT 모델

- 기본값: `gpt-4o-mini` (비용 효율적, 정확도 차이 2.8%p 이내)