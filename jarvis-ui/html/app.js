const presenceListEl = document.getElementById("presenceList");
const chatLogEl = document.getElementById("chatLog");
const actionLogEl = document.getElementById("actionLog");
const bottomNavEl = document.getElementById("bottomNav");
const clockEl = document.getElementById("clockLabel");
const dayEl = document.getElementById("dayLabel");
const speechEl = document.getElementById("speechText");
const cameraStreamEl = document.getElementById("cameraStream");
const cameraVideoEl = document.getElementById("cameraVideo");
const cameraFallbackEl = document.getElementById("cameraFallback");
const cameraStateEl = document.getElementById("cameraState");
const camPillEl = document.getElementById("camPill");
const camPillTextEl = document.getElementById("camPillText");
const actionNameInputEl = document.getElementById("actionNameInput");
const actionTargetEl = document.getElementById("actionTarget");
const actionCommandEl = document.getElementById("actionCommand");
const actionPayloadEl = document.getElementById("actionPayload");
const actionPresetSelectEl = document.getElementById("actionPresetSelect");
const actionPresetNameEl = document.getElementById("actionPresetName");
const savePresetBtnEl = document.getElementById("savePresetBtn");
const deletePresetBtnEl = document.getElementById("deletePresetBtn");
const rewriteActionBtnEl = document.getElementById("rewriteActionBtn");
const testActionBtnEl = document.getElementById("testActionBtn");
const saveActionBtnEl = document.getElementById("saveActionBtn");
const actionBuilderStatusEl = document.getElementById("actionBuilderStatus");

const DEFAULT_CAMERA_STREAM_URL = "http://localhost:8081/stream.mjpg";

const people = [
  { name: "SANDER", home: true },
  { name: "ANNE", home: true },
  { name: "LIANNE", home: false },
  { name: "THOMAS", home: false }
];

const messages = [
  { who: "Jij", text: "Doe de lichten in de woonkamer aan op 40%", time: "15:42:10" },
  { who: "Samantha", text: "De lichten in de woonkamer zijn aangezet op 40%.", time: "15:42:12" },
  { who: "Jij", text: "Open het hek", time: "15:42:15" },
  { who: "Samantha", text: "Het hek is geopend.", time: "15:42:18" }
];

const fallbackActions = [
  { time: "15:42:18", text: "Lichten woonkamer gedimd naar 30%", source: "Homey" },
  { time: "15:42:05", text: "Hek geopend", source: "Homey" },
  { time: "15:40:12", text: "Thermostaat staat ingesteld op 20 C", source: "Home Assistant" },
  { time: "15:39:47", text: "Verbruik woonkamer opgevraagd", source: "Home Assistant" },
  { time: "15:38:33", text: "Aanwezigheid gecontroleerd", source: "Home Assistant" }
];

const navItems = ["OVERZICHT", "VERLICHTING", "KLIMAAT", "BEVEILIGING", "ENERGIE", "MEDIA", "INSTELLINGEN"];
const speechStates = ["Ik luister...", "Commando ontvangen", "Samantha verwerkt actie", "Systeem standby"];
let lastSuccessfulTestSignature = null;
let lastSuccessfulTestResult = null;
let presetListCache = [];

function initials(name) {
  return name.slice(0, 1);
}

function renderPresence() {
  people.forEach((person) => {
    const li = document.createElement("li");
    li.innerHTML = `
      <div class="person-avatar">${initials(person.name)}</div>
      <strong>${person.name}</strong>
      <span class="person-state ${person.home ? "" : "away"}">${person.home ? "THUIS" : "NIET THUIS"}</span>
    `;
    presenceListEl.appendChild(li);
  });
}

function renderMessages() {
  messages.forEach((msg) => {
    const row = document.createElement("article");
    row.className = "msg";
    row.innerHTML = `
      <div class="msg-avatar">${msg.who === "Jij" ? "J" : "S"}</div>
      <div>
        <strong>${msg.who}</strong>
        <div>${msg.text}</div>
      </div>
      <span class="msg-meta">${msg.time}</span>
    `;
    chatLogEl.appendChild(row);
  });
}

function renderActions() {
  actionLogEl.innerHTML = "";
  fallbackActions.forEach((item) => {
    const row = document.createElement("article");
    row.className = "action-item";
    row.innerHTML = `<div>${item.text}</div><div class="meta">${item.time} • ${item.source}</div>`;
    actionLogEl.appendChild(row);
  });
}

function getActionHubBaseUrl() {
  const protocol = window.location.protocol === "https:" ? "https:" : "http:";
  const hostName = window.location.hostname || "localhost";
  return `${protocol}//${hostName}:3002`;
}

function formatActionTime(raw) {
  if (!raw) {
    return "--:--:--";
  }

  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) {
    return "--:--:--";
  }

  return d.toLocaleTimeString("nl-NL", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

async function loadActionsFromHub() {
  if (!actionLogEl) {
    return;
  }

  try {
    const res = await fetch(`${getActionHubBaseUrl()}/api/actions?limit=12`);
    if (!res.ok) {
      throw new Error(`Action hub returned ${res.status}`);
    }

    const data = await res.json();
    const actions = Array.isArray(data?.actions) ? data.actions : [];
    if (actions.length === 0) {
      renderActions();
      return;
    }

    actionLogEl.innerHTML = "";
    actions.forEach((item) => {
      const row = document.createElement("article");
      row.className = "action-item";
      const source = item.source || "Samantha";
      row.innerHTML = `<div>${item.text || "Actie"}</div><div class="meta">${formatActionTime(item.created_at)} • ${source}</div>`;
      actionLogEl.appendChild(row);
    });
  } catch {
    renderActions();
  }
}

function renderNav() {
  navItems.forEach((item, index) => {
    const node = document.createElement("button");
    node.type = "button";
    node.className = `nav-item ${index === 0 ? "active" : ""}`;
    node.textContent = item;
    bottomNavEl.appendChild(node);
  });
}

function setBuilderStatus(text, isError = false) {
  if (!actionBuilderStatusEl) {
    return;
  }

  actionBuilderStatusEl.textContent = text;
  actionBuilderStatusEl.classList.toggle("error", isError);
}

function stableStringify(value) {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(",")}]`;
  }

  const keys = Object.keys(value).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`).join(",")}}`;
}

function parsePayloadJson() {
  const raw = (actionPayloadEl?.value || "").trim();
  if (!raw) {
    return {};
  }

  return JSON.parse(raw);
}

function buildActionDefinition() {
  const text = (actionNameInputEl?.value || "").trim();
  const target = (actionTargetEl?.value || "").trim();
  const command = (actionCommandEl?.value || "").trim();
  const payload = parsePayloadJson();

  if (!text) {
    throw new Error("Omschrijving is verplicht");
  }

  if (!target || !command) {
    throw new Error("Doel en commando zijn verplicht");
  }

  return { text, target, command, payload };
}

function getDefinitionSignature(definition) {
  return `${definition.text}|${definition.target}|${definition.command}|${stableStringify(definition.payload)}`;
}

function getSelectedPresetId() {
  if (!actionPresetSelectEl || !actionPresetSelectEl.value) {
    return null;
  }

  const id = Number.parseInt(actionPresetSelectEl.value, 10);
  return Number.isFinite(id) ? id : null;
}

function applyPresetToBuilder(preset) {
  if (!preset) {
    return;
  }

  if (actionPresetNameEl) {
    actionPresetNameEl.value = preset.name || "";
  }
  if (actionNameInputEl) {
    actionNameInputEl.value = preset.text || "";
  }
  if (actionTargetEl) {
    actionTargetEl.value = preset.target || "home_assistant_presence";
  }
  if (actionCommandEl) {
    actionCommandEl.value = preset.command || "get_states";
  }
  if (actionPayloadEl) {
    actionPayloadEl.value = JSON.stringify(preset.payload || {}, null, 2);
  }
}

function renderPresetSelect(selectedId = null) {
  if (!actionPresetSelectEl) {
    return;
  }

  const previous = selectedId ?? getSelectedPresetId();
  actionPresetSelectEl.innerHTML = "";

  const defaultOption = document.createElement("option");
  defaultOption.value = "";
  defaultOption.textContent = "Nieuw preset...";
  actionPresetSelectEl.appendChild(defaultOption);

  presetListCache.forEach((preset) => {
    const option = document.createElement("option");
    option.value = String(preset.id);
    option.textContent = preset.name;
    actionPresetSelectEl.appendChild(option);
  });

  if (previous) {
    actionPresetSelectEl.value = String(previous);
  }

  const activeId = getSelectedPresetId();
  if (deletePresetBtnEl) {
    deletePresetBtnEl.disabled = !activeId;
  }
}

async function loadPresetsFromHub(selectedId = null) {
  if (!actionPresetSelectEl) {
    return;
  }

  try {
    const res = await fetch(`${getActionHubBaseUrl()}/api/presets`);
    if (!res.ok) {
      throw new Error(`Preset laden mislukt (${res.status})`);
    }
    const data = await res.json();
    presetListCache = Array.isArray(data?.presets) ? data.presets : [];
    renderPresetSelect(selectedId);
  } catch {
    presetListCache = [];
    renderPresetSelect(null);
  }
}

function handlePresetSelectionChange() {
  const presetId = getSelectedPresetId();
  if (!presetId) {
    if (actionPresetNameEl) {
      actionPresetNameEl.value = "";
    }
    if (deletePresetBtnEl) {
      deletePresetBtnEl.disabled = true;
    }
    return;
  }

  const preset = presetListCache.find((p) => p.id === presetId);
  if (!preset) {
    return;
  }

  applyPresetToBuilder(preset);
  invalidateTestResult();
  if (deletePresetBtnEl) {
    deletePresetBtnEl.disabled = false;
  }
  setBuilderStatus(`Preset '${preset.name}' geladen. Test opnieuw voor opslaan.`);
}

async function saveOrUpdatePreset() {
  if (!savePresetBtnEl) {
    return;
  }

  savePresetBtnEl.disabled = true;
  try {
    const definition = buildActionDefinition();
    const presetName = (actionPresetNameEl?.value || "").trim() || definition.text;
    const presetId = getSelectedPresetId();
    const payload = {
      name: presetName,
      text: definition.text,
      target: definition.target,
      command: definition.command,
      payload: definition.payload
    };

    const method = presetId ? "PUT" : "POST";
    const url = presetId
      ? `${getActionHubBaseUrl()}/api/presets/${presetId}`
      : `${getActionHubBaseUrl()}/api/presets`;

    const res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (!res.ok || !data?.ok) {
      throw new Error(data?.error || "Preset opslaan mislukt");
    }

    const selected = data?.id || presetId;
    await loadPresetsFromHub(selected);
    setBuilderStatus(presetId ? "Preset bijgewerkt." : "Nieuw preset opgeslagen.");
  } catch (err) {
    setBuilderStatus(err.message || "Preset opslaan mislukt.", true);
  } finally {
    savePresetBtnEl.disabled = false;
  }
}

async function deleteSelectedPreset() {
  const presetId = getSelectedPresetId();
  if (!presetId || !deletePresetBtnEl) {
    return;
  }

  deletePresetBtnEl.disabled = true;
  try {
    const res = await fetch(`${getActionHubBaseUrl()}/api/presets/${presetId}`, {
      method: "DELETE"
    });
    const data = await res.json();
    if (!res.ok || !data?.ok) {
      throw new Error(data?.error || "Preset verwijderen mislukt");
    }

    if (actionPresetNameEl) {
      actionPresetNameEl.value = "";
    }
    await loadPresetsFromHub(null);
    setBuilderStatus("Preset verwijderd.");
  } catch (err) {
    setBuilderStatus(err.message || "Preset verwijderen mislukt.", true);
  } finally {
    deletePresetBtnEl.disabled = false;
  }
}

function invalidateTestResult() {
  lastSuccessfulTestSignature = null;
  lastSuccessfulTestResult = null;
  if (saveActionBtnEl) {
    saveActionBtnEl.disabled = true;
  }
}

async function rewriteActionTextWithSamatha() {
  if (!actionNameInputEl) {
    return;
  }

  const text = actionNameInputEl.value.trim();
  if (!text) {
    setBuilderStatus("Vul eerst een omschrijving in.", true);
    return;
  }

  rewriteActionBtnEl.disabled = true;
  setBuilderStatus("Samantha verbetert de omschrijving...");

  try {
    const payload = {
      text,
      target: (actionTargetEl?.value || "").trim(),
      command: (actionCommandEl?.value || "").trim(),
      payload: parsePayloadJson()
    };

    const res = await fetch(`${getActionHubBaseUrl()}/api/actions/rewrite`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      throw new Error(`Rewrite mislukt (${res.status})`);
    }

    const data = await res.json();
    const improved = data?.suggested_text || text;
    actionNameInputEl.value = improved;
    invalidateTestResult();
    setBuilderStatus("Omschrijving verbeterd door Samantha. Test nu de actie.");
  } catch (err) {
    setBuilderStatus(err.message || "Kon tekst niet verbeteren.", true);
  } finally {
    rewriteActionBtnEl.disabled = false;
  }
}

async function testActionDefinition() {
  if (!testActionBtnEl) {
    return;
  }

  testActionBtnEl.disabled = true;
  invalidateTestResult();

  try {
    const definition = buildActionDefinition();
    setBuilderStatus("Test uitvoeren...");

    const res = await fetch(`${getActionHubBaseUrl()}/api/actions/execute`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        source: "action-builder-test",
        text: definition.text,
        target: definition.target,
        command: definition.command,
        payload: definition.payload,
        test_only: true
      })
    });

    const data = await res.json();
    if (!res.ok || !data?.ok) {
      const details = data?.result?.error || data?.error || "Onbekende fout";
      throw new Error(`Test mislukt: ${details}`);
    }

    lastSuccessfulTestSignature = getDefinitionSignature(definition);
    lastSuccessfulTestResult = data?.result || {};
    if (saveActionBtnEl) {
      saveActionBtnEl.disabled = false;
    }
    setBuilderStatus("Test geslaagd. Je kunt nu opslaan.");
  } catch (err) {
    setBuilderStatus(err.message || "Test mislukt.", true);
  } finally {
    testActionBtnEl.disabled = false;
  }
}

async function saveValidatedAction() {
  if (!saveActionBtnEl) {
    return;
  }

  saveActionBtnEl.disabled = true;
  try {
    const definition = buildActionDefinition();
    const signature = getDefinitionSignature(definition);
    if (!lastSuccessfulTestSignature || signature !== lastSuccessfulTestSignature) {
      throw new Error("Actie is gewijzigd. Test opnieuw voordat je opslaat.");
    }

    const payload = {
      source: "action-builder",
      status: "validated",
      text: definition.text,
      target: definition.target,
      command: definition.command,
      payload: {
        definition: definition.payload,
        validated_by: "samantha-ai",
        validated_at: new Date().toISOString(),
        test_result: lastSuccessfulTestResult || {}
      }
    };

    const res = await fetch(`${getActionHubBaseUrl()}/api/actions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (!res.ok || !data?.ok) {
      throw new Error(data?.error || "Opslaan mislukt");
    }

    setBuilderStatus("Actie opgeslagen na geslaagde test.");
    loadActionsFromHub();
  } catch (err) {
    setBuilderStatus(err.message || "Opslaan mislukt.", true);
  } finally {
    if (saveActionBtnEl) {
      saveActionBtnEl.disabled = false;
    }
  }
}

function wireActionBuilder() {
  if (!actionNameInputEl || !actionTargetEl || !actionCommandEl || !actionPayloadEl) {
    return;
  }

  const invalidate = () => {
    invalidateTestResult();
    setBuilderStatus("Wijziging gedetecteerd. Test opnieuw voor opslaan.");
  };

  actionNameInputEl.addEventListener("input", invalidate);
  actionTargetEl.addEventListener("change", invalidate);
  actionCommandEl.addEventListener("change", invalidate);
  actionPayloadEl.addEventListener("input", invalidate);
  actionPresetSelectEl?.addEventListener("change", handlePresetSelectionChange);

  savePresetBtnEl?.addEventListener("click", saveOrUpdatePreset);
  deletePresetBtnEl?.addEventListener("click", deleteSelectedPreset);

  rewriteActionBtnEl?.addEventListener("click", rewriteActionTextWithSamatha);
  testActionBtnEl?.addEventListener("click", testActionDefinition);
  saveActionBtnEl?.addEventListener("click", saveValidatedAction);

  loadPresetsFromHub();
}

function updateClock() {
  const now = new Date();
  const dateText = now
    .toLocaleDateString("nl-NL", { weekday: "long", day: "2-digit", month: "long", year: "numeric" })
    .toUpperCase();
  const timeText = now.toLocaleTimeString("nl-NL", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  dayEl.textContent = dateText;
  clockEl.textContent = timeText;
}

let speechIndex = 0;
function cycleSpeech() {
  speechIndex = (speechIndex + 1) % speechStates.length;
  speechEl.textContent = speechStates[speechIndex];
}

function setCameraState(text, offline = false) {
  if (!cameraStateEl) {
    return;
  }

  cameraStateEl.textContent = text;
  cameraStateEl.classList.toggle("offline", offline);

  if (camPillEl && camPillTextEl) {
    camPillTextEl.textContent = offline ? "OFFLINE" : "ACTIVE";
    camPillEl.classList.remove("on", "off");
    camPillEl.classList.add(offline ? "off" : "on");
  }
}

function hideCameraSources() {
  if (cameraStreamEl) {
    cameraStreamEl.classList.remove("live");
  }
  if (cameraVideoEl) {
    cameraVideoEl.classList.remove("live");
  }
}

function getStreamUrls() {
  const url = new URL(window.location.href);
  const fromQuery = url.searchParams.get("cameraStream");
  if (fromQuery) {
    return [fromQuery];
  }

  const candidates = [];
  const protocol = window.location.protocol === "https:" ? "https:" : "http:";
  const hostName = window.location.hostname;

  if (hostName) {
    candidates.push(`${protocol}//${hostName}:8081/api/stream.mjpeg?src=usb`);
    candidates.push(`${protocol}//${hostName}:8081/stream.mjpg`);
  }

  if (hostName && hostName !== "localhost" && hostName !== "127.0.0.1") {
    candidates.push("http://localhost:8081/api/stream.mjpeg?src=usb");
    candidates.push(DEFAULT_CAMERA_STREAM_URL);
  }

  candidates.push("http://127.0.0.1:8081/api/stream.mjpeg?src=usb");
  candidates.push("http://127.0.0.1:8081/stream.mjpg");

  return Array.from(new Set(candidates));
}

function waitForImageLoad(img, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timeoutId = window.setTimeout(() => {
      cleanup();
      reject(new Error("Image stream timeout"));
    }, timeoutMs);

    function cleanup() {
      window.clearTimeout(timeoutId);
      img.removeEventListener("load", onLoad);
      img.removeEventListener("error", onError);
    }

    function onLoad() {
      cleanup();
      resolve();
    }

    function onError() {
      cleanup();
      reject(new Error("Image stream error"));
    }

    img.addEventListener("load", onLoad, { once: true });
    img.addEventListener("error", onError, { once: true });
  });
}

async function tryNetworkStream() {
  if (!cameraStreamEl) {
    return false;
  }

  const streamUrls = getStreamUrls();

  for (const streamUrl of streamUrls) {
    cameraStreamEl.src = streamUrl;

    try {
      await waitForImageLoad(cameraStreamEl, 3500);
      hideCameraSources();
      cameraStreamEl.classList.add("live");
      cameraFallbackEl.classList.add("camera-hidden");
      setCameraState("LIVE STREAM (8081)");
      return true;
    } catch {
      cameraStreamEl.classList.remove("live");
      cameraStreamEl.removeAttribute("src");
    }
  }

  if (cameraStreamEl) {
    cameraStreamEl.classList.remove("live");
    cameraStreamEl.removeAttribute("src");
  }

  return false;
}

async function initCamera() {
  if (!cameraVideoEl || !cameraFallbackEl || !cameraStateEl) {
    return;
  }

  setCameraState("VERBINDEN...");
  if (camPillEl && camPillTextEl) {
    camPillTextEl.textContent = "CONNECTING";
    camPillEl.classList.remove("on", "off");
  }

  const hasNetworkStream = await tryNetworkStream();
  if (hasNetworkStream) {
    return;
  }

  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    setCameraState("OFFLINE", true);
    return;
  }

  try {
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 1280 },
          height: { ideal: 720 },
          facingMode: "environment"
        },
        audio: false
      });
    } catch {
      // Some Linux camera drivers do not support facingMode constraints.
      stream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: false
      });
    }

    hideCameraSources();
    cameraVideoEl.srcObject = stream;
    cameraVideoEl.classList.add("live");
    cameraFallbackEl.classList.add("camera-hidden");
    setCameraState("LIVE USB CAMERA");
  } catch {
    hideCameraSources();
    cameraVideoEl.classList.remove("live");
    cameraFallbackEl.classList.remove("camera-hidden");
    setCameraState("OFFLINE", true);
  }
}

renderPresence();
renderMessages();
renderActions();
renderNav();
updateClock();
initCamera();
loadActionsFromHub();
wireActionBuilder();

setInterval(updateClock, 1000);
setInterval(cycleSpeech, 3800);
setInterval(loadActionsFromHub, 10000);
