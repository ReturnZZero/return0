
import os
import json
import logging
from dataclasses import dataclass
from typing import Optional
from dotenv import load_dotenv
 
from crawlers  import crawl_all_sources
from extractor import GPTExtractor, compute_confidence, aggregate_and_review
from db_writer import upsert_extraction, upsert_place_policy
 
load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)
 
@dataclass
class PlaceTarget:
    place_id:          str
    place_name:        str
    official_url:      Optional[str] = None
    instagram_handle:  Optional[str] = None
    kakao_place_id:    Optional[str] = None
 
def run_pipeline_for_place(target: PlaceTarget, dry_run: bool = False):
    """
    단일 장소에 대해 전체 파이프라인 실행
    dry_run=True 이면 Firestore 저장을 건너뛰고 결과를 출력만 함
    """
    logger.info(f"━━━ 파이프라인 시작: {target.place_name} ({target.place_id}) ━━━")
 
    raw_docs = crawl_all_sources(
        place_id         = target.place_id,
        place_name       = target.place_name,
        official_url     = target.official_url,
        instagram_handle = target.instagram_handle,
        kakao_place_id   = target.kakao_place_id,
    )
 
    if not raw_docs:
        logger.warning(f"크롤링 결과 없음: {target.place_name}")
        return
 
    extractor    = GPTExtractor()
    extractions  = []
 
    for doc in raw_docs:
        extraction = extractor.extract(doc)
        if extraction is None:
            logger.warning(f"GPT 추출 실패: {doc.source_url}")
            continue
 
            extraction = compute_confidence(extraction)
        logger.info(
            f"[Confidence] {doc.source_type} | score={extraction.confidence_score:.3f} "
            f"(출처={extraction.score_breakdown['source_score']:.2f}, "
            f"최신={extraction.score_breakdown['recency_score']:.2f}, "
            f"명확={extraction.score_breakdown['clarity_score']:.2f})"
        )
        extractions.append(extraction)
 
        if not dry_run:
            upsert_extraction(extraction)
 
    if not extractions:
        logger.error(f"유효한 추출 결과 없음: {target.place_name}")
        return
 
    review_status = aggregate_and_review(extractions)
 
    if review_status.needs_review:
        logger.warning(
            f"⚠️  NEEDS_REVIEW: {target.place_name}\n"
            + "\n".join(f"  • {r}" for r in review_status.reasons)
        )
    else:
        logger.info(f"정책 정상: {target.place_name}")
 
    if dry_run:
        print("\n[DRY RUN] 최종 결과:")
        print(json.dumps(review_status.merged_policy, ensure_ascii=False, indent=2))
        print("NEEDS_REVIEW:", review_status.needs_review)
        print("Reasons:", review_status.reasons)
    else:
        upsert_place_policy(review_status)
 
    logger.info(f"━━━ 파이프라인 완료: {target.place_name} ━━━\n")
    return review_status
 
def run_batch(places: list[PlaceTarget], dry_run: bool = False):
    results = []
    for place in places:
        try:
            result = run_pipeline_for_place(place, dry_run=dry_run)
            results.append(result)
        except Exception as e:
            logger.error(f"파이프라인 오류: {place.place_name} — {e}", exc_info=True)
    return results
 
if __name__ == "__main__":
    # 테스트용 장소 목록 (실제 운영 시 DB에서 로드)
    sample_places = [
        PlaceTarget(
            place_id         = "cafe_001",
            place_name       = "강아지와 카페",
            official_url     = "https://example-cafe.com",
            instagram_handle = "example_cafe_dog",
            kakao_place_id   = "12345678",
        ),
    ]
 
    run_batch(sample_places, dry_run=True)