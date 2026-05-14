
import os
import re
import time
import logging
import requests
from bs4 import BeautifulSoup
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from enum import Enum

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


class SourceType(str, Enum):
    OFFICIAL_WEB   = "official_web"
    INSTAGRAM_BIO  = "instagram_bio"
    INSTAGRAM_POST = "instagram_post"
    NAVER_BLOG     = "naver_blog"
    REVIEW         = "review"


@dataclass
class RawDocument:
    place_id:    str
    place_name:  str
    source_type: SourceType
    source_url:  str
    raw_text:    str
    crawled_at:  datetime = field(default_factory=datetime.utcnow)


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
}

PET_KEYWORDS = [
    # 기본 명칭
    "반려견", "반려동물", "애견", "펫", "pet", "dog",
    # 체중·크기
    "체중", "무게", "kg", "소형견", "중형견", "대형견",
    # 견종·제한
    "견종", "품종", "제한", "맹견", "법정맹견",
    # 동반·입장
    "동반", "입장", "동반 가능", "펫 프렌들리",
    # 이용 조건
    "목줄", "리드줄", "케이지", "이동가방", "실내", "실외", "테라스",
]


def _get(url: str, timeout: int = 10) -> Optional[requests.Response]:
    try:
        resp = requests.get(url, headers=HEADERS, timeout=timeout)
        resp.raise_for_status()
        return resp
    except Exception as e:
        logger.warning(f"GET 실패: {url} → {e}")
        return None


class OfficialWebCrawler:
    """공식 홈페이지에서 반려견 정책 관련 텍스트 추출"""

    def crawl(self, place_id: str, place_name: str, url: str) -> Optional[RawDocument]:
        logger.info(f"[공식홈피] {place_name} → {url}")
        resp = _get(url)
        if not resp:
            return None

        soup = BeautifulSoup(resp.text, "lxml")
        for tag in soup(["script", "style", "nav", "footer", "header"]):
            tag.decompose()

        texts = [
            t for tag in soup.find_all(["p", "li", "div", "span", "td"])
            if len(t := tag.get_text(separator=" ", strip=True)) > 15
            and any(kw in t for kw in PET_KEYWORDS)
        ]

        if not texts:
            # 키워드 매칭 실패 시 전체 본문 저장 후 GPT 판단에 위임
            texts = [soup.get_text(separator="\n", strip=True)[:3000]]

        raw_text = "\n".join(dict.fromkeys(texts))
        return RawDocument(
            place_id=place_id,
            place_name=place_name,
            source_type=SourceType.OFFICIAL_WEB,
            source_url=url,
            raw_text=raw_text[:5000],
        )


class InstagramCrawler:
    """인스타그램 비즈니스 계정의 bio와 공식 포스트 캡션 수집"""

    MAX_POSTS = 5  # 반려견 키워드 포함 포스트 최대 수집 건수

    def crawl(self, place_id: str, place_name: str, instagram_username: str) -> list[RawDocument]:
        results: list[RawDocument] = []
        profile_url = f"https://www.instagram.com/{instagram_username}/"
        logger.info(f"[인스타그램] {place_name} → @{instagram_username}")

        resp = _get(profile_url)
        if not resp:
            return results

        soup = BeautifulSoup(resp.text, "lxml")

        bio = self._extract_bio(resp.text, soup)
        if bio:
            results.append(RawDocument(
                place_id=place_id,
                place_name=place_name,
                source_type=SourceType.INSTAGRAM_BIO,
                source_url=profile_url,
                raw_text=bio,
            ))
            logger.info(f"[인스타그램] bio 수집 완료: @{instagram_username}")
        else:
            logger.warning(f"[인스타그램] bio 추출 실패: @{instagram_username}")

        post_docs = self._crawl_posts(place_id, place_name, instagram_username, resp.text)
        results.extend(post_docs)
        logger.info(f"[인스타그램] 포스트 {len(post_docs)}건 수집: @{instagram_username}")

        return results

    def _extract_bio(self, html: str, soup: BeautifulSoup) -> str:
        meta_desc = soup.find("meta", {"name": "description"})
        if meta_desc and meta_desc.get("content"):
            return meta_desc["content"]

        match = re.search(r'"biography":"(.*?)"', html)
        if match:
            return match.group(1).encode().decode("unicode_escape")

        return ""

    def _crawl_posts(
        self, place_id: str, place_name: str, username: str, profile_html: str
    ) -> list[RawDocument]:
        docs: list[RawDocument] = []

        shortcodes = list(dict.fromkeys(re.findall(r'"shortcode":"([^"]+)"', profile_html)))[:20]

        for sc in shortcodes:
            if len(docs) >= self.MAX_POSTS:
                break

            post_url = f"https://www.instagram.com/p/{sc}/"
            resp = _get(post_url)
            if not resp:
                continue

            post_soup = BeautifulSoup(resp.text, "lxml")
            og_desc = post_soup.find("meta", {"property": "og:description"})
            caption = og_desc.get("content", "") if og_desc else ""

            if not caption:
                m = re.search(r'"edge_media_to_caption".*?"text":"(.*?)"', resp.text)
                if m:
                    caption = m.group(1).encode().decode("unicode_escape")

            if not caption or not any(kw in caption for kw in PET_KEYWORDS):
                continue

            docs.append(RawDocument(
                place_id=place_id,
                place_name=place_name,
                source_type=SourceType.INSTAGRAM_POST,
                source_url=post_url,
                raw_text=caption[:3000],
            ))
            time.sleep(0.5)

        return docs


class NaverBlogCrawler:
    """네이버 검색 API로 블로그 포스팅 검색 및 본문 수집"""

    SEARCH_URL = "https://openapi.naver.com/v1/search/blog.json"

    def __init__(self):
        self.client_id     = os.getenv("NAVER_CLIENT_ID", "")
        self.client_secret = os.getenv("NAVER_CLIENT_SECRET", "")

    def _search(self, place_name: str, max_items: int = 5) -> list[dict]:
        if not self.client_id:
            logger.warning("NAVER_CLIENT_ID 미설정 — 블로그 검색 건너뜀")
            return []

        try:
            resp = requests.get(
                self.SEARCH_URL,
                params={"query": f"{place_name} 반려견 애견 동반", "display": max_items, "sort": "date"},
                headers={
                    "X-Naver-Client-Id":     self.client_id,
                    "X-Naver-Client-Secret": self.client_secret,
                },
                timeout=10,
            )
            resp.raise_for_status()
            return resp.json().get("items", [])
        except Exception as e:
            logger.warning(f"네이버 블로그 검색 실패: {e}")
            return []

    def _fetch_body(self, link: str) -> str:
        # 네이버 블로그 iframe 구조 우회를 위해 모바일 URL로 변환
        resp = _get(link.replace("blog.naver.com", "m.blog.naver.com"))
        if not resp:
            return ""

        soup = BeautifulSoup(resp.text, "lxml")
        content = (
            soup.find("div", class_="se-main-container")
            or soup.find("div", id="postViewArea")
            or soup.find("div", class_="post-view")
        )
        if content:
            return content.get_text(separator="\n", strip=True)[:4000]
        return soup.get_text(separator="\n", strip=True)[:2000]

    def crawl(self, place_id: str, place_name: str) -> list[RawDocument]:
        items = self._search(place_name)
        docs  = []

        for item in items:
            link      = item.get("link", "")
            body      = self._fetch_body(link) if link else ""
            if not body:
                body = re.sub(r"<[^>]+>", "", item.get("description", ""))
            if not body:
                continue

            crawled_at = datetime.utcnow()
            try:
                crawled_at = datetime.strptime(item.get("postdate", ""), "%Y%m%d")
            except ValueError:
                pass

            docs.append(RawDocument(
                place_id=place_id,
                place_name=place_name,
                source_type=SourceType.NAVER_BLOG,
                source_url=link,
                raw_text=body,
                crawled_at=crawled_at,
            ))
            time.sleep(0.5)

        logger.info(f"[네이버블로그] {place_name} → {len(docs)}건 수집")
        return docs


class KakaoReviewCrawler:
    """카카오맵 장소 후기 수집"""

    REVIEW_URL = "https://place.map.kakao.com/commentlist/v/{place_id}"

    def crawl(self, place_id: str, place_name: str, kakao_place_id: str) -> list[RawDocument]:
        url = self.REVIEW_URL.format(place_id=kakao_place_id)
        logger.info(f"[카카오후기] {place_name} → {url}")

        resp = _get(url)
        if not resp:
            return []

        try:
            reviews = resp.json().get("comment", {}).get("list", [])
        except Exception:
            logger.warning("카카오맵 JSON 파싱 실패")
            return []

        docs = []
        for rv in reviews[:20]:
            text = rv.get("contents", "").strip()
            if not text:
                continue

            crawled_at = datetime.utcnow()
            try:
                crawled_at = datetime.fromisoformat(rv.get("commentDatetime", "")[:19])
            except ValueError:
                pass

            docs.append(RawDocument(
                place_id=place_id,
                place_name=place_name,
                source_type=SourceType.REVIEW,
                source_url=url,
                raw_text=text[:2000],
                crawled_at=crawled_at,
            ))

        logger.info(f"[카카오후기] {place_name} → {len(docs)}건 수집")
        return docs


def crawl_all_sources(
    place_id:         str,
    place_name:       str,
    official_url:     Optional[str] = None,
    instagram_handle: Optional[str] = None,
    kakao_place_id:   Optional[str] = None,
) -> list[RawDocument]:
    """한 장소에 대해 가능한 모든 출처에서 크롤링하여 RawDocument 리스트로 반환"""
    all_docs: list[RawDocument] = []

    if official_url:
        doc = OfficialWebCrawler().crawl(place_id, place_name, official_url)
        if doc:
            all_docs.append(doc)

    if instagram_handle:
        all_docs.extend(InstagramCrawler().crawl(place_id, place_name, instagram_handle))

    all_docs.extend(NaverBlogCrawler().crawl(place_id, place_name))

    if kakao_place_id:
        all_docs.extend(KakaoReviewCrawler().crawl(place_id, place_name, kakao_place_id))

    logger.info(f"총 {len(all_docs)}개 문서 수집 완료: {place_name}")
    return all_docs