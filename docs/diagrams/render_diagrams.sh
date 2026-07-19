#!/bin/bash
# ============================================================
# Script de rendu des diagrammes PlantUML → PNG
# À exécuter UNE FOIS sur ton Mac depuis ce dossier.
#
# Pré-requis : Java installé (vérifier avec : java -version)
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR="$SCRIPT_DIR/plantuml.jar"
PUML_SERVER="https://github.com/plantuml/plantuml/releases/download/v1.2024.6/plantuml-1.2024.6.jar"

# 1. Télécharger PlantUML si besoin
if [ ! -f "$JAR" ]; then
  echo "→ Téléchargement de PlantUML..."
  curl -sL "$PUML_SERVER" -o "$JAR"
  echo "✓ PlantUML téléchargé"
fi

# 2. Rendre tous les fichiers .puml en PNG
echo "→ Génération des PNG..."
java -jar "$JAR" -charset UTF-8 -png "$SCRIPT_DIR"/*.puml
echo ""
echo "✓ PNG générés dans : $SCRIPT_DIR"
ls "$SCRIPT_DIR"/*.png
