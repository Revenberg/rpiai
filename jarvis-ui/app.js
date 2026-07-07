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

const DEFAULT_CAMERA_STREAM_URL = "http://localhost:8081/?action=stream";

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

const actions = [
  { time: "15:42:18", text: "Lichten woonkamer gedimd naar 30%", source: "Homey" },
  { time: "15:42:05", text: "Hek geopend", source: "Homey" },
  { time: "15:40:12", text: "Thermostaat staat ingesteld op 20 C", source: "Home Assistant" },
  { time: "15:39:47", text: "Verbruik woonkamer opgevraagd", source: "Home Assistant" },
  { time: "15:38:33", text: "Aanwezigheid gecontroleerd", source: "Home Assistant" }
];

const navItems = ["OVERZICHT", "VERLICHTING", "KLIMAAT", "BEVEILIGING", "ENERGIE", "MEDIA", "INSTELLINGEN"];
const speechStates = ["Ik luister...", "Commando ontvangen", "Samantha verwerkt actie", "Systeem standby"];

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
  actions.forEach((item) => {
    const row = document.createElement("article");
    row.className = "action-item";
    row.innerHTML = `<div>${item.text}</div><div class="meta">${item.time} • ${item.source}</div>`;
    actionLogEl.appendChild(row);
  });
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

function getStreamUrl() {
  const url = new URL(window.location.href);
  const fromQuery = url.searchParams.get("cameraStream");
  if (fromQuery) {
    return fromQuery;
  }

  return DEFAULT_CAMERA_STREAM_URL;
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

  const streamUrl = getStreamUrl();
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
    return false;
  }
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

setInterval(updateClock, 1000);
setInterval(cycleSpeech, 3800);
