const firebaseConfig = {
  apiKey: "AIzaSyCZRr1hiJyJXRnPNVO7W3f3txsOvrCazCU",
  authDomain: "mypettrip-6bf55.firebaseapp.com",
  projectId: "mypettrip-6bf55",
  storageBucket: "mypettrip-6bf55.firebasestorage.app",
  messagingSenderId: "273162152277",
};

const regionApiUrl =
  "https://apis.data.go.kr/B551011/KorPetTourService2/ldongCode2";
const regionApiKey =
  "ccd1b9293984eedcb943bb71aa9826aa8f8bf851bc45cb5d16f51c71d4e61f3e";

const fallbackRegions = [
  {
    code: "11",
    name: "서울특별시",
    sigungu: [
      { code: "14", name: "서대문구" },
      { code: "23", name: "마포구" },
      { code: "20", name: "동대문구" },
      { code: "17", name: "성북구" },
    ],
  },
  {
    code: "41",
    name: "경기도",
    sigungu: [
      { code: "20", name: "가평군" },
      { code: "11", name: "수원시" },
      { code: "13", name: "성남시" },
      { code: "28", name: "고양시" },
    ],
  },
];

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();

const form = document.getElementById("place-form");
const preview = document.getElementById("preview");
const status = document.getElementById("status");
const resetFormButton = document.getElementById("reset-form");
const lookupByTitleButton = document.getElementById("lookup-by-title");
const updatePlaceButton = document.getElementById("update-place");
const deletePlaceButton = document.getElementById("delete-place");
const loadingOverlay = document.getElementById("loading-overlay");
const lookupModal = document.getElementById("lookup-modal");
const closeLookupModalButton = document.getElementById("close-lookup-modal");
const lookupResultList = document.getElementById("lookup-result-list");
const sidoSelect = document.getElementById("sidoSelect");
const sigunguSelect = document.getElementById("sigunguSelect");
const sidoCodeInput = document.getElementById("seedRegionSidoCode");
const sidoNameInput = document.getElementById("seedRegionSidoName");
const sigunguCodeInput = document.getElementById("seedRegionSigunguCode");
const sigunguNameInput = document.getElementById("seedRegionSigunguName");

let regions = fallbackRegions;
let lookupResults = [];

function setStatus(message, isError = false) {
  status.textContent = message;
  status.classList.toggle("error", isError);
}

function setLoading(isLoading) {
  loadingOverlay.classList.toggle("open", isLoading);
}

function closeLookupModal() {
  lookupModal.classList.remove("open");
  lookupResultList.innerHTML = "";
  lookupResults = [];
}

function handleLookupResultSelect(index) {
  const selected = lookupResults[index];
  if (!selected) {
    return;
  }

  setFormFromPlaceData(selected.data);
  closeLookupModal();
  setStatus(
    `조회 완료\n문서 ID: ${selected.data.contentId || selected.id}\n장소명: ${selected.data.title || ""}`,
  );
}

function openLookupModal(results) {
  lookupResults = results;
  lookupResultList.innerHTML = "";

  for (const [index, result] of results.entries()) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "result-item";
    button.addEventListener("click", () => handleLookupResultSelect(index));

    const title = document.createElement("span");
    title.className = "result-title";
    title.textContent = result.data.title || "(제목 없음)";

    const meta = document.createElement("span");
    meta.className = "result-meta";
    const addr = result.data.addr1 || "주소 없음";
    const region = [result.data.seedRegionSidoName, result.data.seedRegionSigunguName]
      .filter(Boolean)
      .join(" ");
    meta.textContent = `문서 ID: ${result.data.contentId || result.id}\n주소: ${addr}${region ? `\n지역: ${region}` : ""}`;

    button.append(title, meta);
    lookupResultList.append(button);
  }

  lookupModal.classList.add("open");
}

function buildRegionApiUrl() {
  const url = new URL(regionApiUrl);
  url.searchParams.set("serviceKey", regionApiKey);
  url.searchParams.set("numOfRows", "1000");
  url.searchParams.set("MobileOS", "IOS");
  url.searchParams.set("MobileApp", "mypettrip-admin");
  url.searchParams.set("lDongListYn", "Y");
  url.searchParams.set("_type", "json");
  return url.toString();
}

async function loadRegions() {
  try {
    const response = await fetch(buildRegionApiUrl());
    if (!response.ok) {
      throw new Error(`지역 API 요청 실패: ${response.status}`);
    }

    const decoded = await response.json();
    const rawItems = decoded?.response?.body?.items?.item;
    const items = Array.isArray(rawItems)
      ? rawItems
      : rawItems
        ? [rawItems]
        : [];

    const sidoMap = new Map();
    const sigunguMap = new Map();

    for (const item of items) {
      const sidoCode = String(item.lDongRegnCd || "").trim();
      const sidoName = String(item.lDongRegnNm || "").trim();
      const sigunguCode = String(item.lDongSignguCd || "").trim();
      const sigunguName = String(item.lDongSignguNm || "").trim();

      if (!sidoCode || !sidoName) {
        continue;
      }

      sidoMap.set(sidoCode, sidoName);
      if (!sigunguMap.has(sidoCode)) {
        sigunguMap.set(sidoCode, new Map());
      }
      if (sigunguCode && sigunguName) {
        sigunguMap.get(sidoCode).set(sigunguCode, sigunguName);
      }
    }

    const loadedRegions = [...sidoMap.entries()]
      .map(([code, name]) => ({
        code,
        name,
        sigungu: [...(sigunguMap.get(code)?.entries() || [])]
          .map(([sigunguCode, sigunguName]) => ({
            code: sigunguCode,
            name: sigunguName,
          }))
          .sort((a, b) => a.name.localeCompare(b.name, "ko")),
      }))
      .sort((a, b) => a.name.localeCompare(b.name, "ko"));

    if (loadedRegions.length > 0) {
      regions = loadedRegions;
      setStatus("지역 목록을 불러왔습니다.");
      return;
    }

    throw new Error("지역 목록이 비어 있습니다.");
  } catch (error) {
    regions = fallbackRegions;
    setStatus(
      `지역 API를 불러오지 못해 기본 목록으로 대체했습니다.\n${error.message}`,
      true,
    );
  }
}

function getSelectedSido() {
  return regions.find((item) => item.code === sidoSelect.value) || regions[0];
}

function getSelectedSigungu() {
  const sido = getSelectedSido();
  return (
    sido?.sigungu.find((item) => item.code === sigunguSelect.value) ||
    sido?.sigungu[0] ||
    null
  );
}

function populateSidoOptions(selectedCode) {
  sidoSelect.innerHTML = "";
  for (const region of regions) {
    const option = document.createElement("option");
    option.value = region.code;
    option.textContent = region.name;
    if (region.code === selectedCode) {
      option.selected = true;
    }
    sidoSelect.append(option);
  }
}

function populateSigunguOptions(selectedCode) {
  const sido = getSelectedSido();
  sigunguSelect.innerHTML = "";

  for (const item of sido.sigungu) {
    const option = document.createElement("option");
    option.value = item.code;
    option.textContent = item.name;
    if (item.code === selectedCode) {
      option.selected = true;
    }
    sigunguSelect.append(option);
  }
}

function syncRegionReadOnlyFields() {
  const sido = getSelectedSido();
  const sigungu = getSelectedSigungu();

  sidoCodeInput.value = sido?.code || "";
  sidoNameInput.value = sido?.name || "";
  sigunguCodeInput.value = sigungu?.code || "";
  sigunguNameInput.value = sigungu?.name || "";
}

function ensureRegionSelection(sidoCode, sidoName, sigunguCode, sigunguName) {
  if (!sidoCode && !sidoName) {
    return;
  }

  let sido =
    regions.find((item) => item.code === String(sidoCode || "")) ||
    regions.find((item) => item.name === String(sidoName || ""));

  if (!sido) {
    sido = {
      code: String(sidoCode || ""),
      name: String(sidoName || ""),
      sigungu: [],
    };
    regions = [...regions, sido].sort((a, b) =>
      a.name.localeCompare(b.name, "ko"),
    );
  }

  const normalizedSigunguCode = String(sigunguCode || "");
  const normalizedSigunguName = String(sigunguName || "");
  let sigungu =
    sido.sigungu.find((item) => item.code === normalizedSigunguCode) ||
    sido.sigungu.find((item) => item.name === normalizedSigunguName);

  if (!sigungu && (normalizedSigunguCode || normalizedSigunguName)) {
    sigungu = {
      code: normalizedSigunguCode,
      name: normalizedSigunguName,
    };
    sido.sigungu = [...sido.sigungu, sigungu].sort((a, b) =>
      a.name.localeCompare(b.name, "ko"),
    );
  }

  populateSidoOptions(sido.code);
  populateSigunguOptions(sigungu?.code);

  if (sigungu) {
    sigunguSelect.value = sigungu.code;
  }

  syncRegionReadOnlyFields();
}

function setFormFromPlaceData(data) {
  document.getElementById("contentId").value = data.contentId || "";
  document.getElementById("title").value = data.title || "";
  document.getElementById("addr1").value = data.addr1 || "";
  document.getElementById("firstimage").value = data.firstimage || "";
  document.getElementById("updateDate").value = data.updateDate || "20260507";
  document.getElementById("indoorAllowed").checked = !!data.indoorAllowed;
  document.getElementById("parkingAvailable").checked = !!data.parkingAvailable;
  document.getElementById("leashRequired").checked = !!data.leashRequired;
  document.getElementById("outdoorOnly").checked =
    !!data.outdoorOnly ||
    (Array.isArray(data.travelChecklist) &&
      data.travelChecklist.some((item) => String(item).trim() === "야외"));
  const petSize = String(data.petSize || "").toUpperCase();
  const petSizeRadio = form.querySelector(`input[name="petSize"][value="${petSize}"]`);
  if (petSizeRadio) {
    petSizeRadio.checked = true;
  } else {
    for (const radio of form.querySelectorAll('input[name="petSize"]')) {
      radio.checked = false;
    }
  }
  document.getElementById("mapX").value =
    data.mapX === undefined || data.mapX === null ? "" : data.mapX;
  document.getElementById("mapY").value =
    data.mapY === undefined || data.mapY === null ? "" : data.mapY;
  document.getElementById("lclsSystm1").value = (
    data.lclsSystm1 ||
    data.placeType ||
    "FD"
  ).toUpperCase();

  ensureRegionSelection(
    data.seedRegionSidoCode,
    data.seedRegionSidoName,
    data.seedRegionSigunguCode,
    data.seedRegionSigunguName,
  );

  renderPreview();
}

function buildPayload() {
  const formData = new FormData(form);
  const isOutdoorOnly = formData.get("outdoorOnly") === "on";
  const travelChecklist = [];

  if (isOutdoorOnly) {
    travelChecklist.push("야외");
  }

  const payload = {
    contentId: String(formData.get("contentId") || "").trim(),
    title: String(formData.get("title") || "").trim(),
    addr1: String(formData.get("addr1") || "").trim(),
    firstimage: String(formData.get("firstimage") || "").trim(),
    updateDate: String(formData.get("updateDate") || "").trim(),
    addr2: "",
    mapX: Number(formData.get("mapX")),
    mapY: Number(formData.get("mapY")),
    lclsSystm1: String(formData.get("lclsSystm1") || "").trim().toUpperCase(),
    placeType: String(formData.get("lclsSystm1") || "").trim().toUpperCase(),
    seedRegionSidoCode: sidoCodeInput.value,
    seedRegionSidoName: sidoNameInput.value,
    seedRegionSigunguCode: sigunguCodeInput.value,
    seedRegionSigunguName: sigunguNameInput.value,
    overview: "",
    tel: "",
    homepage: "",
    reviewCount: 0,
    isFierceDog: false,
    indoorAllowed: formData.get("indoorAllowed") === "on",
    outdoorOnly: isOutdoorOnly,
    parkingAvailable: formData.get("parkingAvailable") === "on",
    leashRequired: formData.get("leashRequired") === "on",
    petSize: String(formData.get("petSize") || "").trim().toUpperCase(),
    travelChecklist,
  };

  return payload;
}

function validatePayload(payload) {
  if (!payload.contentId) {
    throw new Error("contentId는 필수입니다.");
  }
  if (!payload.title) {
    throw new Error("장소명은 필수입니다.");
  }
  if (!payload.addr1) {
    throw new Error("기본 주소는 필수입니다.");
  }
  if (!Number.isFinite(payload.mapX) || !Number.isFinite(payload.mapY)) {
    throw new Error("위도/경도는 숫자여야 합니다.");
  }
  if (!payload.lclsSystm1) {
    throw new Error("카테고리는 필수입니다.");
  }
  if (!payload.seedRegionSidoCode || !payload.seedRegionSigunguCode) {
    throw new Error("지역 선택은 필수입니다.");
  }
  if (payload.updateDate && !/^\d{8}$/.test(payload.updateDate)) {
    throw new Error("업데이트 날짜는 yyyyMMdd 형식의 8자리 숫자여야 합니다.");
  }
}

async function getPlaceDocument(contentId) {
  return db.collection("tour_places").doc(contentId).get();
}

function renderPreview() {
  try {
    preview.textContent = JSON.stringify(buildPayload(), null, 2);
  } catch (error) {
    preview.textContent = `미리보기 생성 실패: ${error.message}`;
  }
}

function resetForm() {
  form.reset();
  document.getElementById("lclsSystm1").value = "FD";
  const defaultSido = regions.find((item) => item.name.includes("서울")) || regions[0];
  populateSidoOptions(defaultSido.code);
  const defaultSigungu =
    defaultSido.sigungu.find((item) => item.name.includes("서대문")) ||
    defaultSido.sigungu[0];
  populateSigunguOptions(defaultSigungu?.code);
  if (defaultSigungu) {
    sigunguSelect.value = defaultSigungu.code;
  }
  syncRegionReadOnlyFields();
  renderPreview();
  setStatus("폼을 초기화했습니다.");
}

async function handleCreate(event) {
  event.preventDefault();

  try {
    const payload = buildPayload();
    validatePayload(payload);

    setStatus("신규 저장 여부를 확인 중입니다...");

    const existingDoc = await getPlaceDocument(payload.contentId);
    if (existingDoc.exists) {
      throw new Error("동일한 contentId가 이미 있어 신규 저장할 수 없습니다.");
    }

    setStatus("Firestore에 신규 저장 중입니다...");

    await db.collection("tour_places").doc(payload.contentId).set(
      {
        ...payload,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    setStatus(
      `신규 저장 완료\n컬렉션: tour_places\n문서 ID: ${payload.contentId}\n장소명: ${payload.title}`,
    );
    renderPreview();
  } catch (error) {
    console.error(error);
    setStatus(
      `저장 실패\n${error?.message || "알 수 없는 오류가 발생했습니다."}`,
      true,
    );
  }
}

async function handleUpdate() {
  try {
    const payload = buildPayload();
    validatePayload(payload);

    setStatus("수정 대상 문서를 확인 중입니다...");

    const existingDoc = await getPlaceDocument(payload.contentId);
    if (!existingDoc.exists) {
      throw new Error("해당 contentId 문서가 없어 수정할 수 없습니다.");
    }

    setStatus("Firestore에 수정 반영 중입니다...");

    await db.collection("tour_places").doc(payload.contentId).set(
      {
        ...payload,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    setStatus(
      `수정 완료\n컬렉션: tour_places\n문서 ID: ${payload.contentId}\n장소명: ${payload.title}`,
    );
    renderPreview();
  } catch (error) {
    console.error(error);
    setStatus(
      `수정 실패\n${error?.message || "알 수 없는 오류가 발생했습니다."}`,
      true,
    );
  }
}

async function handleDelete() {
  const contentId = String(document.getElementById("contentId").value || "").trim();

  if (!contentId) {
    setStatus("삭제할 contentId를 먼저 입력해주세요.", true);
    return;
  }

  try {
    setStatus("삭제 대상 문서를 확인 중입니다...");

    const existingDoc = await getPlaceDocument(contentId);
    if (!existingDoc.exists) {
      throw new Error("해당 contentId 문서가 없어 삭제할 수 없습니다.");
    }

    setStatus("Firestore에서 삭제 중입니다...");

    await db.collection("tour_places").doc(contentId).delete();

    resetForm();
    setStatus(`삭제 완료\n컬렉션: tour_places\n문서 ID: ${contentId}`);
  } catch (error) {
    console.error(error);
    setStatus(
      `삭제 실패\n${error?.message || "알 수 없는 오류가 발생했습니다."}`,
      true,
    );
  }
}

async function handleLookupByTitle() {
  const title = String(document.getElementById("title").value || "").trim();

  if (!title) {
    setStatus("조회할 장소명을 먼저 입력해주세요.", true);
    return;
  }

  try {
    setStatus("장소명을 기준으로 조회 중입니다...");

    const snapshot = await db
      .collection("tour_places")
      .orderBy("title")
      .startAt(title)
      .endAt(`${title}\uf8ff`)
      .get();

    if (snapshot.empty) {
      throw new Error("해당 장소명으로 저장된 문서를 찾지 못했습니다.");
    }

    const results = snapshot.docs.map((doc) => ({
      id: doc.id,
      data: doc.data() || {},
    }));

    if (results.length === 1) {
      const selected = results[0];
      setFormFromPlaceData(selected.data);
      setStatus(
        `조회 완료\n문서 ID: ${selected.data.contentId || selected.id}\n장소명: ${selected.data.title || title}`,
      );
      return;
    }

    openLookupModal(results);
    setStatus(`조회 결과 ${results.length}건\n팝업에서 불러올 장소를 선택해주세요.`);
  } catch (error) {
    console.error(error);
    setStatus(
      `조회 실패\n${error?.message || "알 수 없는 오류가 발생했습니다."}`,
      true,
    );
  }
}

function bindEvents() {
  for (const element of form.elements) {
    if (
      element instanceof HTMLInputElement ||
      element instanceof HTMLSelectElement
    ) {
      element.addEventListener("input", renderPreview);
      element.addEventListener("change", renderPreview);
    }
  }

  sidoSelect.addEventListener("change", () => {
    populateSigunguOptions();
    syncRegionReadOnlyFields();
    renderPreview();
  });

  sigunguSelect.addEventListener("change", () => {
    syncRegionReadOnlyFields();
    renderPreview();
  });

  form.addEventListener("submit", handleCreate);
  resetFormButton.addEventListener("click", resetForm);
  lookupByTitleButton.addEventListener("click", handleLookupByTitle);
  updatePlaceButton.addEventListener("click", handleUpdate);
  deletePlaceButton.addEventListener("click", handleDelete);
  closeLookupModalButton.addEventListener("click", closeLookupModal);
  lookupModal.addEventListener("click", (event) => {
    if (event.target === lookupModal) {
      closeLookupModal();
    }
  });
}

async function init() {
  setLoading(true);
  try {
    await loadRegions();
    bindEvents();
    resetForm();
  } finally {
    setLoading(false);
  }
}

init();