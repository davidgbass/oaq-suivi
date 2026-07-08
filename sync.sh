#!/bin/bash
# sync.sh — SharePoint (via OneDrive) → dashboard GitHub Pages.
# Durci (audit 2026-07-07) : verrou anti-course, matérialisation avec reprises,
# validation de structure (via extract.py), notification macOS en cas d'échec.
set -uo pipefail
BASE="/Users/david/oaq-suivi"
LOG="$BASE/sync.log"
STATE="$BASE/.last-sync-checksum"
XLSX="$HOME/Library/CloudStorage/OneDrive-SharedLibraries-OAPQ/Public - 01-Planification stratégique 2026-2029/OAQ-Suivi-plan-strategique.xlsx"
cd "$BASE"

log(){ echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" >> "$LOG"; }
fail(){ log "ÉCHEC : $*"
  osascript -e "display notification \"$*\" with title \"OAQ Suivi — sync en échec\"" 2>/dev/null || true
  exit 1; }

# 0. Verrou : une seule exécution à la fois (l'agent et une sync manuelle peuvent se croiser)
# (mkdir est atomique ; flock n'existe pas sur macOS. Verrou > 10 min = périmé, on le reprend.)
LOCK="$BASE/.sync.lock.d"
if ! mkdir "$LOCK" 2>/dev/null; then
  AGE=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt 600 ]; then log "déjà en cours — on laisse l'autre finir"; exit 0; fi
  log "verrou périmé (${AGE}s) — repris"
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# 1. Fichier présent ? (chemin direct, découverte en repli — en ignorant les domaines archivés)
if [ ! -e "$XLSX" ]; then
  XLSX=$(find "$HOME/Library/CloudStorage" -maxdepth 8 -name "OAQ-Suivi-plan-strategique.xlsx" \
         -not -path "*(20*" -print -quit 2>/dev/null || true)
  [ -n "$XLSX" ] || fail "fichier introuvable (bibliothèque non synchronisée ?)"
fi

# 1b. Boîte d'envoi : si data/outbox.xlsx existe, le déposer sur SharePoint (écriture via
#     le canal autorisé du binaire oaq-sync). Sauvegarde de l'état distant AVANT dépôt.
if [ -f "$BASE/data/outbox.xlsx" ]; then
  cat "$XLSX" > "data/backups/OAQ-Suivi-avant-depot-$(date '+%Y-%m-%d-%H%M%S').xlsx" 2>/dev/null \
    || log "dépôt : sauvegarde préalable illisible (fichier évincé) — poursuite prudente"
  if cat "$BASE/data/outbox.xlsx" > "$XLSX"; then
    rm -f "$BASE/data/outbox.xlsx"
    log "OUTBOX déposée sur SharePoint (via OneDrive)"
  else
    fail "dépôt de la boîte d'envoi impossible (écriture refusée)"
  fi
fi

# 2. Matérialisation avec reprises (OneDrive évince les fichiers → lecture EDEADLK/timeout)
SUM=""
for i in 1 2 3 4 5 6; do
  SUM=$(shasum -a 256 "$XLSX" 2>/dev/null | cut -d' ' -f1) && [ -n "$SUM" ] && break
  log "lecture impossible (essai $i/6 — fichier en ligne seulement ?) — nouvel essai dans 15 s"
  sleep 15
done
[ -n "$SUM" ] || fail "fichier illisible après 6 essais — épingler le dossier dans le Finder (Toujours conserver sur cet appareil)"

# 3. Inchangé → rien à faire
[ -f "$STATE" ] && [ "$(cat "$STATE")" = "$SUM" ] && exit 0

# 4. Sauvegarde horodatée AVANT tout (cat : cp échoue sur les fichiers en ligne seulement)
mkdir -p data/backups
cat "$XLSX" > "data/backups/OAQ-Suivi-$(date '+%Y-%m-%d-%H%M%S').xlsx" \
  || fail "sauvegarde impossible (lecture interrompue)"
ls -t data/backups/OAQ-Suivi-*.xlsx 2>/dev/null | tail -n +41 | xargs rm -f 2>/dev/null || true

# 5. Extraire (valide aussi la structure du fichier) + reconstruire
PY="/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
[ -x "$PY" ] || PY=$(command -v python3)
"$PY" extract.py --current --xlsx "$XLSX" >> "$LOG" 2>&1 \
  || fail "extraction refusée (structure du fichier modifiée ? voir sync.log)"
"$PY" build.py >> "$LOG" 2>&1 || fail "génération du dashboard en erreur"

# 6. Publier seulement si la page a changé
if ! git diff --quiet -- index.html; then
  git add index.html \
    && git -c user.name="OAQ suivi (agent)" -c user.email="gelinas.audio@gmail.com" \
         commit -q -m "Mise à jour automatique depuis SharePoint ($(date '+%Y-%m-%d %H:%M'))" \
    && git push -q \
    || fail "publication git en erreur"
  log "publié (checksum ${SUM:0:12}…)"
else
  log "rebuild sans changement visuel — pas de publication"
fi
echo "$SUM" > "$STATE"
