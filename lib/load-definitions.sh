#!/usr/bin/env bash
# SeleniumOrchestratorStack definitions yükler.
#
# Kullanım:
#   source "${SCRIPT_DIR}/lib/load-definitions.sh"           # sadece ortak (GIT_REMOTE_APP yok)
#   source "${SCRIPT_DIR}/lib/load-definitions.sh" test     # + definitions.test.env
#   source "${SCRIPT_DIR}/lib/load-definitions.sh" prod      # + definitions.prod.env
#
# Sıra: definitions.env; test|prod verilirse definitions.<env>.env

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS_ROOT="$(cd "${_LIB_DIR}/.." && pwd)"
_DEPLOY_ENV="${1:-}"

if [ ! -f "${DEFINITIONS_ROOT}/definitions.env" ]; then
  echo "Hata: definitions.env bulunamadi: ${DEFINITIONS_ROOT}/definitions.env" >&2
  return 1 2>/dev/null || exit 1
fi

set -a
# shellcheck disable=SC1090
source "${DEFINITIONS_ROOT}/definitions.env"

case "${_DEPLOY_ENV}" in
  test)
    if [ ! -f "${DEFINITIONS_ROOT}/definitions.test.env" ]; then
      echo "Hata: definitions.test.env bulunamadi" >&2
      set +a
      return 1 2>/dev/null || exit 1
    fi
    source "${DEFINITIONS_ROOT}/definitions.test.env"
    ;;
  prod)
    if [ ! -f "${DEFINITIONS_ROOT}/definitions.prod.env" ]; then
      echo "Hata: definitions.prod.env bulunamadi" >&2
      set +a
      return 1 2>/dev/null || exit 1
    fi
    source "${DEFINITIONS_ROOT}/definitions.prod.env"
    ;;
esac

set +a
# Ortak path'ler: definitions.env. Yedek/Postgres konteyner adları: definitions.test.env | definitions.prod.env