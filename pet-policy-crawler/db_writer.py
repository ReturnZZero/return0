
import os
import logging
from datetime import datetime
from dataclasses import asdict
 
import hashlib
import firebase_admin
from firebase_admin import credentials, firestore
 
from extractor import PolicyExtraction, PlaceReviewStatus
 
logger = logging.getLogger(__name__)
 
_db = None
 
def get_db():
    global _db
    if _db is not None:
        return _db
 
    if not firebase_admin._apps:
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
        else:
            # 환경변수로 인증 정보 전달 시 (CI/CD 환경)
            cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
 
    _db = firestore.client()
    return _db
 
# places/{place_id}
#   ├── policy (merged, 최종 정책)
#   ├── status ("OK" | "NEEDS_REVIEW")
#   ├── needs_review_reasons: []
#   └── raw_extractions/{source_type}_{url_hash}
#         └── PolicyExtraction 전체
#
# admin_review_queue/{place_id}
#   ├── place_name
#   ├── reasons: []
#   ├── queued_at
#   └── resolved: false
 
def upsert_extraction(extraction: PolicyExtraction):
    """개별 PolicyExtraction을 Firestore에 저장"""
    db = get_db()
    url_hash = hashlib.md5(extraction.source_url.encode()).hexdigest()[:8]
    doc_id   = f"{extraction.source_type}_{url_hash}"
 
    data = asdict(extraction)
    # datetime → ISO string 변환
    data["crawled_at"]  = extraction.crawled_at.isoformat()
    data["source_type"] = extraction.source_type.value
 
    db.collection("places").document(extraction.place_id)\
      .collection("raw_extractions").document(doc_id)\
      .set(data, merge=True)
 
    logger.info(f"[Firestore] raw_extraction upsert: {extraction.place_id}/{doc_id}")
 
def upsert_place_policy(review_status: PlaceReviewStatus):
    """
    집계된 정책 + 상태를 places/{place_id} 문서에 Upsert
    NEEDS_REVIEW이면 관리자 큐에도 등록
    """
    db = get_db()
 
    status_str = "NEEDS_REVIEW" if review_status.needs_review else "OK"
 
    place_data = {
        "place_id":             review_status.place_id,
        "place_name":           review_status.place_name,
        "status":               status_str,
        "needs_review_reasons": review_status.reasons,
        "policy":               review_status.merged_policy,
        "last_crawled_at":      datetime.utcnow().isoformat(),
    }
 
    db.collection("places").document(review_status.place_id).set(place_data, merge=True)
    logger.info(f"[Firestore] place upsert: {review_status.place_id} → {status_str}")
 
    if review_status.needs_review:
        _enqueue_admin_review(db, review_status)
 
def _enqueue_admin_review(db, review_status: PlaceReviewStatus):
    """관리자 검토 큐에 등록 (이미 등록된 경우 이유만 업데이트)"""
    queue_ref = db.collection("admin_review_queue").document(review_status.place_id)
    existing  = queue_ref.get()
 
    if existing.exists and not existing.to_dict().get("resolved", True):
        # 이미 미해결 큐에 존재 → 이유 업데이트만
        queue_ref.update({
            "reasons":    review_status.reasons,
            "updated_at": datetime.utcnow().isoformat(),
        })
        logger.info(f"[AdminQueue] 기존 큐 업데이트: {review_status.place_id}")
    else:
        queue_ref.set({
            "place_id":   review_status.place_id,
            "place_name": review_status.place_name,
            "reasons":    review_status.reasons,
            "queued_at":  datetime.utcnow().isoformat(),
            "resolved":   False,
            "resolver":   None,
            "resolved_at": None,
        })
        logger.info(f"[AdminQueue] 새 큐 등록: {review_status.place_id}")
 
def mark_reviewed(place_id: str, resolver: str, resolution_note: str = ""):
    """관리자가 검토 완료 처리"""
    db = get_db()
    db.collection("admin_review_queue").document(place_id).update({
        "resolved":      True,
        "resolver":      resolver,
        "resolved_at":   datetime.utcnow().isoformat(),
        "resolution_note": resolution_note,
    })
    db.collection("places").document(place_id).update({
        "status": "OK",
        "needs_review_reasons": [],
    })
    logger.info(f"[AdminQueue] 검토 완료: {place_id} by {resolver}")