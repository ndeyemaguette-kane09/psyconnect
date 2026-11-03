#!/bin/bash
# arrête les services lancés par start-dev.sh : d'abord via les fichiers .pid,
# puis par port. ne touche qu'aux process java, jamais à docker
# (bash 3 de macOS, donc pas de declare -A)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGS="$SCRIPT_DIR/logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICES="auth-service:8081 user-service:8082 appointment-service:8083 payment-service:8085 notification-service:8086 session-service:8089"

echo ""
echo -e "${YELLOW}PsyConnect : arrêt des services${NC}"
echo ""

for pid_file in "$LOGS"/*.pid; do
  [ -f "$pid_file" ] || continue
  name=$(basename "$pid_file" .pid)
  pid=$(cat "$pid_file")

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    echo -e "${RED}$name${NC} (PID $pid) arrêté"
  else
    echo "$name (PID $pid) déjà arrêté"
  fi
  rm -f "$pid_file"
done

# docker desktop mappe les mêmes ports, d'où le filtre sur java
echo ""
echo "Vérification des ports restants"
for entry in $SERVICES; do
  name="${entry%%:*}"
  port="${entry##*:}"

  for pid in $(lsof -ti:"$port" 2>/dev/null); do
    comm=$(ps -p "$pid" -o comm= 2>/dev/null)
    if echo "$comm" | grep -qE "^java$"; then
      echo -e "${RED}Port $port encore occupé${NC} ($name, PID $pid), arrêt forcé"
      kill "$pid" 2>/dev/null
    fi
  done
done

echo ""
echo -e "${GREEN}Terminé.${NC}"
echo ""
