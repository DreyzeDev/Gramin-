(function () {
  const knownVersions = ["0.5.0", "0.6.0", "0.6.1", "0.6.2", "0.6.3", "0.6.4", "0.6.5", "0.6.6", "0.6.7", "0.6.8", "0.6.9"];
  const baselineVersion = "0.6.0";
  let installedVersion = localStorage.getItem("gramin-installed-version") || baselineVersion;

  if (!knownVersions.includes(installedVersion)) installedVersion = baselineVersion;
  window.__GRAMIN_INSTALLED_VERSION = installedVersion;

  const base = `/app-assets/releases/${installedVersion}`;
  document.write(`<link rel="stylesheet" href="${base}/app.css">`);
  document.write(`<script src="${base}/app.js" defer><\/script>`);
})();
