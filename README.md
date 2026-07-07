# OAQ — Suivi du plan stratégique 2026-2029

Tableau de bord interactif (curseur d'évolution entre les points de mesure) pour le
Conseil d'administration de l'OAQ. Le contenu est chiffré (AES-256-GCM) et déchiffré
uniquement dans le navigateur — voir `index.html`.

## Pipeline (local seulement — jamais publié)

1. `python3 extract.py --date AAAA-MM-JJ --label "CA du ..."` — extrait un snapshot
   depuis `~/Downloads/OAQ-Suivi-plan-strategique-SIMPLE.xlsx` (ou la copie SharePoint synchronisée)
   vers `data/snapshots/`.
2. `python3 build.py` — régénère `preview.html` (clair, révision locale) et
   `index.html` (chiffré, seul artefact publiable).
3. `git add index.html robots.txt && git commit && git push` — publication GitHub Pages.

`build.py` (contient le mot de passe), `data/` (niveau 3 en clair) et `preview.html`
sont exclus du dépôt par `.gitignore`.

Les snapshots `DEMO-*` sont des données fictives d'illustration :
`rm data/snapshots/DEMO-*.json && python3 build.py` pour les retirer.
