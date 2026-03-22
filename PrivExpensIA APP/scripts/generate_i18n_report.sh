#!/usr/bin/env bash
set -euo pipefail

DEVICE="9D1B772E-7D9B-4934-A7F4-D2829CEB0065"
APP_ID="com.minhtam.ExpenseAI"
OUT_DIR="./proof/i18n"
REPORT_HTML="${OUT_DIR}/report.html"
MANIFEST_JSON="${OUT_DIR}/manifest.json"
BUILD_LOG="./proof/build_log.txt"

langs=( "fr-CH" "de-CH" "it-CH" "en" "ja" "ko" "sk" "es" )

# 0) Préconditions
mkdir -p "${OUT_DIR}"
if [ ! -f "${BUILD_LOG}" ]; then
  echo "WARN: ${BUILD_LOG} manquant — je continue, mais pense à joindre le log de build."
fi

# 1) Boot/Ready
xcrun simctl boot "${DEVICE}" || true
xcrun simctl bootstatus "${DEVICE}" -b

# 2) Vérif existence des 8 captures (générées par i18n_snapshots.sh)
# Chercher les fichiers les plus récents pour chaque langue
missing=0
for L in "${langs[@]}"; do
  # Trouver le fichier le plus récent pour cette langue
  PNG=$(ls -t "${OUT_DIR}"/app_${L}_*.png 2>/dev/null | head -1)
  
  if [ -z "${PNG}" ] || [ ! -s "${PNG}" ]; then
    echo "MISSING: app_${L}*.png"
    missing=$((missing+1))
  else
    # Filtre basique anti-simulation (taille minimale)
    sz=$(wc -c < "${PNG}" | tr -d ' ')
    if [ "${sz}" -lt 50000 ]; then
      echo "TOO_SMALL (<50KB): ${PNG} (${sz} bytes)"
      missing=$((missing+1))
    else
      # Créer un lien symbolique sans timestamp pour le rapport HTML
      ln -sf "$(basename "${PNG}")" "${OUT_DIR}/app_${L}.png"
      echo "Found: ${PNG} (${sz} bytes)"
    fi
  fi
done

if [ "${missing}" -ne 0 ]; then
  echo "✗ ÉCHEC : ${missing} capture(s) manquante(s) ou trop petites. Reprendre i18n_snapshots.sh."
  exit 2
fi

# 3) Manifest + checksums
{
  echo "{"
  echo "  \"device_udid\": \"${DEVICE}\","
  echo "  \"bundle\": \"${APP_ID}\","
  echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"images\": {"
  for i in "${!langs[@]}"; do
    L="${langs[$i]}"
    PNG="${OUT_DIR}/app_${L}.png"
    SUM=$(shasum -a 256 "${PNG}" | awk '{print $1}')
    printf '    "%s": { "file": "app_%s.png", "sha256": "%s" }' "${L}" "${L}" "${SUM}"
    if [ "${i}" -lt $(( ${#langs[@]} - 1 )) ]; then printf ',\n'; else printf '\n'; fi
  done
  echo "  }"
  echo "}"
} > "${MANIFEST_JSON}"

# 4) Rapport HTML (galerie responsive) + auto-ouverture
cat > "${REPORT_HTML}" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>PrivExpensIA — I18N Report</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root { color-scheme: dark light; }
  body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", Arial, sans-serif; margin: 24px; }
  header { margin-bottom: 16px; }
  h1 { font-size: 22px; margin: 0 0 6px 0; }
  .meta { color: #888; font-size: 12px; margin-bottom: 16px; }
  .grid { display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); }
  figure { margin: 0; padding: 12px; border: 1px solid #3333; border-radius: 12px; background: #1111; }
  figcaption { margin-top: 8px; font-size: 13px; color: #777; }
  img { width: 100%; border-radius: 10px; box-shadow: 0 4px 16px #0004; }
  code { background:#0002; padding:2px 4px; border-radius:4px; }
  .ok { color: #2ecc71; } .warn { color: #e67e22; }
</style>
</head>
<body>
<header>
  <h1>PrivExpensIA — I18N Snapshots</h1>
  <div class="meta" id="meta"></div>
</header>
<section class="grid" id="grid"></section>
<script>
(async () => {
  const res = await fetch('./manifest.json');
  const m = await res.json();
  const meta = document.getElementById('meta');
  meta.textContent = `Device UDID: ${m.device_udid} · Bundle: ${m.bundle} · Generated: ${m.generated_at}`;
  const grid = document.getElementById('grid');
  for (const [lang, info] of Object.entries(m.images)) {
    const card = document.createElement('figure');
    const img = document.createElement('img');
    img.src = './' + info.file;
    img.alt = lang;
    const cap = document.createElement('figcaption');
    cap.innerHTML = `<strong>${lang}</strong><br><code>${info.file}</code><br>SHA256: <code>${info.sha256}</code>`;
    card.appendChild(img); card.appendChild(cap); grid.appendChild(card);
  }
})();
</script>
</body>
</html>
HTML

# 5) Ouvrir le rapport dans le navigateur
open "${REPORT_HTML}"

echo "✅ Rapport prêt : ${REPORT_HTML}"