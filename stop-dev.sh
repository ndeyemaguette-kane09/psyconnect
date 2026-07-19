#!/bin/bash
# Arrête tous les services lancés par start-dev.sh
# Stratégie double : PID files d'abord, puis nettoyage par port (filet de sécurité)
# Compatible bash 3.x (macOS) — NE TUE JAMAIS les process Docker

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGS="$SCRIPT_DIR/logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Couples nom:port en chaîne simple — compatible bash 3.x (pas de declare -A)
SERVICES="auth-service:8081 user-service:8082 appointment-service:8083 payment-service:8085 notification-service:8086 session-service:8089"

echo ""
echo -e "${YELLOW}=== PsyConnect Dev — arrêt des services ===${NC}"
echo ""

# 1. Tuer via PID files (propre)
for pid_file in "$LOGS"/*.pid; do
  [ -f "$pid_file" ] || continue
  name=$(basename "$pid_file" .pid)
  pid=$(cat "$pid_file")

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    echo -e "  ${RED}■ $name${NC}  (PID $pid) arrêté"
  else
    echo -e "  $name  (PID $pid) déjà arrêté"
  fi
  rm -f "$pid_file"
done

# 2. Filet de sécurité : tuer par port, mais UNIQUEMENT les process java
#    (évite de tuer Docker Desktop qui mappe ces mêmes ports via ses containers)
echo ""
echo "  Vérification des ports résiduels…"
for entry in $SERVICES; do
  name="${entry%%:*}"
  port="${entry##*:}"

  for pid in $(lsof -ti:"$port" 2>/dev/null); do
    comm=$(ps -p "$pid" -o comm= 2>/dev/null)
    if echo "$comm" | grep -qE "^java$"; then
      echo -e "  ${RED}■ Port $port occupé${NC} ($name, PID $pid) — nettoyage forcé"
      kill "$pid" 2>/dev/null
    fi
  done
done

echo ""
echo -e "${GREEN}Terminé.${NC}"
echo ""
