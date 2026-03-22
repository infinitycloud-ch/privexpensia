#!/usr/bin/env python3
"""
Test du modèle Qwen avec MLX
"""

import sys
import json
from pathlib import Path
sys.path.append('~/Library/Python/3.13/lib/python/site-packages')

from mlx_lm import load, generate

model_path = Path.home() / "Documents/models/qwen2.5-0.5b-4bit"

print("🤖 TEST QWEN AVEC MLX")
print("="*50)
print(f"Modèle: {model_path}")
print()

# Test prompt
test_receipt = """
Extract expense information from this receipt:

CARREFOUR MARKET
15 Rue de la République
75001 Paris

Date: 14/09/2025 15:42

ALIMENTATION
Pain Complet Bio          2.45
Lait Demi-écrémé 1L      1.89
Pommes Golden 1kg        3.50
Fromage Comté 200g      12.90
Yaourt Nature x4         2.99

SOUS-TOTAL              23.73
TVA 5.5%                 1.31
TOTAL                   25.04

CB VISA ****1234        25.04

Merci de votre visite!

Return JSON with: merchant, total_amount, tax_amount, date, category, items
"""

print("📥 Chargement du modèle...")
try:
    model, tokenizer = load(str(model_path))
    print("✅ Modèle chargé!")
    print()
    
    print("📝 Prompt:")
    print(test_receipt[:200] + "...")
    print()
    
    print("⚡ Génération en cours...")
    response = generate(
        model,
        tokenizer,
        prompt=test_receipt,
        max_tokens=500
    )
    
    print("🎯 Réponse du modèle:")
    print(response)
    print()
    
    # Essayer d'extraire le JSON
    try:
        # Chercher le JSON dans la réponse
        if '{' in response:
            json_start = response.index('{')
            json_end = response.rfind('}') + 1
            json_str = response[json_start:json_end]
            data = json.loads(json_str)
            
            print("📦 Données extraites:")
            print(json.dumps(data, indent=2, ensure_ascii=False))
    except:
        print("⚠️ Pas de JSON valide trouvé")
        
except Exception as e:
    print(f"❌ Erreur: {e}")
    print("Le modèle doit être converti au format MLX")