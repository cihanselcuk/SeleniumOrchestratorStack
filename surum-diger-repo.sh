#!/bin/bash
# Yardım merkezi ve Unity oyun yayını: kaynak ayrı repo değil, EGITIM repo içindeki klasörler.
#   Help/private-ari-help-center, Help/public-ari-help-center, OyunUnity/Publish

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh"

ENV=$1

if [ -z "$ENV" ]; then
    echo "Kullanim: $0 <ortam>"
    echo "  $0 test"
    echo "  $0 prod"
    exit 1
fi

if [ "$ENV" != "test" ] && [ "$ENV" != "prod" ]; then
    echo "Hata: Ortam 'test' veya 'prod' olmali"
    exit 1
fi

echo "--------------"
echo "Docker build (${PROJECT}, ${ENV}) — kaynak: ${APP_SOURCE_DIR}"
echo "--------------"

# HELP-CENTER
PRIVATE_DIR="${APP_SOURCE_DIR}/Help/private-ari-help-center"
PUBLIC_DIR="${APP_SOURCE_DIR}/Help/public-ari-help-center"
if [ ! -d "${PRIVATE_DIR}" ] || [ ! -d "${PUBLIC_DIR}" ]; then
    echo "Hata: Help dizinleri bulunamadi: ${PRIVATE_DIR} / ${PUBLIC_DIR}" >&2
    exit 1
fi
sudo docker build -f "${PRIVATE_DIR}/Dockerfile.${ENV}" -t "${PROJECT_TITLE}-yardim-ozel-${ENV}:latest" "${PRIVATE_DIR}/"
sudo docker build -f "${PUBLIC_DIR}/Dockerfile.${ENV}" -t "${PROJECT_TITLE}-yardim-genel-${ENV}:latest" "${PUBLIC_DIR}/"

# Yeni Özel container sürümleri, aşağıya eklenir
# -- PRESERVE BEGIN: OzelEkContainerSurumleri -- #
# -- PRESERVE END: OzelEkContainerSurumleri -- #

echo ""
echo "Tamamlandi: $PROJECT ($ENV)"