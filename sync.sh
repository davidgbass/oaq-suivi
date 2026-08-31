#!/bin/bash
# sync.sh — SharePoint (via OneDrive) → dashboard GitHub Pages.
# Durci (audit 2026-07-07) : verrou anti-course, matérialisation avec reprises,
# validation de structure (via extract.py), notification macOS en cas d'échec.
# Durci (2026-07-18) : toute copie .xlsx est écrite en fichier temporaire, VALIDÉE
# (archive zip intègre), puis seulement déplacée en place. Motif : du 11 au 17 juillet
# 2026, l'éviction OneDrive a produit 7 sauvegardes vides/corrompues — la panne
# détruisait son propre filet de secours.
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

# valider_xlsx <fichier> — vrai si le fichier est un .xlsx exploitable.
# Un fichier tronqué par l'éviction OneDrive passe souvent le test de l'en-tête « PK »
# mais échoue au test d'intégrité de l'archive : les deux sont nécessaires.
valider_xlsx(){
  local f="$1"
  [ -s "$f" ] || return 1                               # non vide
  [ "$(head -c2 "$f" 2>/dev/null)" = "PK" ] || return 1  # signature zip
  unzip -tqq "$f" >/dev/null 2>&1 || return 1            # archive intègre
  unzip -l "$f" 2>/dev/null | grep -q "xl/workbook.xml"  # bien un classeur
}

# copier_valide <source> <destination> — copie via temporaire, valide, puis met en place.
# Rien n'atterrit à la destination si la lecture a été interrompue.
copier_valide(){
  local src="$1" dst="$2" tmp
  tmp="$(mktemp "${dst}.tmp.XXXXXX")" || return 1
  if ! cat "$src" > "$tmp" 2>/dev/null; then rm -f "$tmp"; return 1; fi
  if ! valider_xlsx "$tmp"; then rm -f "$tmp"; return 1; fi
  mv -f "$tmp" "$dst"
}

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
  # L'outbox part écraser SharePoint : la valider AVANT tout, sinon on détruit le distant.
  valider_xlsx "$BASE/data/outbox.xlsx" \
    || fail "dépôt refusé : data/outbox.xlsx est corrompue ou incomplète (le fichier SharePoint n'a PAS été touché)"
  # Sauvegarde préalable de l'état distant — bloquante : sans filet valide, on ne dépose pas.
  mkdir -p data/backups
  copier_valide "$XLSX" "data/backups/OAQ-Suivi-avant-depot-$(date '+%Y-%m-%d-%H%M%S').xlsx" \
    || fail "dépôt refusé : sauvegarde préalable impossible ou corrompue (fichier évincé ?) — épingler le dossier dans le Finder"
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
copier_valide "$XLSX" "data/backups/OAQ-Suivi-$(date '+%Y-%m-%d-%H%M%S').xlsx" \
  || fail "sauvegarde impossible ou corrompue (lecture interrompue — fichier évincé ?) — épingler le dossier dans le Finder (Toujours conserver sur cet appareil)"

# 4b. Purge des sauvegardes corrompues héritées (épisode d'éviction du 11-17 juillet 2026).
#     Elles occupent des places dans la rotation et donnent une fausse impression de filet.
for b in data/backups/OAQ-Suivi-*.xlsx; do
  [ -e "$b" ] || continue
  valider_xlsx "$b" || { rm -f "$b"; log "sauvegarde corrompue purgée : $(basename "$b")"; }
done

# 4c. Rotation : ne conserver que les 40 plus récentes (toutes valides à ce stade)
ls -t data/backups/OAQ-Suivi-*.xlsx 2>/dev/null | tail -n +41 | xargs rm -f 2>/dev/null || true

# 5. Extraire (valide aussi la structure du fichier) + reconstruire
PY="/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
[ -x "$PY" ] || PY=$(command -v python3)
#    Un point d'historique par date de calendrier (écrasé si la sync repasse le même
#    jour) — remplace l'ancien snapshot CURRENT.json à sens unique, qui écrasait
#    « aujourd'hui » à chaque sync et ne laissait jamais de trace des dates
#    intermédiaires : le curseur restait coincé entre l'ancienne baseline et
#    « maintenant » et n'illustrait jamais la progression réelle.
"$PY" extract.py --date "$(date '+%Y-%m-%d')" --xlsx "$XLSX" >> "$LOG" 2>&1 \
  || fail "extraction refusée (structure du fichier modifiée ? voir sync.log)"
rm -f data/snapshots/CURRENT.json
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
