#!/bin/bash
# sync.sh — Branche le fichier SharePoint (synchronisé par OneDrive) sur le dashboard GitHub Pages.
# Lancé par le LaunchAgent com.oaq.suivi-sync (à chaque changement du dossier synchronisé + aux 10 min).
# Idempotent : ne reconstruit et ne publie que si le fichier a réellement changé.
set -euo pipefail
BASE="/Users/david/oaq-suivi"
LOG="$BASE/sync.log"
STATE="$BASE/.last-sync-checksum"
cd "$BASE"

log(){ echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" >> "$LOG"; }

# 1. Localiser le fichier maître dans les bibliothèques OneDrive synchronisées
XLSX=$(find "$HOME/Library/CloudStorage" -maxdepth 8 -name "OAQ-Suivi-plan-strategique.xlsx" -print -quit 2>/dev/null || true)
if [ -z "$XLSX" ]; then
  log "fichier SharePoint introuvable localement (bibliothèque « Public » non synchronisée ?)"
  exit 0
fi

# 2. Ne rien faire si inchangé (OneDrive touche parfois sans modifier)
SUM=$(shasum -a 256 "$XLSX" | cut -d' ' -f1)
[ -f "$STATE" ] && [ "$(cat "$STATE")" = "$SUM" ] && exit 0

# 3. Sauvegarde horodatée AVANT toute chose (leçon apprise) — garder les 40 dernières
mkdir -p data/backups
cp "$XLSX" "data/backups/OAQ-Suivi-$(date '+%Y-%m-%d-%H%M%S').xlsx"
ls -t data/backups/OAQ-Suivi-*.xlsx 2>/dev/null | tail -n +41 | xargs rm -f 2>/dev/null || true

# 4. Extraire (snapshot roulant « État courant ») + reconstruire
PY=$(command -v python3)
"$PY" extract.py --current --xlsx "$XLSX" >> "$LOG" 2>&1
"$PY" build.py >> "$LOG" 2>&1

# 5. Publier seulement si la page a changé
if ! git diff --quiet -- index.html; then
  git add index.html
  git -c user.name="OAQ suivi (agent)" -c user.email="gelinas.audio@gmail.com" \
      commit -q -m "Mise à jour automatique depuis SharePoint ($(date '+%Y-%m-%d %H:%M'))"
  git push -q
  log "publié (checksum ${SUM:0:12}…)"
else
  log "rebuild sans changement visuel — pas de publication"
fi
echo "$SUM" > "$STATE"
