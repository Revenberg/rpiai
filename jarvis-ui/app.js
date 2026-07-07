const presenceListEl = document.getElementById("presenceList");
const chatLogEl = document.getElementById("chatLog");
const actionLogEl = document.getElementById("actionLog");
const bottomNavEl = document.getElementById("bottomNav");
const clockEl = document.getElementById("clockLabel");
const dayEl = document.getElementById("dayLabel");
const speechEl = document.getElementById("speechText");

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

renderPresence();
renderMessages();
renderActions();
renderNav();
updateClock();

setInterval(updateClock, 1000);
setInterval(cycleSpeech, 3800);
