#!/bin/bash
if [[ $(id -u) -ne 0 ]]; then
  echo "Hata: Bu script sudo ile çalıştırılmalıdır. Örnek: sudo ./backup-postgres-prod.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh" prod

CONTAINER_NAME="${POSTGRES_BACKUP_CONTAINER_PROD}"
DB_USER="${POSTGRES_USER}"
DB_NAME="${PROJECT_TITLE}"

if ! docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo ""
  echo "========================================="
  echo "  UYARI: Konteyner '${CONTAINER_NAME}' bulunamadı."
  echo "  Yedek alınamıyor."
  echo "========================================="
  echo ""
  read -rp "Yedek almadan devam edilsin mi? (e/h): " cevap
  case "$cevap" in
    [eE]|[eE][vV][eE][tT])
      echo "Yedek atlanıyor, devam ediliyor..."
      exit 0
      ;;
    *)
      echo "İşlem iptal edildi."
      exit 1
      ;;
  esac
fi

BACKUP_NAME="${PROJECT_TITLE}_prod_$(date +%Y-%m-%d_%H-%M-%S).dump"
CONTAINER_PATH="/tmp/${BACKUP_NAME}"

mkdir -p "${BACKUP_PROD_DIR}"

echo "Konteyner: ${CONTAINER_NAME}"
echo "Yedek dizini: ${BACKUP_PROD_DIR}"
echo "Yedek alınıyor: ${BACKUP_NAME}"

docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -f "$CONTAINER_PATH"

if [ $? -ne 0 ]; then
  echo "Hata: pg_dump başarısız."
  exit 1
fi

docker cp "${CONTAINER_NAME}:${CONTAINER_PATH}" "${BACKUP_PROD_DIR}/"

if [ $? -ne 0 ]; then
  echo "Hata: docker cp başarısız."
  exit 1
fi

docker exec "$CONTAINER_NAME" rm -f "$CONTAINER_PATH"

echo ""
echo "Yedek tamamlandı."
echo "Dosya: ${BACKUP_PROD_DIR}/${BACKUP_NAME}"
echo ""
echo "Dizin içeriği:"
ls -la "${BACKUP_PROD_DIR}" 2>/dev/null || dir "${BACKUP_PROD_DIR}" 2>/dev/null || echo "(liste alınamadı - dizini elle kontrol edin)"
