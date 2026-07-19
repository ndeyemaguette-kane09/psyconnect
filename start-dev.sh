#!/bin/bash
# Lance tous les microservices PsyConnect en mode dev (bootRun en arrière-plan)
# Usage : ./start-dev.sh
# Logs  : logs/<service>.log
# Arrêt : ./stop-dev.sh  (ou kill $(cat logs/<service>.pid))
#
# PRÉ-REQUIS : Eureka doit tourner dans Docker avant de lancer ce script.
#   docker-compose up -d postgres zipkin eureka-server api-gateway
#   (attendre ~90s qu'Eureka soit healthy)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$SCRIPT_DIR/backend"
LOGS="$SCRIPT_DIR/logs"

mkdir -p "$LOGS"

# couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─── Vérification Eureka ──────────────────────────────────────────────────────
check_eureka() {
  # Tente d'abord /actuator/health (code HTTP 200), sinon la page racine
  local url="http://localhost:8761/actuator/health"
  local max_wait=120  # secondes max d'attente (Eureka met ~90s à démarrer)
  local interval=5

  echo -e "${YELLOW}  Vérification d'Eureka (localhost:8761)…${NC}"

  local elapsed=0
  while [ $elapsed -lt $max_wait ]; do
    # Vérification via code HTTP (200 = UP) — évite les problèmes de grep sur le JSON
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null)
    if [ "$http_code" = "200" ]; then
      echo -e "  ${GREEN}✔ Eureka est UP${NC}"
      return 0
    fi

    # Pas encore UP — attendre si on vient de démarrer Docker
    if [ $elapsed -eq 0 ]; then
      echo -e "  ${YELLOW}  Eureka pas encore prêt, attente jusqu'à ${max_wait}s…${NC}"
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  # Toujours pas UP après max_wait secondes
  echo ""
  echo -e "${RED}  ✖ ERREUR : Eureka (localhost:8761) ne répond pas après ${max_wait}s.${NC}"
  echo ""
  echo "  Les microservices nécessitent Eureka pour démarrer."
  echo "  Lance d'abord l'infrastructure Docker depuis le dossier PsyConnect :"
  echo ""
  echo -e "    ${GREEN}docker-compose up -d postgres zipkin eureka-server api-gateway${NC}"
  echo ""
  echo "  Puis relance ce script quand Eureka est UP :"
  echo "  (vérifie sur http://localhost:8761 ou via 'docker-compose ps')"
  echo ""
  exit 1
}

# ─── Lancement d'un service ───────────────────────────────────────────────────
start_service() {
  local name=$1
  local dir="$BACKEND/$name"
  local log="$LOGS/$name.log"
  local pid_file="$LOGS/$name.pid"

  if [ ! -d "$dir" ]; then
    echo "  ⚠️  $name : dossier introuvable, ignoré"
    return
  fi

  echo -e "  ${GREEN}▶ $name${NC}  →  $log"
  cd "$dir"
  ./gradlew bootRun > "$log" 2>&1 &
  echo $! > "$pid_file"
  cd "$SCRIPT_DIR"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}=== PsyConnect Dev — démarrage des services ===${NC}"
echo ""

check_eureka

echo ""

# Ordre : auth d'abord (les autres s'enregistrent dans Eureka de toute façon)
start_service "auth-service"
start_service "user-service"
start_service "appointment-service"
start_service "payment-service"
start_service "notification-service"
start_service "session-service"

echo ""
echo -e "${YELLOW}Tous les services démarrés en arrière-plan.${NC}"
echo ""
echo "  Suivre les logs en temps réel :"
echo "    tail -f logs/user-service.log"
echo "    tail -f logs/auth-service.log"
echo "    tail -f logs/<service>.log"
echo ""
echo "  Arrêter tout :"
echo "    ./stop-dev.sh"
echo ""
