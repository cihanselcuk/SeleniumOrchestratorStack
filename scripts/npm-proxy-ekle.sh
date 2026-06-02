#!/usr/bin/env bash
# Nginx Proxy Manager API ile greentrace proxy host'larını toplu oluşturur.
#
# Kullanım:
#   ./scripts/npm-proxy-ekle.sh test
#   ./scripts/npm-proxy-ekle.sh prod
#
# Gerekli: NPM_URL, NPM_EMAIL, NPM_PASSWORD ortam değişkenleri veya aşağıda düzenle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/load-definitions.sh" "${1:?'Kullanim: npm-proxy-ekle.sh <test|prod>'}"

# ─── NPM Bağlantı Bilgileri ───
NPM_URL="${NPM_URL:-http://127.0.0.1:81}"
NPM_EMAIL="${NPM_EMAIL:-admin@rtdev.com}"
NPM_PASSWORD="${NPM_PASSWORD:-h~yJ+cCBnUy4VrE}"

# ─── Token Al ───
echo "NPM'e bağlanılıyor: ${NPM_URL}"
TOKEN=$(curl -s -X POST "${NPM_URL}/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Hata: NPM token alınamadı. Email/şifre veya URL'i kontrol edin."
  exit 1
fi
echo "Token alındı."

# ─── Proxy Host Oluşturma Fonksiyonu ───
olustur_proxy() {
  local domain="$1"
  local forward_host="$2"
  local forward_port="$3"

  echo ""
  echo "Oluşturuluyor: ${domain} → ${forward_host}:${forward_port}"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${NPM_URL}/api/nginx/proxy-hosts" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{
      \"domain_names\": [\"${domain}\"],
      \"forward_scheme\": \"http\",
      \"forward_host\": \"${forward_host}\",
      \"forward_port\": ${forward_port},
      \"block_exploits\": false,
      \"allow_websocket_upgrade\": true,
      \"access_list_id\": 0,
      \"certificate_id\": 0,
      \"ssl_forced\": false,
      \"meta\": { \"letsencrypt_agree\": false, \"dns_challenge\": false },
      \"advanced_config\": \"\",
      \"locations\": [],
      \"http2_support\": true,
      \"hsts_enabled\": false,
      \"hsts_subdomains\": false
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "201" ]; then
    echo "  ✓ Başarılı"
  else
    echo "  ✗ Hata (HTTP ${HTTP_CODE}): ${BODY}"
  fi
}

# ─── Kayıtlar ───
ENV_LABEL="${DEPLOY_ENV}"

if [ "$ENV_LABEL" = "test" ]; then
  olustur_proxy "giristestyonetim.seleniumorchestrator.com"   "${PROJECT_TITLE}-${ENV_LABEL}-keycloak-1"       8080
  olustur_proxy "giristest.seleniumorchestrator.com"          "${PROJECT_TITLE}-${ENV_LABEL}-keycloak-1"       8080
  olustur_proxy "portaltest.seleniumorchestrator.com"         "${PROJECT_TITLE}-${ENV_LABEL}-frontend-1"       80
  olustur_proxy "pgadmintest.seleniumorchestrator.com"        "${PROJECT_TITLE}-${ENV_LABEL}-pgadmin-1"        80
  olustur_proxy "listmonktest.seleniumorchestrator.com"       "${PROJECT_TITLE}-${ENV_LABEL}-listmonk-1"       9000
  olustur_proxy "yardimtest.seleniumorchestrator.com"         "${PROJECT_TITLE}-${ENV_LABEL}-yardimozel-1"     80

elif [ "$ENV_LABEL" = "prod" ]; then
  olustur_proxy "giristestyonetim.seleniumorchestrator.com"   "${PROJECT_TITLE}-${ENV_LABEL}-keycloak-1"       8080
  olustur_proxy "giris.seleniumorchestrator.com"              "${PROJECT_TITLE}-${ENV_LABEL}-keycloak-1"      8080
  olustur_proxy "portal.seleniumorchestrator.com"             "${PROJECT_TITLE}-${ENV_LABEL}-frontend-1"      80
  olustur_proxy "pgadmin.seleniumorchestrator.com"            "${PROJECT_TITLE}-${ENV_LABEL}-pgadmin-1"       80
  olustur_proxy "listmonk.seleniumorchestrator.com"           "${PROJECT_TITLE}-${ENV_LABEL}-listmonk-1"      9000
  olustur_proxy "yardim.seleniumorchestrator.com"             "${PROJECT_TITLE}-${ENV_LABEL}-yardimozel-1"    80

fi

echo ""
echo "========================================"
echo "Tamamlandı: ${ENV_LABEL} proxy host'ları oluşturuldu"
echo "========================================"