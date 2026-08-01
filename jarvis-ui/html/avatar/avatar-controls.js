const speakInput = document.getElementById("speakInput");
const actionButtons = Array.from(document.querySelectorAll("[data-action]"));

function withAvatarApi(run) {
  const api = window.__vrmApi;
  if (!api) {
    return false;
  }

  run(api);
  return true;
}

function triggerAction(action) {
  return withAvatarApi((api) => {
    if (action === "blink") {
      api.blink();
      return;
    }

    if (action === "nod-yes") {
      api.nodYes();
      return;
    }

    if (action === "nod-no") {
      api.nodNo();
    }
  });
}

actionButtons.forEach((button) => {
  button.addEventListener("click", () => {
    triggerAction(button.dataset.action || "");
  });
});

if (speakInput) {
  speakInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") {
      return;
    }

    const text = speakInput.value.trim();
    if (!text) {
      return;
    }

    const applied = withAvatarApi((api) => {
      api.speakText(text);
    });

    if (applied) {
      speakInput.value = "";
    }
  });
}
