#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh" test
# shellcheck source=lib/compose.sh
source "${SCRIPT_DIR}/lib/compose.sh"

echo ""
echo "--------------"
echo "SURUM TEST — PostgreSQL yedek (sürüm öncesi)"
echo "--------------"
sudo "${SCRIPT_DIR}/backup-postgres-test.sh" || exit 1

DOCKER_HOST_IP=$(sudo docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
echo "Docker Host IP: $DOCKER_HOST_IP"

echo ""
echo "--------------"
echo "SURUM TEST — Git (${APP_GIT_BRANCH})"
echo "--------------"
cd "${APP_SOURCE_DIR}" || exit 1
sudo git reset --hard
sudo git fetch "${GIT_REMOTE_APP}"
sudo git checkout "${APP_GIT_BRANCH}"
sudo git pull "${GIT_REMOTE_APP}" "${APP_GIT_BRANCH}"

echo ""
echo "-----------------------------"
echo "SURUM TEST — myenv.js"
echo "-----------------------------"
versionTest=$(git rev-list HEAD --count)
content=$(printf "window.CSMMAINENDPOINT = \"/\";window.CSMVERSION = \"1.0.%s-test\";" "$versionTest")
echo "$content" | sudo tee "${APP_SOURCE_DIR}/SeleniumOrchestratorFrontend/myenv.js"

echo ""
echo "--------------"
echo "SURUM TEST — Docker build + compose"
echo "--------------"
olustur_compose test down

sudo cp "${APP_SOURCE_DIR}/NuGet.Config" "${APP_SOURCE_DIR}/SeleniumOrchestratorBackend/"
sudo docker build --add-host "${NUGET_HOST}:${DOCKER_HOST_IP}" -t "${PROJECT_TITLE}si-${DEPLOY_ENV}:latest" "${APP_SOURCE_DIR}/SeleniumOrchestratorBackend/."
sudo docker build -t "${PROJECT_TITLE}ui-${DEPLOY_ENV}:latest" -f "${APP_SOURCE_DIR}/SeleniumOrchestratorFrontend/DockerfileTest" "${APP_SOURCE_DIR}/SeleniumOrchestratorFrontend/."

cd "${STACK_SOURCE_DIR}" || exit 1
sudo ./surum-diger-repo.sh test
sudo ./surum-genel-servisler.sh test

olustur_compose test up -d

echo ""
echo "Tamamlandi: surum-test"