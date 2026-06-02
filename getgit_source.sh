#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh" prod

cd "${APP_SOURCE_DIR}" || exit 1
sudo git reset --hard
sudo git fetch "${GIT_REMOTE_APP}"
sudo git checkout "${APP_GIT_BRANCH}"
sudo git pull "${GIT_REMOTE_APP}" "${APP_GIT_BRANCH}"
cd "$OLDPWD" || true
