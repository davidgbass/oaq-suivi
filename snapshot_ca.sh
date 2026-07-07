#!/bin/bash
# snapshot_ca.sh — Fige l'état courant comme POINT DE MESURE officiel (avant une séance du CA).
# Usage :  ./snapshot_ca.sh "CA du 18 septembre 2026"
# Le point gelé devient un cran permanent du curseur temporel ; l'état courant continue d'évoluer.
set -euo pipefail
BASE="/Users/david/oaq-suivi"
cd "$BASE"
LABEL="${1:?Usage: ./snapshot_ca.sh \"CA du ...\"}"
DATE=$(date '+%Y-%m-%d')
if [ ! -f data/snapshots/CURRENT.json ]; then
  echo "Pas d'état courant — lancer ./sync.sh d'abord."; exit 1
fi
python3 - "$DATE" "$LABEL" << 'EOF'
import json, sys
d, label = sys.argv[1], sys.argv[2]
s = json.load(open("data/snapshots/CURRENT.json", encoding="utf-8"))
s["date"] = d; s["label"] = label; s["demo"] = False
json.dump(s, open(f"data/snapshots/{d}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"Point de mesure gelé : data/snapshots/{d}.json — « {label} »")
EOF
python3 build.py
git add index.html && git -c user.name="OAQ suivi (agent)" -c user.email="gelinas.audio@gmail.com" \
    commit -q -m "Point de mesure : $LABEL" && git push -q
echo "Publié."
