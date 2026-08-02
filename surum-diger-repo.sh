#!/bin/bash
# Yardım merkezi: kaynak ayrı repo değil, seleniumorchestrator repo içindeki
# Help/${PROJECT_TITLE}-yardim-ozel klasörü (kalıp tüm projelerde aynıdır).
# Yardım merkezi olmayan projelerde SkipYardim=true ile bu blok hiç üretilmez.
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


# Yeni Özel container sürümleri, aşağıya eklenir
# -- PRESERVE BEGIN: OzelEkContainerSurumleri -- #
# -- PRESERVE END: OzelEkContainerSurumleri -- #

echo ""
echo "Tamamlandi: ${PROJECT_TITLE} ($ENV)"