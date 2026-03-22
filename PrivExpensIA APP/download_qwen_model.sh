#!/bin/bash

# TÉLÉCHARGEMENT DU VRAI MODÈLE QWEN
# ====================================

echo "🤖 TÉLÉCHARGEMENT DU MODÈLE QWEN 0.5B"
echo "====================================="
echo ""

# Token HuggingFace
export HF_TOKEN="hf_YOUR_TOKEN_HERE"

# Créer le dossier models
MODEL_DIR="$HOME/Documents/models"
mkdir -p "$MODEL_DIR"

echo "📂 Dossier de destination: $MODEL_DIR"
echo ""

# Option 1: Télécharger Qwen 0.5B quantifié pour MLX
echo "📥 Téléchargement Qwen2.5-0.5B-Instruct quantifié..."
cd "$MODEL_DIR"

# Utiliser huggingface-cli pour télécharger
if command -v huggingface-cli &> /dev/null; then
    huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct \
        --local-dir qwen2.5-0.5b-instruct \
        --token $HF_TOKEN
else
    echo "⚠️ huggingface-cli non installé"
    echo "Installation avec: pip install huggingface-hub"
    
    # Alternative: téléchargement direct avec curl
    echo ""
    echo "📥 Téléchargement direct des fichiers essentiels..."
    
    mkdir -p qwen2.5-0.5b-4bit
    cd qwen2.5-0.5b-4bit
    
    # Télécharger les fichiers essentiels
    curl -H "Authorization: Bearer $HF_TOKEN" \
         -L "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/resolve/main/config.json" \
         -o config.json
    
    curl -H "Authorization: Bearer $HF_TOKEN" \
         -L "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/resolve/main/tokenizer.json" \
         -o tokenizer.json
    
    echo ""
    echo "⚠️ Pour le modèle complet, installez huggingface-cli"
fi

echo ""
echo "✅ Téléchargement terminé!"
echo ""
echo "📍 Emplacement: $MODEL_DIR/qwen2.5-0.5b-4bit"
echo ""
echo "🔧 Prochaines étapes:"
echo "1. Convertir en format MLX ou CoreML si nécessaire"
echo "2. L'app cherchera le modèle dans ~/Documents/models/qwen2.5-0.5b-4bit"
echo "3. Relancer l'app pour charger le vrai modèle"
echo ""
echo "💡 Note: Le modèle fait ~500MB-1GB selon la quantification"