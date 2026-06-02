#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh"
# shellcheck source=lib/compose.sh
source "${SCRIPT_DIR}/lib/compose.sh"

olustur_compose test down
olustur_compose prod down
olustur_compose test up -d
olustur_compose prod up -d
