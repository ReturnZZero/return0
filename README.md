<div align="center">

#  MyPetTrip
### AI 기반 반려동물 동반 장소 추천 서비스

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)](https://firebase.google.com)
[![OpenAI](https://img.shields.io/badge/OpenAI%20GPT-412991?style=flat-square&logo=openai&logoColor=white)](https://openai.com)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Google Maps](https://img.shields.io/badge/Google%20Maps%20API-4285F4?style=flat-square&logo=googlemaps&logoColor=white)](https://developers.google.com/maps)

[![학교](https://img.shields.io/badge/이화여자대학교-컴퓨터공학과-9B59B6?style=flat-square)]()
[![트랙](https://img.shields.io/badge/캡스톤디자인-산학%20트랙-2ECC71?style=flat-square)]()
[![팀](https://img.shields.io/badge/Team%2025-return%200%3B-E74C3C?style=flat-square)]()
[![기간](https://img.shields.io/badge/기간-2025.09%20~%202026.06-F39C12?style=flat-square)]()

</div>

---

## 프로젝트 소개

반려동물 동반 여행 시 발생하는 **정보 분산**, **조건 불확실성**, **실제 이용 가능 여부 확인의 어려움**을 해결하기 위해,
AI 기반 여행 상담 챗봇과 위치 기반 서비스를 결합하여
반려동물과 보호자 모두에게 적합한 여행 정보를 제공하는 것을 목표로 합니다.

---

### 문제 흐름 (Motivation Flow)

| | 문제 | 설명 |
|---|---|---|
| **01** | **반려동물 양육 인구의 급증** | 2024년 기준 등록 반려동물 수 약 349만 마리, 응답자의 81.6%가 반려동물과 함께 여행한다고 답변 |
| **02** | **정보의 파편화** | 반려동물 동반 정보가 지도, 블로그, SNS 등 여러 플랫폼에 분산되어 있어 한 곳에서 수집하기 어려움 |
| **03** | **세부 정책 정보의 부재** | '반려견 동반 가능'으로 표기되어도 체중 제한·견종 제한·실내외 구역 등 세부 조건은 파악하기 어려움 |
| **04** | **맞춤 추천 기능의 부재** | 기존 서비스는 단순 목록 제공에 그쳐 반려동물의 크기·성향·건강 상태를 반영한 추천 불가 |
| **05** | **방문 실패 경험 반복** | 잘못된 정보를 믿고 방문했다가 입장 거부되는 실패 경험이 반복됨 |
| **06** | **MyPetTrip의 해결책** | 공공데이터 + 웹 크롤링 기반 신뢰성 있는 DB 구축 + GPT 챗봇 기반 반려동물 맞춤 추천 실현 |

---

### 💡 핵심 아이디어 (Core Idea)

| 문제 (Problem) | 인사이트 (Insight) | 우리의 해결책 (Our Solution) |
|---|---|---|
| 반려동물 동반 정보가 여러 플랫폼에 분산 | 공공데이터만으로는 세부 정책 확보 불가 | TourAPI + 웹 크롤링 다중 출처 통합 파이프라인 |
| 수집 정보의 신뢰도를 보장하기 어려움 | 출처·최신성·명확성으로 신뢰도 정량화 가능 | Confidence Score 기반 자동 검증 + NEEDS_REVIEW 시스템 |
| 기존 챗봇은 없는 장소를 지어내는 환각 문제 | RAG 구조로 환각을 구조적으로 차단 가능 | JSON 필터 기반 RAG — GPT는 조건 분석, 실제 추천은 DB 조회 결과로 |
| 모든 반려견에게 같은 장소를 추천 | 반려동물 프로필이 곧 맞춤 필터 | 앱에 등록된 프로필(크기·성향·맹견 여부 등)을 GPT 컨텍스트로 주입 |

---

## 주요 기능 (Key Features)

| # | 기능 | 설명 | 기술 |
|---|---|---|---|
| 1 | **반려동물 프로필 등록** | 이름·체중·크기·활동성·맹견 여부 등 개별 특성 데이터화 | Firestore, Flutter |
| 2 | **지도 기반 장소 탐색** | 현재 위치 중심 반려동물 친화 장소 시각화 및 조건 필터링 | Google Maps API, Geocoding API |
| 3 | **구조화된 장소 정보 제공** | 체중 제한·출입 구역·목줄 규정 등 세부 정책 명확히 표시 | TourAPI + 크롤링 통합 DB |
| 4 | **AI 챗봇 여행 상담** | 자연어 질의로 반려동물 맞춤 장소 추천 및 여행 코스 제안 | OpenAI GPT API, RAG 구조 |
| 5 | **선호 장소 저장·관리** | 마음에 드는 장소 북마크 및 개인 여행 리스트 관리 | Firestore, Flutter |

---

## 🏗️ 시스템 아키텍처 (System Architecture)

![System Architecture](https://github.com/ReturnZZero/return0/blob/main/docs/System%20Architecture.png)

---

##  핵심 기술 (Technical Highlights)

### 【기술 1】 다중 출처 데이터 통합 파이프라인

기존 서비스들이 사용자 리뷰에만 의존하는 한계를 극복하기 위해 **4개 출처를 통합**하는 파이프라인을 구축했습니다.

```
한국관광공사 TourAPI (정형 데이터)
        +
공식 홈페이지 · 인스타그램 · 네이버 블로그 · 카카오맵 후기 (비정형 데이터)
        ↓
GPT-4o-mini 기반 정형화 추출 (9개 핵심 필드: 체중제한, 견종제한, 실내허용 등)
        ↓
Confidence Score 산정 (출처 40% + 최신성 30% + 명확성 30%)
        ↓
충돌 감지 → NEEDS_REVIEW 자동 분류 → 관리자 검토 큐 등록
        ↓
고신뢰도 검증 DB (Firestore)
```
       
| 출처 | 신뢰도 가중치 |
|---|---|
| 공식 홈페이지 | 1.00 |
| 인스타그램 (공식 계정) | 0.85 |
| 네이버 블로그 | 0.55 |
| 카카오맵 후기 | 0.40 |

> **검증 결과** : Confidence Score 관리자 일치율 **89%** · NEEDS_REVIEW 전환 정확도 **91.3%** · gpt-4o 대비 mini 정확도 차이 **2.8%p** (비용 97% 절감)


---

### 【기술 2】 JSON 필터 기반 RAG 구조

일반 GPT 챗봇의 환각(Hallucination) 문제를 구조적으로 차단합니다.

```
사용자 자연어 질의  "OO이랑 가평에서 카페 추천해줘"
        ↓
GPT : 자연어 → JSON 필터 변환
{ mapX: 127.49, mapY: 37.83, petSize: "S", indoorAllowed: true, ... }
        ↓
Firestore DB 조회  (GPT가 장소를 직접 생성하지 않음 → 환각 차단)
        ↓
검증된 실존 장소 목록 반환 → 챗봇 화면 추천 카드 출력
```

---

### 【기술 3】 반려동물 프로필 컨텍스트 주입

동일한 질문이라도 반려동물의 특성에 따라 **완전히 다른 추천**이 제공됩니다.

| 필드 | 설명 | 적용 방식 |
|---|---|---|
| `petSize` | 소형·중형·대형견 구분 | Hard Filter — 체중 초과 장소 제외 |
| `isFierceDog` | 법정맹견 여부 | Hard Filter — 맹견 불가 장소 제외 |
| `activityLevel` | 활동성 (L / M / H) | Soft Ranking — 조용한 곳 vs 넓은 야외 우선 |
| `indoorAllowed` | 실내 이용 필수 여부 | Hard Filter |
| `travelChecklist` | 사용자 추가 선호 조건 | Soft Ranking |

---

## 기존 서비스와의 비교

| 비교 항목 | 네이버·카카오맵 | 반려동물 동반 앱 | MyPetTrip |
|---|---|---|---|
| 세부 정책 정보 (체중·견종·구역) |  미제공 | 일부 제공 | GPT 자동 추출로 표시 |
| 정보 검증 방식 |  사용자 리뷰 의존 | 검증 체계 없음 | 다중 출처 교차검증 |
| 정보 최신성 관리 |  사실상 방치 | 사실상 방치 | 이상감지 + 갱신 파이프라인 |
| 반려동물 특성 반영 |  없음 | 없음 | 프로필 기반 컨텍스트 주입 |
| 추천 방식 | 키워드 검색 | 조건 필터 직접 선택 | 자연어 챗봇 기반 RAG 추천 |

---

## 기대 효과 (Expected Impact)

| 관점 | 기대 효과 |
|---|---|
| **사용자** | 방문 실패 경험 감소 — 체중·견종·구역 등 세부 조건을 사전에 정확히 파악 |
| **사용자** | 여행 준비 시간 단축 — 자연어 한 문장으로 맞춤 장소 추천까지 원스톱 |
| **사용자** | 진정한 맞춤 추천 실현 — 대형견 보호자와 소형견 보호자에게 서로 다른 최적 장소 추천 |
| **기술** | LLM을 데이터 정제 엔진으로 활용하는 실용적 파이프라인 구현 사례 제시 |
| **기술** | 도메인 특화 RAG 구조를 통한 LLM 환각 문제의 공학적 해결 |
| **기술** | 공공데이터와 민간 비정형 데이터의 이종 데이터 통합(Data Fusion) 실현 |

---

## 향후 계획 (Future Plans)

1. **반려동물 동반 장소 데이터 확장**
2. **리뷰 및 커뮤니티 기능 추가** 
3. **이상 감지 고도화** — 사용자 신고·트래픽 급감·부정 키워드 기반 이상 감지 시스템 구축
4. **챗봇 응답 정확도 개선** — 대화 중 사회성·소음 민감도·건강 상태 동적 추출 고도화
5. **최종 데모 및 서비스 완성** — 2026년 6월 캡스톤 최종 발표

---

## 🛠️ 기술 스택 (Tech Stack)

| 분류 | 기술 |
|---|---|
| **Mobile App** | Flutter (Dart) |
| **Backend** | Firebase Authentication, Firestore Database |
| **AI / NLP** | OpenAI GPT-4o-mini API |
| **Data Pipeline** | Python, BeautifulSoup, Naver Search API |
| **Maps** | Google Maps API, Google Geocoding API |
| **Public Data** | 한국관광공사 TourAPI 4.0 |

---

## 📁 레포지토리 구조

```
return0/
├── 📁 26-1 GROWTH/              # Flutter 앱 소스코드
│   ├── android/
│   ├── assets/
│   ├── ios/
│   ├── lib/                     # 앱 핵심 코드 (screens, services, models)
│   ├── linux/
│   ├── macos/
│   ├── test/
│   ├── web/
│   ├── windows/
│   ├── pubspec.yaml
│   └── pubspec.lock
├── 📁 pet-policy-crawler/       # 반려견 정책 크롤링 파이프라인
│   ├── crawlers.py
│   ├── extractor.py
│   ├── db_writer.py
│   ├── pipeline.py
│   ├── requirements.txt
│   └── README.md
├── 📁 docs/                     # 발표자료 및 보고서
├── GroundRules.md
└── README.md
```

---

## 🚀 실행 및 재현 방법 (Install / Build / Run / Test)

본 프로젝트는 **Flutter 기반 모바일 앱**과 **Python 기반 데이터 파이프라인**으로 구성되어 있습니다.  
아래 절차를 따르면 GitHub Repository를 clone한 뒤 프로젝트를 설치하고 실행할 수 있습니다.

---

### 1. Repository Clone

```bash
git clone https://github.com/ReturnZZero/return0.git
cd return0
```

---

### 2. Flutter App 설치 방법 (How to Install)

Flutter 앱 실행에 필요한 패키지를 설치합니다.

```bash
cd "26-1 GROWTH"
flutter pub get
```

Flutter가 설치되어 있지 않은 경우, 먼저 Flutter SDK를 설치해야 합니다.  
본 프로젝트는 **Flutter**와 **Dart** 기반으로 개발되었습니다.

---

### 3. Flutter App 빌드 방법 (How to Build)

Android APK 파일을 생성하려면 다음 명령어를 실행합니다.

```bash
cd "26-1 GROWTH"
flutter build apk
```

iOS 빌드는 macOS와 Xcode 환경에서 가능합니다.

```bash
cd "26-1 GROWTH"
flutter build ios
```

---

### 4. Flutter App 실행 방법 (How to Run)

연결된 emulator 또는 실제 기기에서 앱을 실행합니다.

```bash
cd "26-1 GROWTH"
flutter run
```

앱 실행 전 Firebase 및 Google Maps API 설정이 필요합니다.

| 플랫폼 | 필요한 파일 |
|---|---|
| Android | `android/app/google-services.json` |
| iOS | `ios/Runner/GoogleService-Info.plist` |
| Flutter | `lib/firebase_options.dart` |

> 보안상의 이유로 실제 Firebase 설정 파일과 API Key는 GitHub에 업로드하지 않습니다.  
> 재현이 필요한 경우, 별도의 Firebase 프로젝트를 생성한 뒤 위 설정 파일을 추가해야 합니다.

---

### 5. 환경변수 설정 (Environment Variables)

본 프로젝트는 외부 API 사용을 위해 API Key 설정이 필요합니다.  
Repository에 포함된 `.env.example` 파일을 참고하여 `.env` 파일을 생성합니다.

```bash
cp .env.example .env
```

`.env` 파일에는 다음과 같은 값이 필요합니다.

```env
OPENAI_API_KEY=your_openai_api_key
NAVER_CLIENT_ID=your_naver_client_id
NAVER_CLIENT_SECRET=your_naver_client_secret
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
TOUR_API_KEY=your_tour_api_key
```

> 실제 API Key는 개인정보 및 보안 문제로 GitHub에 업로드하지 않습니다.

---

### 6. 데이터 파이프라인 설치 방법

반려동물 동반 정책 정보를 수집하고 정형화하는 Python 기반 데이터 파이프라인은  
`pet-policy-crawler` 폴더에 포함되어 있습니다.

```bash
cd pet-policy-crawler
pip install -r requirements.txt
```

---

### 7. 데이터 파이프라인 실행 방법

크롤링 및 정책 추출 파이프라인을 실행하려면 다음 명령어를 사용합니다.

```bash
cd pet-policy-crawler
python pipeline.py
```

파이프라인은 TourAPI, 웹 문서, 블로그 등의 정보를 기반으로  
반려동물 동반 가능 여부와 세부 정책 정보를 추출합니다.

추출된 데이터는 구조화된 형태로 변환된 뒤  
Firestore DB에 저장되거나 JSON 파일 형태로 확인할 수 있습니다.

---

### 8. 테스트 방법 (How to Test)

#### Flutter App 테스트

```bash
cd "26-1 GROWTH"
flutter run
```

앱 실행 후 다음 항목을 확인합니다.

| 테스트 항목 | 확인 내용 |
|---|---|
| 반려동물 프로필 등록 | 이름, 크기, 활동성, 맹견 여부 등이 정상적으로 저장되는지 확인 |
| 지도 화면 | 반려동물 동반 장소 목록이 지도에 표시되는지 확인 |
| 장소 상세 페이지 | 체중 제한, 실내 동반 가능 여부, 목줄 착용 여부 등이 표시되는지 확인 |
| AI 챗봇 | 자연어 질문 입력 시 Firestore DB 기반 추천 결과가 출력되는지 확인 |

AI 챗봇 예시 질문은 다음과 같습니다.

```text
소형견이랑 실내 이용 가능한 카페 추천해줘
```

---

#### 데이터 파이프라인 테스트

```bash
cd pet-policy-crawler
python pipeline.py
```

실행 후 장소 정책 데이터가 정상적으로 추출되는지 확인합니다.

| 확인 항목 | 설명 |
|---|---|
| 장소명 | 장소 이름이 정상적으로 수집되었는지 확인 |
| 주소 | 장소 주소가 포함되어 있는지 확인 |
| 반려동물 동반 가능 여부 | 동반 가능 여부가 추출되었는지 확인 |
| 체중 제한 | 소형견, 중형견, 대형견 제한 정보가 추출되었는지 확인 |
| 실내 동반 가능 여부 | 실내 또는 테라스 이용 가능 여부가 구분되는지 확인 |
| 신뢰도 점수 | Confidence Score가 계산되는지 확인 |
| 검토 상태 | NEEDS_REVIEW 여부가 분류되는지 확인 |

---

## 🧪 샘플 데이터 (Sample Data)

본 프로젝트는 반려동물 동반 장소 추천을 위해 장소 데이터가 필요합니다.  
실제 서비스 데이터는 Firestore DB에 저장되며, GitHub Repository에는 재현 및 테스트를 위한 샘플 데이터를 포함합니다.

샘플 데이터 경로는 다음과 같습니다.

```text
pet-policy-crawler/sample_data/sample_places.json
```

샘플 데이터는 다음과 같은 필드를 포함합니다.

| 필드 | 설명 |
|---|---|
| `name` | 장소명 |
| `category` | 장소 분류 |
| `address` | 주소 |
| `mapX` | 경도 |
| `mapY` | 위도 |
| `petSize` | 허용 반려견 크기 |
| `indoorAllowed` | 실내 동반 가능 여부 |
| `leashRequired` | 목줄 착용 필요 여부 |
| `isFierceDogAllowed` | 맹견 동반 가능 여부 |
| `sourceUrl` | 정보 출처 |
| `confidenceScore` | 데이터 신뢰도 점수 |
| `reviewStatus` | 관리자 검토 상태 |

---

## 🗄️ 데이터베이스 구조 (Database Structure)

본 프로젝트는 Firebase Firestore를 사용하여 사용자, 반려동물, 장소, 북마크, 챗봇 기록 데이터를 저장합니다.

| Collection | 설명 |
|---|---|
| `users` | 사용자 계정 및 기본 정보 |
| `pets` | 반려동물 프로필 정보 |
| `places` | 반려동물 동반 장소 정보 |
| `bookmarks` | 사용자가 저장한 관심 장소 |
| `chatLogs` | 챗봇 질문 및 추천 기록 |
| `reviewQueue` | NEEDS_REVIEW 상태의 관리자 검토 대상 데이터 |

### places Collection 예시

```json
{
  "contentId": "00000031",
  "title": "보틀라운지",
  "addr1": "서울 서대문구 홍연길 26 1층",
  "tel": "070-5147-8332",
  "firstimage": "https://firebasestorage.googleapis.com/v0/b/mypettrip-6bf55.firebasestorage.app/o/%E1%84%87%E1%85%A9%E1%84%90%E1%85%B3%E1%86%AF%E1%84%85%E1%85%A1%E1%84%8B%E1%85%AE%E1%86%AB%E1%84%8C%E1%85%B5.jpeg?alt=media&token=9ffe4224-4e7d-4d7a-bc8f-b851384e6285",
  "updateDate": "20260507",
  "addr2": "",
  "mapX": 126.928474475085,
  "mapY": 37.575182819531,
  "lclsSystm1": "FD",
  "placeType": "FD",
  "seedRegionSidoCode": "11",
  "seedRegionSidoName": "서울특별시",
  "seedRegionSigunguCode": "410",
  "seedRegionSigunguName": "서대문구",
  "overview": "",
  "homepage": "",
  "reviewCount": 0,
  "isFierceDog": false,
  "indoorAllowed": true,
  "outdoorOnly": false,
  "parkingAvailable": false,
  "leashRequired": false,
  "petSize": "L",
  "travelChecklist": []
}
```

---

## 🔗 사용한 오픈소스 및 외부 API

| 이름 | 사용 목적 |
|---|---|
| Flutter | 모바일 앱 UI 및 클라이언트 개발 |
| Dart | Flutter 앱 개발 언어 |
| Firebase Authentication | 사용자 로그인 및 인증 관리 |
| Cloud Firestore | 사용자, 반려동물, 장소 데이터 저장 |
| Google Maps API | 지도 표시 및 장소 위치 시각화 |
| Google Geocoding API | 주소와 좌표 변환 |
| OpenAI GPT-4o-mini API | 자연어 질의를 구조화된 JSON 필터로 변환 |
| 한국관광공사 TourAPI 4.0 | 기초 관광지 및 장소 데이터 수집 |
| Python | 데이터 수집 및 정제 파이프라인 구현 |
| BeautifulSoup | 웹 페이지 내 반려동물 동반 정책 정보 추출 |
| Naver Search API | 블로그 및 웹 문서 기반 장소 정보 탐색 |

---

## 📄 Poster Session
![Poster](https://github.com/ReturnZZero/return0/blob/main/docs/%E1%84%8C%E1%85%A9%E1%86%AF%E1%84%91%E1%85%B3%20%E1%84%91%E1%85%A9%E1%84%89%E1%85%B3%E1%84%90%E1%85%A5%E1%84%89%E1%85%A6%E1%84%89%E1%85%A7%E1%86%AB.png)

---

## 📎 관련 문서 (Documents)

| 문서 | 링크 |
|---|---|
| 중간발표 자료 | [📄 중간발표 발표자료](https://github.com/ReturnZZero/return0/blob/main/docs/25-return%200%3B-%E1%84%8C%E1%85%AE%E1%86%BC%E1%84%80%E1%85%A1%E1%86%AB%E1%84%87%E1%85%A1%E1%86%AF%E1%84%91%E1%85%AD%20%E1%84%87%E1%85%A1%E1%86%AF%E1%84%91%E1%85%AD%E1%84%8C%E1%85%A1%E1%84%85%E1%85%AD.pdf) |
| 1차 보고서 | [📄 1차 보고서](https://github.com/ReturnZZero/return0/blob/main/docs/25-return0%3B-1%E1%84%8E%E1%85%A1%E1%84%87%E1%85%A9%E1%84%80%E1%85%A9%E1%84%89%E1%85%A5.pdf) |
| 기말 보고서 | [📄 2차 보고서](https://github.com/ReturnZZero/return0/blob/bb3be48de20d49d8b8d618be0bce459dd3b6a9e3/docs/25-return%200%3B-2%EC%B0%A8%20%EB%B3%B4%EA%B3%A0%EC%84%9C.pdf) |
| 최종 보고서 | [📄 최종 보고서](docs/25-return0;-최종보고서-유예나.pdf) |

---

## 👩‍💻 팀원 소개 (Team Members)

| 이름 | 역할 | 학번 | 담당 |
|---|---|---|---|
| **유예나** | 팀장 | 2076260 | 전체 시스템 설계 · DB 설계 · Firebase 백엔드 · Mobile App |
| **계예진** | PM | 2017003 | UI·UX 설계 · Flutter 모바일 앱 개발 |
| **민성원** | AI | 2076133 | AI 여행 상담 로직 · 데이터 파이프라인 · 백엔드 연동 |

> 지도교수 : **심재형 교수님** | 이화여자대학교 컴퓨터공학과 캡스톤디자인 2026-1 (산학 트랙 · 팀 25)

---

© 2025-2026 Team return 0; — 이화여자대학교 컴퓨터공학과

