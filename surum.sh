#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh"

echo "--------------------"
echo "0- UPDATE SeleniumOrchestratorSTACK (ortak)"
echo "--------------------"
cd "${STACK_SOURCE_DIR}" || exit 1
sudo git reset --hard
sudo git pull "${GIT_REMOTE_STACK}" main

sudo chmod +x "${SCRIPT_DIR}/surum-diger-repo.sh"
sudo chmod +x "${SCRIPT_DIR}/surum-genel-servisler.sh"
sudo chmod +x "${SCRIPT_DIR}/surum-test.sh"
sudo chmod +x "${SCRIPT_DIR}/surum-prod.sh"
sudo chmod +x "${SCRIPT_DIR}/backup-postgres-test.sh"
sudo chmod +x "${SCRIPT_DIR}/backup-postgres-prod.sh"
sudo chmod +x "${SCRIPT_DIR}/surum-keycloak.sh"

echo ""
"${SCRIPT_DIR}/surum-test.sh" || exit 1

echo ""
"${SCRIPT_DIR}/surum-prod.sh" || exit 1

echo ""
echo "========================================"
echo "Tamamlandi: surum (test + prod)"
echo "========================================"