(function () {
  const manifestURL = "/app-assets/releases.json";
  let availableRelease = null;

  const sheet = document.getElementById("update-sheet");
  const version = document.getElementById("update-version");
  const notes = document.getElementById("update-notes");
  const laterButton = document.getElementById("update-later");
  const updateButton = document.getElementById("update-now");

  async function getManifest() {
    const response = await fetch(`${manifestURL}?t=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error("Update manifest is unavailable");
    return response.json();
  }

  function showUpdate(release) {
    if (!release || release.version === window.__GRAMIN_INSTALLED_VERSION) return;
    if (sessionStorage.getItem("gramin-update-later") === release.version) return;
    availableRelease = release;
    version.textContent = `Версия ${release.version}`;
    notes.innerHTML = release.notes.map(item => `<li>${escapeHTML(item)}</li>`).join("");
    sheet.hidden = false;
  }

  async function checkForUpdates() {
    try {
      const manifest = await getManifest();
      const release = manifest.releases.find(item => item.version === manifest.latest);
      showUpdate(release);
    } catch (_) {
      // Update checks must never prevent the banking interface from opening.
    }
  }

  function escapeHTML(value) {
    const node = document.createElement("span");
    node.textContent = value;
    return node.innerHTML;
  }

  laterButton.addEventListener("click", () => {
    if (availableRelease) sessionStorage.setItem("gramin-update-later", availableRelease.version);
    sheet.hidden = true;
  });

  updateButton.addEventListener("click", () => {
    if (!availableRelease) return;
    updateButton.disabled = true;
    updateButton.textContent = "Обновляем…";
    localStorage.setItem("gramin-installed-version", availableRelease.version);
    sessionStorage.removeItem("gramin-update-later");
    location.reload();
  });

  checkForUpdates();
  setInterval(checkForUpdates, 60000);
})();
