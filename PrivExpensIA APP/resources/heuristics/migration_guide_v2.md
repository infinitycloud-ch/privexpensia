# 🔄 Guide de Migration v1 → v2
## Pipeline d'Extraction PrivExpensIA

**Version**: 2.0.0  
**Date**: 2025-01-12  
**Impact**: MAJEUR - Architecture hybride heuristiques + AI

---

## 🎯 Changements Majeurs

### 1. Architecture Pipeline
**v1**: Extraction séquentielle (OCR → Heuristiques OU AI)  
**v2**: Pipeline hybride intelligent (OCR → Heuristiques + AI + Fusion)

### 2. Modèle AI
**v1**: GPT-3.5 via API  
**v2**: Qwen2.5 local (7B params)

### 3. Performance
**v1**: 85% précision, 800ms moyenne  
**v2**: 95% précision, 450ms moyenne (mode hybride)

### 4. Structure Configuration
**v1**: Fichiers séparés (config.json, rules.json, etc.)  
**v2**: Configuration unifiée (pipeline_config.json)

---

## 🛠️ Étapes de Migration

### Étape 1: Sauvegarde
```bash
# Sauvegarder configuration actuelle
mkdir -p backups/v1
cp -r resources/config/* backups/v1/
cp src/extraction/* backups/v1/

# Documenter version actuelle
git tag -a v1.0-final -m "Dernière version avant migration v2"
git push --tags
```

### Étape 2: Installation Dépendances
```bash
# Python pour Qwen2.5
pip install -r requirements_v2.txt

# Télécharger modèle Qwen2.5
python scripts/download_qwen.py

# Vérifier installation
python -c "from transformers import AutoModel; print('Qwen2.5 ready')"
```

### Étape 3: Mise à Jour Configuration
```bash
# Copier nouveaux fichiers
cp -r resources/heuristics/* resources/config/

# Migrer configuration
python scripts/migrate_config.py \
  --input backups/v1/config.json \
  --output resources/config/pipeline_config.json
```

### Étape 4: Adapter Code Swift
```swift
// v1 - Ancien code
import PrivExpensIA_v1

let extractor = ReceiptExtractor(
    useAI: true,
    threshold: 0.8
)
let result = extractor.extract(image)

// v2 - Nouveau code
import PrivExpensIA

let pipeline = ExtractionPipeline(
    configPath: "resources/heuristics/pipeline_config.json",
    mode: .balanced
)
let result = try await pipeline.extract(from: image)
```

---

## 🔄 Mapping des Paramètres

### Configuration Principale
| Paramètre v1 | Paramètre v2 | Notes |
|-------------|--------------|--------|
| `use_ai` | `strategy.mode` | "hybrid", "heuristics_only", "ai_only" |
| `ai_model` | `ai.model` | "Qwen2.5" au lieu de "gpt-3.5" |
| `threshold` | `confidence.thresholds.auto_accept` | 0.90 par défaut |
| `timeout` | `performance.timeouts.total` | 5000ms par défaut |
| `cache_enabled` | `cache.enabled` | true par défaut |
| `language` | `country_configs.[country].languages` | Multi-langues supporté |

### Seuils de Confiance
```json
// v1
{
  "threshold": 0.8,
  "manual_threshold": 0.5
}

// v2
{
  "confidence": {
    "thresholds": {
      "auto_accept": 0.90,
      "ai_verification": 0.70,
      "manual_review": 0.50,
      "rejection": 0.30
    }
  }
}
```

### Règles d'Extraction
```json
// v1 - Séparées
"date_patterns": ["\\d{2}/\\d{2}/\\d{4}"],
"amount_patterns": ["\\$[0-9]+\\.[0-9]{2}"]

// v2 - Unifiées dans extraction_rules.json
{
  "date": {
    "formats": {
      "CH": "DD.MM.YYYY",
      "US": "MM/DD/YYYY"
    }
  },
  "currencies": {
    "CHF": {"patterns": [...], "symbol": "CHF"},
    "USD": {"patterns": [...], "symbol": "$"}
  }
}
```

---

## 🔍 Tests de Validation

### 1. Test Unitaire
```bash
# Tester extraction heuristiques
python tests/test_heuristics.py

# Tester intégration AI
python tests/test_qwen_integration.py

# Tester fusion résultats
python tests/test_fusion_strategy.py
```

### 2. Test de Non-Régression
```python
# Script de comparaison v1 vs v2
import json
from pathlib import Path

def compare_versions():
    test_receipts = Path("test_data/receipts/").glob("*.jpg")
    
    for receipt in test_receipts:
        v1_result = extract_v1(receipt)
        v2_result = extract_v2(receipt)
        
        # Comparer précision
        assert v2_result["confidence"] >= v1_result["confidence"]
        
        # Vérifier champs essentiels
        for field in ["date", "amount", "merchant"]:
            assert field in v2_result
    
    print("✅ Tous les tests passés")

compare_versions()
```

### 3. Test de Performance
```bash
# Benchmark v1 vs v2
python scripts/benchmark.py \
  --v1-config backups/v1/config.json \
  --v2-config resources/heuristics/pipeline_config.json \
  --samples 100

# Résultats attendus:
# v1: 85% accuracy, 800ms avg
# v2: 95% accuracy, 450ms avg
```

---

## ⚠️ Points d'Attention

### 1. Breaking Changes
- ❌ `ReceiptExtractor` class remplacée par `ExtractionPipeline`
- ❌ Méthode `extract()` maintenant asynchrone (`async/await`)
- ❌ Format de réponse modifié (nouveaux champs `metadata`, `extraction_method`)

### 2. Nouveaux Champs Réponse
```json
// v2 ajoute:
{
  "extraction_method": "hybrid",  // Nouveau
  "confidence_breakdown": {        // Nouveau
    "heuristic": 0.85,
    "ai": 0.92,
    "fusion": 0.95
  },
  "processing_time_ms": 380,       // Nouveau
  "metadata": {                    // Nouveau
    "pipeline_version": "2.0.0",
    "country_detected": "CH"
  }
}
```

### 3. Gestion des Erreurs
```swift
// v1
if let result = extractor.extract(image) {
    // Succès
} else {
    // Échec
}

// v2 - Plus granulaire
do {
    let result = try await pipeline.extract(from: image)
    switch result.confidence {
    case 0.9...1.0:
        // Auto-accept
    case 0.7..<0.9:
        // Review needed
    default:
        // Manual entry
    }
} catch ExtractionError.timeout {
    // Gérer timeout
} catch ExtractionError.invalidImage {
    // Gérer image invalide
}
```

---

## 📈 Plan de Rollout

### Phase 1: Test (Semaine 1)
- [ ] Déployer v2 sur environnement de test
- [ ] Tester avec 1000 reçus réels
- [ ] Valider amélioration performance

### Phase 2: Canary (Semaine 2)
- [ ] Activer v2 pour 10% des utilisateurs
- [ ] Monitorer métriques
- [ ] Collecter feedback

### Phase 3: Migration Graduelle (Semaine 3-4)
- [ ] 25% → 50% → 75% → 100%
- [ ] Rollback ready si problèmes

### Phase 4: Dépréciation v1 (Mois 2)
- [ ] Notifier fin de support v1
- [ ] Migration forcée des retardataires
- [ ] Archiver code v1

---

## 🔑 Scripts de Migration

### migrate_config.py
```python
#!/usr/bin/env python3
import json
import sys

def migrate_v1_to_v2(v1_config_path, v2_output_path):
    with open(v1_config_path) as f:
        v1 = json.load(f)
    
    v2 = {
        "version": "2.0.0",
        "pipeline": {
            "mode": "hybrid" if v1.get("use_ai") else "heuristics_only"
        },
        "confidence": {
            "thresholds": {
                "auto_accept": v1.get("threshold", 0.8) + 0.1,
                "ai_verification": v1.get("threshold", 0.8) - 0.1,
                "manual_review": v1.get("manual_threshold", 0.5)
            }
        },
        "ai": {
            "model": "Qwen2.5",
            "enabled": v1.get("use_ai", False)
        }
    }
    
    with open(v2_output_path, 'w') as f:
        json.dump(v2, f, indent=2)
    
    print(f"✅ Migration terminée: {v2_output_path}")

if __name__ == "__main__":
    migrate_v1_to_v2(sys.argv[1], sys.argv[2])
```

### rollback.sh
```bash
#!/bin/bash
# Script de rollback d'urgence

echo "⚠️  Rollback vers v1..."

# Restaurer config
cp -r backups/v1/* resources/config/

# Revert code
git checkout v1.0-final

# Redémarrer services
systemctl restart privexpensia

echo "✅ Rollback terminé"
```

---

## 📞 Support

### Contacts
- **Email**: dupont2@moulinsart.local
- **Slack**: #privexpensia-migration
- **Wiki**: /docs/migration-v2

### FAQ Migration

**Q: Puis-je utiliser v1 et v2 en parallèle?**  
A: Oui, pendant la phase de transition (1 mois)

**Q: Les données v1 sont-elles compatibles?**  
A: Oui, script de migration fourni

**Q: Qwen2.5 nécessite-t-il GPU?**  
A: Recommandé mais fonctionne sur CPU (plus lent)

**Q: Rollback possible après migration?**  
A: Oui, pendant 30 jours avec script rollback.sh

---

*Guide créé par DUPONT2 - Documentation & Recherche*  
*PrivExpensIA - Moulinsart Project*