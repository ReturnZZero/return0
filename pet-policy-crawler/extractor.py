
import os
import json
import logging
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Optional
from openai import OpenAI

from crawlers import RawDocument, SourceType

logger = logging.getLogger(__name__)


@dataclass
class PolicyExtraction:
    place_id:          str
    place_name:        str
    source_type:       SourceType
    source_url:        str
    crawled_at:        datetime

    pet_allowed:       Optional[bool]  = None
    weight_limit_kg:   Optional[float] = None
    breed_restriction: Optional[str]   = None
    indoor_allowed:    Optional[bool]  = None
    outdoor_allowed:   Optional[bool]  = None
    leash_required:    Optional[bool]  = None
    carrier_required:  Optional[bool]  = None
    extra_notes:       Optional[str]   = None

    confidence_score:  float = 0.0
    score_breakdown:   dict  = field(default_factory=dict)


# 출처별 맞춤 source_hint
_SOURCE_HINTS = {
    SourceType.OFFICIAL_WEB: (
        "아래는 반려견 동반 가능 시설의 공식 홈페이지에서 수집한 텍스트입니다.\n"
        "공식 정책이 명시된 경우 정확히 추출하고, 언급이 없으면 null로 두세요.\n"
        "수치(kg 등)가 명시된 경우 반드시 숫자로 추출하세요."
    ),
    SourceType.INSTAGRAM_BIO: (
        "아래는 반려견 동반 가능 시설의 인스타그램 프로필 소개란(bio) 텍스트입니다.\n"
        "간결한 소개문에서 반려견 관련 조건을 최대한 추출하세요."
    ),
    SourceType.INSTAGRAM_POST: (
        "아래는 반려견 동반 가능 시설의 인스타그램 공식 포스트 캡션 텍스트입니다.\n"
        "사업자가 직접 공지한 반려견 정책 조건만 추출하세요.\n"
        "홍보성 문구, 이벤트 안내, 해시태그는 무시하세요."
    ),
    SourceType.NAVER_BLOG: (
        "아래는 네이버 블로그 방문 후기 텍스트입니다.\n"
        "방문자가 직접 경험한 반려견 관련 정책 정보만 추출하세요.\n"
        "주관적 감상(좋았어요, 분위기 최고 등)은 무시하세요.\n"
        "정책 변경 가능성이 있는 표현(예전엔 됐는데, 바뀐 것 같아요)이 있으면 extra_notes에 기록하세요."
    ),
    SourceType.REVIEW: (
        "아래는 카카오맵 등의 방문 후기 텍스트입니다.\n"
        "반려견 동반 관련 조건 정보만 추출하세요. 불명확한 경우 null로 두세요."
    ),
}

_POLICY_JSON_SCHEMA = """{
  "place_name":        string or null,  // 장소명
  "pet_allowed":       boolean or null, // 반려견 동반 가능 여부
  "weight_limit_kg":   number or null,  // 체중 제한 (kg, 예: 7.0)
  "breed_restriction": string or null,  // 견종 제한 내용
  "indoor_allowed":    boolean or null, // 실내 입장 가능
  "outdoor_allowed":   boolean or null, // 실외/테라스 입장 가능
  "leash_required":    boolean or null, // 목줄 필수 여부
  "carrier_required":  boolean or null, // 이동가방/케이지 필수
  "extra_notes":       string or null   // 기타 조건
}"""

_POLICY_EXTRACTION_RULES = """[추출 규칙]
1. 텍스트에 명확히 언급된 정보만 추출하세요. 추측하거나 유추하지 마세요.
2. 모호하거나 불확실한 경우 반드시 null을 사용하세요.
3. 반려견 관련 정보가 전혀 없으면 모든 필드를 null로 반환하세요.
4. 체중 제한은 반드시 숫자(kg)로만 추출하세요.
   예) '소형견(7kg 이하)' → weight_limit_kg: 7.0
   예) '대형견도 가능' → weight_limit_kg: null (상한 불명확)
5. breed_restriction은 원문 표현을 그대로 보존하세요.
   법정맹견 여부가 명시된 경우 반드시 포함하세요.
6. pet_allowed 판단 기준:
   true:  '반려견 동반 가능', '애견 동반 ok', '펫 프렌들리' 등 명확한 허용 표현
   false: '반려견 불가', '애완동물 출입 금지', '폐업' 등 명확한 불가 표현
   null:  언급 없음 또는 조건부('사전 문의 필요' 등)
7. 광고성 표현, 주관적 감상, 홍보 문구는 무시하세요.
8. AI가 생성한 것으로 의심되는 반복적·비구체적 텍스트는 관련 필드를 null로 처리하세요."""


class GPTExtractor:
    """RawDocument를 GPT API로 정책 구조화한다. temperature=0.0으로 결정론적 추출."""

    def __init__(self, model: str = "gpt-4o-mini"):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY", ""))
        self.model  = model

    def extract(self, doc: RawDocument) -> Optional[PolicyExtraction]:
        if not self.client.api_key:
            logger.warning("OPENAI_API_KEY 미설정")
            return None

        source_hint = _SOURCE_HINTS.get(
            doc.source_type,
            "아래 텍스트에서 반려견 관련 정책 정보를 추출하세요."
        )
        system_prompt = (
            "당신은 반려견 동반 시설의 정책 정보를 텍스트에서 정확하게 추출하는 "
            "데이터 파이프라인 전문가입니다.\n"
            f"{source_hint}\n\n"
            "[출력 형식]\n"
            "아래 JSON 스키마에 맞게 반드시 순수 JSON만 반환하세요.\n"
            "마크다운 코드블록(```), 설명 문장, 전문(preamble)을 절대 포함하지 마세요.\n\n"
            f"{_POLICY_JSON_SCHEMA}\n\n"
            f"{_POLICY_EXTRACTION_RULES}"
        )
        place_hint = (
            f"장소명: {doc.place_name}\n\n"
            if doc.place_name
            else "장소명은 텍스트에서 직접 추출해주세요.\n\n"
        )
        user_prompt = f"{place_hint}텍스트:\n{doc.raw_text}"

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user",   "content": user_prompt},
                ],
                temperature=0.0,
                max_tokens=600,
            )
            raw_json = response.choices[0].message.content.strip()
            raw_json = (
                raw_json
                .removeprefix("```json")
                .removeprefix("```")
                .removesuffix("```")
                .strip()
            )
            data = json.loads(raw_json)

        except json.JSONDecodeError as e:
            logger.error(f"GPT 응답 JSON 파싱 실패: {e}")
            return None
        except Exception as e:
            logger.error(f"GPT API 호출 실패: {e}")
            return None

        return PolicyExtraction(
            place_id          = doc.place_id,
            place_name        = data.get("place_name") or doc.place_name,
            source_type       = doc.source_type,
            source_url        = doc.source_url,
            crawled_at        = doc.crawled_at,
            pet_allowed       = data.get("pet_allowed"),
            weight_limit_kg   = data.get("weight_limit_kg"),
            breed_restriction = data.get("breed_restriction"),
            indoor_allowed    = data.get("indoor_allowed"),
            outdoor_allowed   = data.get("outdoor_allowed"),
            leash_required    = data.get("leash_required"),
            carrier_required  = data.get("carrier_required"),
            extra_notes       = data.get("extra_notes"),
        )


# Confidence Score

WEIGHT_SOURCE  = 0.40
WEIGHT_RECENCY = 0.30
WEIGHT_CLARITY = 0.30

_SOURCE_BASE_SCORES = {
    SourceType.OFFICIAL_WEB:   1.00,
    SourceType.INSTAGRAM_BIO:  0.85,
    SourceType.INSTAGRAM_POST: 0.80,
    SourceType.NAVER_BLOG:     0.55,
    SourceType.REVIEW:         0.40,
}

MAX_STALENESS_DAYS = 365 * 2


def _source_score(source_type: SourceType) -> float:
    return _SOURCE_BASE_SCORES.get(source_type, 0.30)


def _recency_score(crawled_at: datetime) -> float:
    delta = (datetime.utcnow() - crawled_at).days
    if delta <= 0:
        return 1.0
    if delta >= MAX_STALENESS_DAYS:
        return 0.0
    return 1.0 - (delta / MAX_STALENESS_DAYS)


def _clarity_score(ext: PolicyExtraction) -> float:
    """핵심 정책 필드 채움 비율. pet_allowed는 가중치 2배."""
    fields = {
        "pet_allowed": 2, "weight_limit_kg": 1, "breed_restriction": 1,
        "indoor_allowed": 1, "outdoor_allowed": 1,
        "leash_required": 0.5, "carrier_required": 0.5, "extra_notes": 0.5,
    }
    total  = sum(fields.values())
    filled = sum(w for f, w in fields.items() if getattr(ext, f) is not None)
    return filled / total


def compute_confidence(ext: PolicyExtraction) -> PolicyExtraction:
    s = _source_score(ext.source_type)
    r = _recency_score(ext.crawled_at)
    c = _clarity_score(ext)

    ext.confidence_score = round(WEIGHT_SOURCE * s + WEIGHT_RECENCY * r + WEIGHT_CLARITY * c, 4)
    ext.score_breakdown  = {
        "source_score":  round(s, 4),
        "recency_score": round(r, 4),
        "clarity_score": round(c, 4),
        "weights": {"source": WEIGHT_SOURCE, "recency": WEIGHT_RECENCY, "clarity": WEIGHT_CLARITY},
    }
    return ext


# 충돌 감지 & NEEDS_REVIEW 판정

NEEDS_REVIEW_THRESHOLD = 0.45

CONFLICT_FIELDS = ["pet_allowed", "weight_limit_kg", "indoor_allowed", "outdoor_allowed"]

_SOURCE_PRIORITY = {
    SourceType.OFFICIAL_WEB:   0,
    SourceType.INSTAGRAM_BIO:  1,
    SourceType.INSTAGRAM_POST: 2,
    SourceType.NAVER_BLOG:     3,
    SourceType.REVIEW:         4,
}


@dataclass
class PlaceReviewStatus:
    place_id:        str
    place_name:      str
    needs_review:    bool
    reasons:         list[str]
    merged_policy:   dict
    all_extractions: list[dict]


def aggregate_and_review(extractions: list[PolicyExtraction]) -> PlaceReviewStatus:
    if not extractions:
        return PlaceReviewStatus(
            place_id="", place_name="", needs_review=True,
            reasons=["추출 결과 없음"], merged_policy={}, all_extractions=[]
        )

    reasons = []

    for ext in extractions:
        if ext.confidence_score < NEEDS_REVIEW_THRESHOLD:
            reasons.append(
                f"낮은 confidence ({ext.confidence_score:.2f}) "
                f"from {ext.source_type} — {ext.source_url}"
            )

    for field_name in CONFLICT_FIELDS:
        values = [
            (getattr(e, field_name), e.source_type, e.crawled_at)
            for e in extractions if getattr(e, field_name) is not None
        ]
        if len(values) < 2:
            continue
        if len(set(v[0] for v in values)) > 1:
            newest, *rest = sorted(values, key=lambda x: x[2], reverse=True)
            older = [v for v in rest if v[0] != newest[0]]
            if older:
                msg = (
                    f"[충돌] '{field_name}': "
                    f"최신({newest[1]}, {newest[2].date()}) = {newest[0]} vs "
                    f"이전({older[0][1]}, {older[0][2].date()}) = {older[0][0]}"
                )
                reasons.append(msg)
                logger.warning(msg)

    best = sorted(
        extractions,
        key=lambda e: (_SOURCE_PRIORITY.get(e.source_type, 9), -e.crawled_at.timestamp())
    )[0]

    merged_policy = {
        "pet_allowed":       best.pet_allowed,
        "weight_limit_kg":   best.weight_limit_kg,
        "breed_restriction": best.breed_restriction,
        "indoor_allowed":    best.indoor_allowed,
        "outdoor_allowed":   best.outdoor_allowed,
        "leash_required":    best.leash_required,
        "carrier_required":  best.carrier_required,
        "extra_notes":       best.extra_notes,
        "best_source":       best.source_type,
        "best_confidence":   best.confidence_score,
        "updated_at":        datetime.utcnow().isoformat(),
    }

    return PlaceReviewStatus(
        place_id        = extractions[0].place_id,
        place_name      = extractions[0].place_name,
        needs_review    = len(reasons) > 0,
        reasons         = reasons,
        merged_policy   = merged_policy,
        all_extractions = [asdict(e) for e in extractions],
    )