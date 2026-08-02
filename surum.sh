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

# git pull sonrasi: tum script'lere +x (tek tek saymak yerine toplu; yeni script eklenince unutulmaz)
sudo chmod +x "${SCRIPT_DIR}"/*.sh "${SCRIPT_DIR}"/lib/*.sh "${SCRIPT_DIR}"/scripts/*.sh 2>/dev/null || true

echo ""
"${SCRIPT_DIR}/surum-test.sh" || exit 1

echo ""
"${SCRIPT_DIR}/surum-prod.sh" || exit 1

echo ""
echo "========================================"
echo "Tamamlandi: surum (test + prod)"
echo "========================================"