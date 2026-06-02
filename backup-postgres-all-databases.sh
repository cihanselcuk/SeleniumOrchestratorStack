#!/bin/bash
# PostgreSQL içindeki tüm (şablon olmayan) veritabanlarını ayrı ayrı custom format (-Fc) ile yedekler.
# Kullanım: sudo ./backup-postgres-all-databases.sh test|prod

if [[ $(id -u) -ne 0 ]]; then
  echo "Hata: Bu script sudo ile çalıştırılmalıdır. Örnek: sudo ./backup-postgres-all-databases.sh test"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_ARG="${1:-}"

if [[ "${ENV_ARG}" != "test" && "${ENV_ARG}" != "prod" ]]; then
  echo "Kullanım: sudo ./backup-postgres-all-databases.sh test|prod"
  exit 1
fi

# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh" "${ENV_ARG}"

if [[ "${DEPLOY_ENV}" == "test" ]]; then
  CONTAINER_NAME="${POSTGRES_BACKUP_CONTAINER_TEST}"
  BACKUP_DIR="${BACKUP_TEST_DIR}"
else
  CONTAINER_NAME="${POSTGRES_BACKUP_CONTAINER_PROD}"
  BACKUP_DIR="${BACKUP_PROD_DIR}"
fi

# backup-postgres-prod.sh / backup-postgres-test.sh ile aynı tarih formatı; her DB için aynı oturum damgası
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"

if ! docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Hata: Konteyner '${CONTAINER_NAME}' bulunamadı."
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

echo "Konteyner: ${CONTAINER_NAME}"
echo "Yedek dizini: ${BACKUP_DIR}"
echo "Oturum damgası: ${TIMESTAMP}"
echo ""

# -At: satır başına tek kolon, gereksiz boşluk yok (for döngüsü için)
while IFS= read -r db; do
  [[ -z "${db}" ]] && continue

  echo "========================================="
  echo "Veritabanı adı: ${db}"
  echo "========================================="

  # Örnek: egitim_prod_2026-05-14_22-30-00_keycloak.dump (tekil yedek: egitim_prod_2026-05-14_22-30-00.dump)
  DUMP_BASENAME="${PROJECT_TITLE}_${DEPLOY_ENV}_${TIMESTAMP}_${db}.dump"
  CONTAINER_PATH="/tmp/${DUMP_BASENAME}"

  if ! docker exec "${CONTAINER_NAME}" \
    pg_dump -U "${POSTGRES_USER}" -Fc -d "${db}" -f "${CONTAINER_PATH}"; then
    echo "Hata: pg_dump başarısız (${db})."
    exit 1
  fi

  if ! docker cp "${CONTAINER_NAME}:${CONTAINER_PATH}" "${BACKUP_DIR}/${DUMP_BASENAME}"; then
    echo "Hata: docker cp başarısız (${db})."
    exit 1
  fi

  docker exec "${CONTAINER_NAME}" rm -f "${CONTAINER_PATH}"

  echo "Tamamlandı: ${BACKUP_DIR}/${DUMP_BASENAME}"
  echo ""
done < <(
  docker exec "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -At -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;"
)

echo "Tüm veritabanı yedekleri bitti."
ls -la "${BACKUP_DIR}" 2>/dev/null || true
