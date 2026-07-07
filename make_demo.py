#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_demo.py — Génère des snapshots DÉMO (données fictives, clairement étiquetées)
pour tester le curseur d'évolution avant que le vrai historique existe.

À SUPPRIMER quand de vrais snapshots s'accumulent :
    rm data/snapshots/DEMO-*.json && python3 build.py
"""
import json, os, copy

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, "data", "snapshots", "2026-07-06.json")

with open(SRC, encoding="utf-8") as f:
    base = json.load(f)

def find(snap, no):
    return next(a for a in snap["actions"] if a["no"] == no)

def jal(snap, prio):
    return next(j for j in snap["jalons"] if j["prio"] == prio)

# ---------- DÉMO 1 — CA de septembre 2026 ----------
s1 = copy.deepcopy(base)
s1.update(date="2026-09-18", label="CA septembre 2026 — DÉMO (données fictives)", demo=True)
a = find(s1, "2.3.1"); a["statut"] = "✅ Terminée"; a["quoi"] = "[DÉMO] Listes de mots livrées et diffusées aux membres"; a["maj"] = "2026-09-10"
a = find(s1, "3.1.1"); a["qui"] = "David"; a["statut"] = "🟡 Amorcée"; a["quoi"] = "[DÉMO] Porteur nommé au CA de septembre"; a["maj"] = "2026-09-18"
a = find(s1, "3.1.2"); a["qui"] = "David"; a["quoi"] = "[DÉMO] Porteur nommé"; a["maj"] = "2026-09-18"
a = find(s1, "2.1.3"); a["statut"] = "⛔ Bloquée"; a["bloque"] = True; a["quoi"] = "[DÉMO] Bloqué : attend la position OTC officielle avant de bâtir la formation — décision demandée au CA"; a["maj"] = "2026-09-05"
a = find(s1, "1.1.1"); a["qui"] = "Alice"; a["statut"] = "🟢 En cours"; a["quoi"] = "[DÉMO] Première rencontre de la table de concertation tenue"; a["maj"] = "2026-09-12"
j = jal(s1, "1.2"); j["statut"] = "⏳ En cours"; j["comm"] = "[DÉMO] Mémoire RAMQ en rédaction"
for k in s1["kpis"]:
    if k["id"] == "K7": k["actuel"] = "[DÉMO] 6 instances"; k["comm"] = "[DÉMO] Baseline établie"

# ---------- DÉMO 2 — CA de novembre 2026 ----------
s2 = copy.deepcopy(s1)
s2.update(date="2026-11-20", label="CA novembre 2026 — DÉMO (données fictives)", demo=True)
a = find(s2, "2.1.3"); a["statut"] = "🟡 Amorcée"; a["bloque"] = False; a["quoi"] = "[DÉMO] Débloqué : position OTC adoptée — plan de formation en montage"; a["maj"] = "2026-11-02"
a = find(s2, "1.2.1"); a["statut"] = "🟢 En cours"; a["quoi"] = "[DÉMO] Rencontres cabinet + mémoire déposé"; a["maj"] = "2026-11-15"
a = find(s2, "4.1.1"); a["statut"] = "🟢 En cours"; a["quoi"] = "[DÉMO] Cadre de gestion documentaire en déploiement"; a["maj"] = "2026-11-10"
a = find(s2, "3.3.1"); a["statut"] = "🟡 Amorcée"; a["quoi"] = "[DÉMO] Axes de communication esquissés"; a["maj"] = "2026-11-12"
a = find(s2, "1.3.2"); a["statut"] = "🟡 Amorcée"; a["quoi"] = "[DÉMO] Projet pilote CHSLD identifié"; a["maj"] = "2026-11-18"
j = jal(s2, "1.2"); j["statut"] = "✓ Atteint"; j["comm"] = "[DÉMO] Mémoire déposé + position OTC publiée"
j = jal(s2, "3.2"); j["statut"] = "⏳ En cours"

# ---------- DÉMO 3 — CA de janvier 2027 ----------
s3 = copy.deepcopy(s2)
s3.update(date="2027-01-22", label="CA janvier 2027 — DÉMO (données fictives)", demo=True)
a = find(s3, "2.4.1"); a["statut"] = "✅ Terminée"; a["quoi"] = "[DÉMO] Sondage besoins de formation complété"; a["maj"] = "2027-01-10"
a = find(s3, "2.1.1"); a["statut"] = "✅ Terminée"; a["quoi"] = "[DÉMO] Position OTC adoptée et publiée"; a["maj"] = "2026-12-15"
a = find(s3, "3.1.1"); a["statut"] = "🟢 En cours"; a["quoi"] = "[DÉMO] Espaces d'intervention cartographiés"; a["maj"] = "2027-01-15"
a = find(s3, "2.2.3"); a["statut"] = "🟡 Amorcée"; a["quoi"] = "[DÉMO] Étude de faisabilité outils IA amorcée"; a["maj"] = "2027-01-20"
a = find(s3, "3.2.1"); a["statut"] = "⛔ Bloquée"; a["bloque"] = True; a["quoi"] = "[DÉMO] Bloqué : réponse OOAQ en attente depuis 2 mois — relance politique demandée"; a["maj"] = "2027-01-18"
j = jal(s3, "4.1"); j["statut"] = "⏳ En cours"
for k in s3["kpis"]:
    if k["id"] == "K2": k["actuel"] = "[DÉMO] 46 %"; k["comm"] = "[DÉMO] +7 pts vs baseline"

for s in (s1, s2, s3):
    out = os.path.join(BASE, "data", "snapshots", f"DEMO-{s['date']}.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=1)
    print("Snapshot DÉMO écrit :", out)
