#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_ROOT="$(cd "${SCRIPT_DIR}/../../SeleniumOrchestrator" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/version.json"

major=$(python3 -c "import json; print(json.load(open('${VERSION_FILE}'))['major'])")
minor=$(python3 -c "import json; print(json.load(open('${VERSION_FILE}'))['minor'])")
patch=$(git -C "${ORCH_ROOT}" rev-list HEAD --count)

version="$major.$minor.$patch"

content=$(printf 'window.CSMMAINENDPOINT = "/";window.CSMVERSION = "%s";' "$version")
echo "$content" | sudo tee "${ORCH_ROOT}/SeleniumOrchestratorFrontend/myenv.js" > /dev/null

echo "------- BUILD SERVER"
sudo docker build -t zdory/selenium-orchestrator-api:latest -t "zdory/selenium-orchestrator-api:${version}" "${ORCH_ROOT}/SeleniumOrchestratorBackend/."

echo "------- BUILD RUNNER"
sudo docker build -t zdory/selenium-runner-api:latest -t "zdory/selenium-runner-api:${version}" "${ORCH_ROOT}/SeleniumOrchestratorBackend/Utils/SeleniumRunner/SeleniumRunner.Api/."

echo "------- BUILD FRONTEND"
sudo docker build -f "${ORCH_ROOT}/SeleniumOrchestratorFrontend/DockerfileProd" -t zdory/selenium-orchestrator-ui:latest -t "zdory/selenium-orchestrator-ui:${version}" "${ORCH_ROOT}/SeleniumOrchestratorFrontend/."

content=$(printf 'window.CSMMAINENDPOINT = "http://localhost:5001/";window.CSMVERSION = "%s";' "dev")
echo "$content" | sudo tee "${ORCH_ROOT}/SeleniumOrchestratorFrontend/myenv.js" > /dev/null

echo "------- PUBLISH IMAGES"
sudo docker push zdory/selenium-orchestrator-api:latest
sudo docker push "zdory/selenium-orchestrator-api:${version}"
sudo docker push zdory/selenium-runner-api:latest
sudo docker push "zdory/selenium-runner-api:${version}"
sudo docker push zdory/selenium-orchestrator-ui:latest
sudo docker push "zdory/selenium-orchestrator-ui:${version}"
