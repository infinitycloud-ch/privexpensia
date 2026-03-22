#!/usr/bin/env python3
"""
Analyse de vidéo avec Gemini 1.5 Pro
Utilise l'API Google pour analyser directement la vidéo complète
"""

import os
import sys
import base64
import json
import time
from pathlib import Path
from datetime import datetime

# Configuration Gemini
GEMINI_API_KEY = "AIzaSyBngEd6ciAtKS_gzexsAWy9h783pw4iqqA"

def analyze_video_with_gemini(video_path):
    """
    Analyse une vidéo complète avec Gemini 1.5 Pro
    """
    import requests

    print(f"🎬 Analyse de la vidéo avec Gemini 1.5 Pro")
    print(f"📹 Fichier: {video_path}")
    print("="*60)

    # Lire la vidéo et l'encoder en base64
    with open(video_path, "rb") as video_file:
        video_data = base64.b64encode(video_file.read()).decode()

    # Prompt spécialisé pour la localisation
    prompt = """Analyse cette vidéo d'une application iOS testée en 4 langues (FR, EN, DE, ES).

MISSION CRITIQUE - Détecte TOUS les problèmes de localisation:

1. UNDERSCORES: Cherche tout texte contenant "_" (ex: "home_title", "settings_label")
   C'est CRITIQUE - aucun underscore ne doit apparaître.

2. TEXTES NON TRADUITS: Identifie tout texte anglais quand l'interface est en FR/DE/ES

3. Pour chaque segment de ~15 secondes (une langue):
   - 0:00-0:15 → Français
   - 0:15-0:30 → English
   - 0:30-0:45 → Deutsch
   - 0:45-1:00 → Español

4. Vérifie spécifiquement:
   - Salutations (Bonjour/Good Morning/Guten Morgen/Buenos días)
   - Jours de la semaine
   - Labels UI (Today's Spending, Budget Left, etc.)
   - Menus Settings

Pour chaque problème trouvé, indique:
- Timestamp exact
- Langue active
- Texte problématique
- Correction attendue
- Priorité (CRITIQUE/HAUTE/MOYENNE)

Donne un SCORE DE CONFORMITÉ sur 100."""

    # Appel API Gemini
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key={GEMINI_API_KEY}"

    payload = {
        "contents": [{
            "parts": [
                {"text": prompt},
                {
                    "inline_data": {
                        "mime_type": "video/mp4",
                        "data": video_data
                    }
                }
            ]
        }],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 8192
        }
    }

    print("🤖 Envoi à Gemini pour analyse...")

    try:
        response = requests.post(url, json=payload, headers={"Content-Type": "application/json"})

        if response.status_code == 200:
            result = response.json()

            # Extraire le texte de la réponse
            if "candidates" in result and len(result["candidates"]) > 0:
                analysis_text = result["candidates"][0]["content"]["parts"][0]["text"]
                print("\n" + "="*60)
                print("📊 ANALYSE GEMINI:")
                print("="*60)
                print(analysis_text)
                return analysis_text
            else:
                print("❌ Réponse vide de Gemini")
                return None

        else:
            print(f"❌ Erreur API: {response.status_code}")
            print(response.text)
            return None

    except Exception as e:
        print(f"❌ Erreur: {str(e)}")
        return None

def generate_report(analysis_result, video_path):
    """
    Génère un rapport basé sur l'analyse Gemini
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    report_path = str(Path(video_path).with_suffix('')) + "_GEMINI_analysis.md"

    report_content = f"""# 🤖 Rapport d'Analyse Gemini - Validation Localisation

**Date**: {timestamp}
**Vidéo analysée**: {Path(video_path).name}
**Modèle**: Gemini 1.5 Pro (Analyse vidéo native)

---

## Analyse Complète

{analysis_result if analysis_result else "Erreur dans l'analyse"}

---

## Métadonnées

- **Durée vidéo**: ~60 secondes
- **Langues testées**: FR, EN, DE, ES
- **Type d'analyse**: Vidéo complète (pas d'extraction de frames)
- **API Key**: Configurée ✅

---

*Rapport généré automatiquement par Gemini Video Analyzer*
"""

    with open(report_path, 'w') as f:
        f.write(report_content)

    print(f"\n📄 Rapport sauvegardé: {report_path}")
    return report_path

def main():
    if len(sys.argv) < 2:
        # Utiliser la dernière vidéo générée
        video_dir = Path("~/moulinsart/PrivExpensIA/validation/videos")
        videos = list(video_dir.glob("localization_test_*.mp4"))
        if not videos:
            print("❌ Aucune vidéo trouvée")
            sys.exit(1)
        video_path = str(max(videos, key=lambda p: p.stat().st_mtime))
        print(f"📹 Utilisation de la dernière vidéo: {Path(video_path).name}")
    else:
        video_path = sys.argv[1]

    if not Path(video_path).exists():
        print(f"❌ Vidéo non trouvée: {video_path}")
        sys.exit(1)

    # Vérifier la taille de la vidéo
    video_size = Path(video_path).stat().st_size / (1024 * 1024)  # En MB
    print(f"📊 Taille de la vidéo: {video_size:.2f} MB")

    if video_size > 20:
        print("⚠️ Vidéo > 20MB, l'upload peut prendre du temps...")

    print("\n🚀 DÉMARRAGE DE L'ANALYSE GEMINI")
    print("="*60)

    # Analyser avec Gemini
    analysis_result = analyze_video_with_gemini(video_path)

    if analysis_result:
        # Générer le rapport
        report_path = generate_report(analysis_result, video_path)

        print("\n✅ ANALYSE TERMINÉE AVEC SUCCÈS!")
        print(f"   Rapport disponible: {report_path}")

        # Extraire le score si présent
        if "score" in analysis_result.lower():
            lines = analysis_result.split('\n')
            for line in lines:
                if "score" in line.lower() and "/100" in line:
                    print(f"   {line.strip()}")
                    break
    else:
        print("\n❌ Échec de l'analyse")
        sys.exit(1)

if __name__ == "__main__":
    main()