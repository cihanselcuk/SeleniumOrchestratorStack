#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh"

ENV=$1

if [ -z "$ENV" ]; then
    echo "Kullanim: $0 <ortam>"
    echo "  Ortam: test | prod"
    echo ""
    echo "Ornekler:"
    echo "  $0 test"
    echo "  $0 prod"
    exit 1
fi

if [ "$ENV" != "test" ] && [ "$ENV" != "prod" ]; then
    echo "Hata: Ortam 'test' veya 'prod' olmali"
    exit 1
fi

MICROSERVICES_DIR="${GENELSERVISLER_SOURCE_DIR}/MicroServices"
DOCKER_HOST_IP=$(sudo docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')

echo "--------------"
echo "1- RESTORE GIT"
echo "--------------"

if [ ! -d "${GENELSERVISLER_SOURCE_DIR}" ]; then
    echo "Dizin bulunamadi, ilk kez klonlaniyor..."
    sudo git clone "${GIT_REMOTE_GENELSERVISLER}" "${GENELSERVISLER_SOURCE_DIR}"
fi

cd "${GENELSERVISLER_SOURCE_DIR}" || exit 1
sudo git reset --hard
sudo git fetch "${GIT_REMOTE_GENELSERVISLER}"
sudo git checkout main
sudo git pull "${GIT_REMOTE_GENELSERVISLER}" main

echo ""
echo "--------------------------"
echo "2- BUILD GENEL SERVISLER"
echo "--------------------------"

sudo cp "${GENELSERVISLER_SOURCE_DIR}/NuGet.Config" "${MICROSERVICES_DIR}/"
sudo docker build --add-host "${NUGET_HOST}:${DOCKER_HOST_IP}" -t "sms-service-${ENV}:latest" -f "${MICROSERVICES_DIR}/SmsService/SmsService.WebApi/Dockerfile" "${MICROSERVICES_DIR}/."
sudo docker build --add-host "${NUGET_HOST}:${DOCKER_HOST_IP}" -t "rota-service-${ENV}:latest" -f "${MICROSERVICES_DIR}/GuzergahService/GuzergahService.WebApi/Dockerfile" "${MICROSERVICES_DIR}/."
sudo docker build -t "llm-service-${ENV}:latest" "${MICROSERVICES_DIR}/LLMAgentService/app/."

echo ""
echo "----------------------------"
echo "3- BUILD & DEPLOY KEYCLOAK"
echo "----------------------------"

sudo chmod +x "${SCRIPT_DIR}/surum-keycloak.sh"
sudo "${SCRIPT_DIR}/surum-keycloak.sh" "$ENV"

echo ""
echo "Tamamlandi: genelservisler ($ENV)"
