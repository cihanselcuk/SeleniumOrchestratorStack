#!/usr/bin/env bash
# listmonk --install (LISTMONK_* env ile; boş --config). Veritabanı / tabloları elle hazırlarsın.
# Kullanım: sudo ./scripts/setup-listmonk.sh test|prod
#
# Eşdeğer: olustur_compose <env> run --rm listmonk ./listmonk --install --config ''

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

env="${1:?'Kullanim: sudo ./scripts/setup-listmonk.sh test|prod'}"
case "$env" in
test | prod) ;;
*)
  echo "Hata: test veya prod verin." >&2
  exit 1
  ;;
esac

# shellcheck source=lib/load-definitions.sh
source "${STACK_ROOT}/lib/load-definitions.sh" "$env"
# shellcheck source=lib/compose.sh
source "${STACK_ROOT}/lib/compose.sh"

echo "listmonk --install (${PROJECT_TITLE}-${env})..."
olustur_compose "$env" run --rm listmonk ./listmonk --install --config ''

echo "Tamam."
