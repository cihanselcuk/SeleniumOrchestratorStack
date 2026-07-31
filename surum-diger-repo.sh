#!/bin/bash
# Yardım merkezi: kaynak ayrı repo değil, seleniumorchestrator repo içindeki
# "" klasörü (YardimOzelKaynakDizini değişkeni; boş = yardım merkezi yok).
# İkinci (genel) yardım merkezi, Unity oyun yayını gibi projeye özel ek container'lar
# aşağıdaki "OzelEkContainerSurumleri" PRESERVE bloğuna eklenir.

# Alt adımlardan biri patlarsa devam etme — çağıran surum-test/prod.sh de bunu görsün.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh"

echo "Diğer servislerin sürümünü güncellemek için çalıştırılacak."
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
echo "Docker build (${PROJECT_TITLE}, ${ENV}) — kaynak: ${APP_SOURCE_DIR}"
echo "--------------"

# HELP-CENTER (özel) — dizin adı projeye göre değişir, generator'dan gelir.
YARDIM_OZEL_DIR=""
if [ -z "${YARDIM_OZEL_DIR}" ]; then
    echo "Bu projede özel yardım merkezi tanımlı değil, atlaniyor."
else
    PRIVATE_DIR="${APP_SOURCE_DIR}/${YARDIM_OZEL_DIR}"
    if [ ! -d "${PRIVATE_DIR}" ]; then
        echo "Hata: Help dizini bulunamadi: ${PRIVATE_DIR}" >&2
        exit 1
    fi
    # Sürüm: ana app deposunun commit sayısı (SeleniumOrchestratorFrontend/myenv.js ile aynı mantık)
    YARDIM_VERSION_COUNT=$(cd "${APP_SOURCE_DIR}" && sudo git rev-list HEAD --count)
    if [ "$ENV" = "prod" ]; then
        YARDIM_VERSION="1.0.${YARDIM_VERSION_COUNT}"
    else
        YARDIM_VERSION="1.0.${YARDIM_VERSION_COUNT}-test"
    fi
    echo "yardim-ozel sürüm: ${YARDIM_VERSION}"

    sudo docker build \
        --build-arg APP_VERSION="${YARDIM_VERSION}" \
        -f "${PRIVATE_DIR}/Dockerfile.${ENV}" \
        -t "${PROJECT_TITLE}-yardim-ozel-${ENV}:latest" "${PRIVATE_DIR}/"
fi

# Yeni Özel container sürümleri, aşağıya eklenir
# -- PRESERVE BEGIN: OzelEkContainerSurumleri -- #
# -- PRESERVE END: OzelEkContainerSurumleri -- #

echo ""
echo "Tamamlandi: ${PROJECT_TITLE} ($ENV)"