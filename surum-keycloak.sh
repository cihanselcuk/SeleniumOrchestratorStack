#!/bin/bash
ENV=$1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh"

if [ -z "$ENV" ]; then
    echo "Kullanim: $0 <ortam>"
    echo "  Ortam: test | prod"
    echo ""
    echo "Ornekler:"
    echo "  $0 test"
    echo "  $0 prod"
    exit 1
fi

if [ "$ENV" != "test" ] && [ "$ENV" != "prod" ]; then
    echo "Hata: Ortam 'test' veya 'prod' olmali"
    exit 1
fi

SPI_DIR="${GENELSERVISLER_SOURCE_DIR}/KeycloakProvider/KeycloakProvider/keycloak-backend-auth-spi"
THEMES_DIR="${GENELSERVISLER_SOURCE_DIR}/KeycloakProvider/Docker/keycloak/themes"
PROVIDERS_VOLUME="${VOLUME_ROOT}/keycloak-${ENV}/providers"
THEMES_VOLUME="${VOLUME_ROOT}/keycloak-${ENV}/themes"
MAVEN_CACHE="${DEVOPS_HOME}/.m2-cache"
SPI_CHECKSUM_FILE="${PROVIDERS_VOLUME}/.spi-source-checksum"

sudo mkdir -p "${PROVIDERS_VOLUME}"
sudo mkdir -p "${THEMES_VOLUME}"
sudo mkdir -p "${MAVEN_CACHE}"

echo "--------------------"
echo "1- BUILD KEYCLOAK SPI"
echo "--------------------"

cd "$SPI_DIR" || exit 1

CURRENT_CHECKSUM=$(find . -name '*.java' -o -name 'pom.xml' | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}')
PREVIOUS_CHECKSUM=""
if [ -f "${SPI_CHECKSUM_FILE}" ]; then
    PREVIOUS_CHECKSUM=$(cat "${SPI_CHECKSUM_FILE}")
fi

if [ "${CURRENT_CHECKSUM}" = "${PREVIOUS_CHECKSUM}" ] && \
   ls "${PROVIDERS_VOLUME}"/keycloak-rintensoft-auth-spi-*.jar >/dev/null 2>&1; then
    echo "SPI kaynağında değişiklik yok — build atlanıyor."
else
    echo "Değişiklik tespit edildi — Maven build başlıyor..."
    docker run --rm \
        -v "$(pwd)":/workspace \
        -v "${MAVEN_CACHE}":/root/.m2 \
        -w /workspace \
        maven:3-openjdk-17 \
        mvn clean package -DskipTests -q

    if [ $? -ne 0 ]; then
        echo "Hata: Maven build başarısız."
        exit 1
    fi

    sudo cp target/keycloak-rintensoft-auth-spi-*.jar "${PROVIDERS_VOLUME}/"
    echo "${CURRENT_CHECKSUM}" | sudo tee "${SPI_CHECKSUM_FILE}" > /dev/null
    echo "SPI build tamamlandi ve kopyalandi."
fi

echo ""
echo "-------------------------"
echo "2- COPY KEYCLOAK THEMES"
echo "-------------------------"

sudo cp -r "${THEMES_DIR}"/* "${THEMES_VOLUME}/"

echo ""
echo "Tamamlandi: keycloak ($ENV)"
