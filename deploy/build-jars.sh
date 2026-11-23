#!/bin/bash
# construit le jar de chaque service Spring Boot avant docker compose build
set -e
cd "$(dirname "$0")/../backend"
for s in eureka-server auth-service user-service appointment-service payment-service \
         notification-service session-service ai-companion-service api-gateway; do
  echo "== $s"
  (cd "$s" && chmod +x gradlew && ./gradlew clean bootJar -x test --no-daemon -q)
done
