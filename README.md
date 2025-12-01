# Team 25 - return 0;
### 25-2 컴퓨터공학과 졸업 프로젝트 · return 0; 레포지토리
### 과제 내용은 `START` 폴더 아래 정리되어 있습니다.

---

# Ⅰ. 팀 소개
- **팀 명**: return 0;
- **팀 원**: 유예나(2076260), 민성원(2076133), 계예진(2017003)

---

# Ⅱ. 프로젝트 개요
- **프로젝트명**: MyPetTrip — AI 기반 반려동물 맞춤 여행지 추천 서비스  
- **프로젝트 기간**: 2025년 9월 ~ 2025년 12월  
- **기획 목적**:  
  반려인이 반려동물과 함께 여행할 때 겪는 정보 분산, 조건 불확실성, 장소 검증 어려움 등 현실적인 문제를 해결하고,  
  **AI 추천 + 위치 기반 데이터(LBS)**를 활용해 반려동물 맞춤형 여행 경험을 제공하는 것을 목표로 한다.

---

# Ⅲ. 해결 방안 및 서비스 방향

### ✔ 핵심 기능
- **AI 기반 개인 맞춤 여행지 추천**
  - 반려동물 크기·나이·성향(소음 민감, 사회성, 활동성 등) 기반 추천  
- **조건 기반 필터링**
  - 대형견 가능 여부 / 실내·실외 동반 가능 / 소음 환경 / 계단 여부 등  
- **신뢰성 있는 장소 정보 표준화**
  - 흩어진 정보를 수집·정리하여 반려인 입장에서 필요한 세부 정책을 구조화  
- **커뮤니티 및 후기 기반 보조 정보**
  - 실제 반려인이 남긴 후기·사진 기반 신뢰도 확보  

---

# Ⅳ. 시스템 설계 및 기술 스택

### ✔ 시스템 구성
MyPetTrip은 아래 3계층 구조로 동작하도록 설계되었다.

1. **Frontend (Flutter)**  
   - Android/iOS 동시 개발  
   - Kakao Map API 기반 위치 탐색 및 필터 UI  

2. **Backend (Firebase, FastAPI)**  
   - Firebase Authentication: 사용자 인증  
   - Firestore(NoSQL): 사용자/반려동물/장소/리뷰 데이터 저장  
   - FastAPI: AI 추천 서버 (Google Cloud Run 배포 예정)  

3. **AI Recommendation Engine**  
   - Scikit-learn 기반 Cosine Similarity 추천  
   - LightGBM 기반 랭킹 모델 구조 설계  
   - NumPy·Pandas 기반 데이터 벡터화 및 전처리  

### ✔ 기술 스택 요약
- **Frontend:** Flutter, Dart  
- **Backend:** Firebase Auth, Firestore, Cloud Functions  
- **AI:** Python, NumPy, Pandas, Scikit-learn, LightGBM  
- **Infra:** Google Cloud Run  
- **External API:** Kakao Map API  

---

# Ⅴ. 기대 효과 및 향후 계획

### ✔ 기대 효과
- 반려동물 동반 가능 정보의 파편화 문제 해소  
- 반려동물 특성 기반 맞춤형 추천 제공  
- 신뢰성 높은 여행 정보를 빠르게 탐색 가능  
- 반려인 중심 커뮤니티 형성을 통한 지속적 정보 축적  

### ✔ 향후 계획
1. 반려동물 동반 장소 데이터 확장  
2. LightGBM 기반 개인화 추천 고도화  
3. 리뷰·커뮤니티 기능 강화  
4. 프로토타입 고도화 및 사용자 테스트 진행  
5. 학기말 데모 및 최종 보고서 제출 준비  

---

# Ⅵ. 페르소나 요약

### ✔ 김하은 (25세, 대학원생, 소형견 보호자)
- **Pain Point**: 동반 가능 여부 불확실, 리뷰 정보 노후, 가성비 탐색 어려움  
- **Needs**: 신뢰성 있는 조건 정리, 저렴한 숙소/카페 추천, 까다로운 조건 미리 확인  

### ✔ 오준석 (48세, 강사, 대형견 보호자)
- **Pain Point**: 대형견 가능한 장소 부족, 검색 시간 소모, 현장 도착 후 출입 거절 경험  
- **Needs**: 대형견 맞춤 추천, 간단하고 직관적인 UI, 가족 모두 쉽게 사용할 서비스  

---

# 📁 Repository Structure
/app # Flutter 앱 구조 초안
/backend # FastAPI 추천 서버 코드
/ai_prototype # Cosine Similarity 기반 AI 추천 프로토타입
/data # 장소/반려동물 데이터 및 전처리 스크립트
/docs # 기획안, 설계 자료, 보고서 초안
/START # 과제 제출물 정리 폴더
README.md # Repository 설명 문서


