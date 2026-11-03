#!/bin/bash
# lance les microservices en dev (bootRun en arrière-plan)
# logs dans logs/<service>.log, arrêt avec ./stop-dev.sh
#
# eureka doit déjà tourner dans docker :
#   docker-compose up -d postgres zipkin eureka-server api-gateway
#   (il met ~90 s à démarrer)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$SCRIPT_DIR/backend"
LOGS="$SCRIPT_DIR/logs"

mkdir -p "$LOGS"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_eureka() {
  local url="http://localhost:8761/actuator/health"
  local max_wait=120
  local interval=5

  echo -e "${YELLOW}Vérification d'Eureka (localhost:8761)${NC}"

  local elapsed=0
  while [ $elapsed -lt $max_wait ]; do
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null)
    if [ "$http_code" = "200" ]; then
      echo -e "${GREEN}Eureka est prêt${NC}"
      return 0
    fi

    if [ $elapsed -eq 0 ]; then
      echo -e "${YELLOW}Eureka pas encore prêt, attente jusqu'à ${max_wait} s${NC}"
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  echo ""
  echo -e "${RED}Erreur : Eureka (localhost:8761) ne répond pas après ${max_wait} s.${NC}"
  echo ""
  echo "Les microservices ont besoin d'Eureka. Lance d'abord :"
  echo ""
  echo "  docker-compose up -d postgres zipkin eureka-server api-gateway"
  echo ""
  echo "puis relance ce script (état visible sur http://localhost:8761 ou avec 'docker-compose ps')."
  echo ""
  exit 1
}

start_service() {
  local name=$1
  local dir="$BACKEND/$name"
  local log="$LOGS/$name.log"
  local pid_file="$LOGS/$name.pid"

  if [ ! -d "$dir" ]; then
    echo "$name : dossier introuvable, ignoré"
    return
  fi

  echo -e "${GREEN}$name${NC} -> $log"
  cd "$dir"
  ./gradlew bootRun > "$log" 2>&1 &
  echo $! > "$pid_file"
  cd "$SCRIPT_DIR"
}

echo ""
echo -e "${YELLOW}PsyConnect : démarrage des services${NC}"
echo ""

check_eureka

echo ""

start_service "auth-service"
start_service "user-service"
start_service "appointment-service"
start_service "payment-service"
start_service "notification-service"
start_service "session-service"

echo ""
echo -e "${YELLOW}Services lancés en arrière-plan.${NC}"
echo ""
echo "Logs : tail -f logs/<service>.log"
echo "Arrêt : ./stop-dev.sh"
echo ""
