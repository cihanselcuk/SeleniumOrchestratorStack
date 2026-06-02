#!/bin/bash
# Custom format (-Fc) dump dosyasını Postgres konteynerine geri yükler.
# Hedef veritabanı yoksa oluşturulur; varsa silinsin mi diye sorulur (onay şifresi gerekir).
# Kullanım: sudo ./restore-postgres-from-dump.sh test|prod /yol/dosya.dump [hedef_veritabani]
# 3. argüman verilirse hedef DB doğrudan kullanılır (soru sorulmaz); verilmezse dosya adından tahmin + Enter ile onay.
# Dump yolu hedef ortamdan bağımsızdır (ör. prod yedeğini test konteynerine). Tam mutlak yol önerilir.
#
# Dosya adı backup-postgres-*.sh ile uyumluysa hedef DB önerilir:
#   egitim_prod_2026-05-14_22-30-00.dump           -> egitim
#   egitim_prod_2026-05-14_22-30-00_keycloak.dump -> keycloak

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Mevcut veritabanını silmeden önce istenen onay şifresi
RESTORE_DELETE_CONFIRM_PASSWORD='12345*!'

restore_drop_database() {
  local db="$1"
  echo "Aktif bağlantılar kesiliyor: ${db}"
  docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -d postgres -v ON_ERROR_STOP=1 -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${db}' AND pid <> pg_backend_pid();"
  echo "Veritabanı siliniyor: ${db}"
  if ! docker exec "${CONTAINER_NAME}" dropdb -U "${POSTGRES_USER}" --if-exists "${db}"; then
    echo "Hata: dropdb başarısız (${db})."
    return 1
  fi
  echo "Veritabanı silindi: ${db}"
  return 0
}

restore_verify_delete_password() {
  local attempt pwd
  for attempt in 1 2 3; do
    read -rsp "Onay şifresi (mevcut veritabanını silmek için): " pwd
    echo ""
    if [[ "${pwd}" == "${RESTORE_DELETE_CONFIRM_PASSWORD}" ]]; then
      return 0
    fi
    echo "Hata: Şifre yanlış."
  done
  echo "İşlem iptal edildi (çok fazla hatalı deneme)."
  return 1
}

# Silmeden önce mevcut DB yedeği: <BACKUP_*_DIR>/restore-backup/restore-backup_<db>_<tarih>.dump
restore_backup_before_delete() {
  local db="$1" ts backup_name container_path host_path backup_root

  if [[ "${DEPLOY_ENV}" == "test" ]]; then
    backup_root="${BACKUP_TEST_DIR:-${DEVOPS_HOME}/backup/${PROJECT_TITLE}/test}"
  else
    backup_root="${BACKUP_PROD_DIR:-${DEVOPS_HOME}/backup/${PROJECT_TITLE}/prod}"
  fi

  ts="$(date +%Y-%m-%d_%H-%M-%S)"
  backup_name="restore-backup_${db}_${ts}.dump"
  container_path="/tmp/${backup_name}"
  host_path="${backup_root}/restore-backup/${backup_name}"

  mkdir -p "${backup_root}/restore-backup"

  echo ""
  echo "Restore öncesi yedek alınıyor (silinecek DB: ${db})..."
  if ! docker exec "${CONTAINER_NAME}" pg_dump -U "${POSTGRES_USER}" -Fc -d "${db}" -f "${container_path}"; then
    echo "Hata: pg_dump (restore öncesi yedek) başarısız. Veritabanı silinmedi."
    return 1
  fi

  if ! docker cp "${CONTAINER_NAME}:${container_path}" "${host_path}"; then
    echo "Hata: docker cp (restore öncesi yedek) başarısız. Veritabanı silinmedi."
    docker exec "${CONTAINER_NAME}" rm -f "${container_path}" 2>/dev/null || true
    return 1
  fi

  docker exec "${CONTAINER_NAME}" rm -f "${container_path}" 2>/dev/null || true
  echo "Ön yedek kaydedildi: ${host_path}"
  return 0
}

restore_print_help() {
  local prog="${0##*/}"
  cat <<EOF
${prog} — PostgreSQL custom format (-Fc) .dump dosyasını Docker Postgres konteynerine geri yükler.

KULLANIM
  sudo ./${prog} <ortam> <dump_dosyasi_yolu> [hedef_veritabani]

ARGÜMANLAR
  <ortam>               Zorunlu.  test | prod
                        Hangi ortamın Postgres konteynerine (Docker) bağlanılacağı.
                        Dump dosyasının diskteki konumu bundan bağımsızdır
                        (örneğin prod yedeğini teste verebilirsiniz).

  <dump_dosyasi_yolu>   Zorunlu.  Sunucudaki yedek dosyasının yolu.
                        Tam mutlak yol önerilir: /home/.../dosya.dump
                        Ayrıca: ~/... (sudo ile bile SUDO_USER evi) ve
                        ./ veya ../ ile başlamayan göreli yollar (REAL_HOME altında) desteklenir.

  [hedef_veritabani]    İsteğe bağlı.  Sadece harf, rakam ve alt çizgi (_).
                        VERİLİRSE: Restore bu ada yapılır; veritabanı adı için soru sorulmaz.
                        VERİLMEZSE: Dosya adından (egitim_prod_..._keycloak.dump gibi) tahmin edilir,
                        Enter ile onaylayıp veya yazarak değiştirebilirsiniz.

DİĞER
  ./${prog} help   veya   ./${prog} -h   veya   --help
                        Bu metni gösterir (sudo gerekmez).

MEVCUT VERİTABANI
  Hedef veritabanı zaten varsa: silinsin mi diye sorulur (e/h).
  Evet + doğru onay şifresi: önce <yedek_kökü>/restore-backup/restore-backup_<db>_<tarih>.dump
  alınır, sonra DB silinir, yenisi oluşturulur, restore devam eder.
  Ön yedek başarısızsa silme yapılmaz. Hayır veya yanlış şifre: işlem iptal.

YENİ VERİTABANI
  Hedef yoksa oluşturulsun mu diye sorulur (e/h, varsayılan e).

ÖRNEKLER
  sudo ./${prog} prod /home/devops/backup/egitim/prod/egitim_prod_2026-05-14_12-00-00.dump
  sudo ./${prog} test /home/devops/backup/egitim/prod/egitim_prod_2026-05-14_12-00-00_keycloak.dump keycloak_yeni
  sudo ./${prog} test /home/devops/backup/egitim/prod/egitim_prod_....dump
                        (3. argüman yok: hedef DB dosya adından tahmin + soru)
EOF
}

case "${1:-}" in
  '' | -h | --help | help)
    restore_print_help
    exit 0
    ;;
esac

if [[ $(id -u) -ne 0 ]]; then
  echo "Hata: Bu script sudo ile çalıştırılmalıdır. Yardım: ./${0##*/} help"
  exit 1
fi

ENV_ARG="${1:-}"
DUMP_PATH="${2:-}"
HEDEF_DB_CLI="${3:-}"

if [[ "${ENV_ARG}" != "test" && "${ENV_ARG}" != "prod" ]] || [[ -z "${DUMP_PATH}" ]]; then
  echo "Hata: Eksik veya geçersiz argüman."
  echo ""
  restore_print_help
  exit 1
fi

# shellcheck source=lib/load-definitions.sh
source "${SCRIPT_DIR}/lib/load-definitions.sh" "${ENV_ARG}"

if [[ "${DEPLOY_ENV}" == "test" ]]; then
  CONTAINER_NAME="${POSTGRES_BACKUP_CONTAINER_TEST}"
else
  CONTAINER_NAME="${POSTGRES_BACKUP_CONTAINER_PROD}"
fi

if ! docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Hata: Konteyner '${CONTAINER_NAME}' bulunamadı."
  exit 1
fi

# sudo ile HOME=/root olabildiği için göreli yollar SUDO_USER'ın evine göre (yoksa mevcut HOME).
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
  [[ -z "${REAL_HOME}" ]] && REAL_HOME="${HOME}"
else
  REAL_HOME="${HOME}"
fi

# definitions.test|prod.env yalnızca birini yüklediğinden boş kalabilir; ipucu satırı için türet.
BACKUP_HINT_TEST="${BACKUP_TEST_DIR:-${DEVOPS_HOME}/backup/${PROJECT_TITLE}/test}"
BACKUP_HINT_PROD="${BACKUP_PROD_DIR:-${DEVOPS_HOME}/backup/${PROJECT_TITLE}/prod}"

# Mutlak yol: realpath/readlink; ~/ → REAL_HOME; ./ ../ değilse önce REAL_HOME altında dene.
DUMP_P="${DUMP_PATH}"
if [[ "${DUMP_P}" == \~/* ]]; then
  DUMP_P="${REAL_HOME}/${DUMP_P#~/}"
elif [[ "${DUMP_P}" == \~ ]]; then
  DUMP_P="${REAL_HOME}"
fi

_dump_try_resolve() {
  local c="$1" out
  out=""
  if command -v realpath >/dev/null 2>&1; then
    out="$(realpath "${c}" 2>/dev/null)" || out=""
  fi
  if [[ -z "${out}" ]] && command -v readlink >/dev/null 2>&1; then
    out="$(readlink -f "${c}" 2>/dev/null)" || out=""
  fi
  if [[ -n "${out}" && -f "${out}" ]]; then
    DUMP_ABS="${out}"
    return 0
  fi
  return 1
}

DUMP_ABS=""
if _dump_try_resolve "${DUMP_P}"; then
  :
elif [[ "${DUMP_P}" != /* ]] && [[ "${DUMP_P}" != ./* ]] && [[ "${DUMP_P}" != ../* ]] && _dump_try_resolve "${REAL_HOME}/${DUMP_P}"; then
  :
else
  if [[ "${DUMP_P}" == /* ]]; then
    DUMP_ABS="${DUMP_P}"
  else
    DUMP_ABS="$(pwd)/${DUMP_P}"
  fi
  if [[ ! -f "${DUMP_ABS}" ]] && [[ "${DUMP_P}" != /* ]] && [[ "${DUMP_P}" != ./* ]] && [[ "${DUMP_P}" != ../* ]]; then
    DUMP_ABS="${REAL_HOME}/${DUMP_P}"
  fi
fi

if [[ -z "${DUMP_ABS}" ]] || [[ ! -f "${DUMP_ABS}" ]]; then
  echo "Hata: Dump dosyası bulunamadı veya yol çözülemedi: ${DUMP_PATH}"
  echo "Çalışma dizini: $(pwd) — REAL_HOME=${REAL_HOME} (sudo ile SUDO_USER evi)"
  echo "Öneri: Dosyanın gerçek tam yolunu verin (ör. ls -l ile kopyalanan yol)."
  echo "Tanımlı yedek kökleri (referans) — test: ${BACKUP_HINT_TEST} — prod: ${BACKUP_HINT_PROD}"
  echo "Örnek: sudo $0 test ${BACKUP_HINT_PROD}/egitim_prod_....dump"
  exit 1
fi

infer_default_db() {
  local base rest
  base=$(basename "${DUMP_ABS}" .dump)
  # Hedef ortam test iken dosya adı egitim_prod_... olabilir; önek hedef DEPLOY_ENV ile sınırlı olmamalı.
  local p_cur="${PROJECT_TITLE}_${DEPLOY_ENV}_"
  local p_prod="${PROJECT_TITLE}_prod_"
  local p_test="${PROJECT_TITLE}_test_"

  if [[ "${base}" == "${p_cur}"* ]]; then
    rest="${base#${p_cur}}"
  elif [[ "${base}" == "${p_prod}"* ]]; then
    rest="${base#${p_prod}}"
  elif [[ "${base}" == "${p_test}"* ]]; then
    rest="${base#${p_test}}"
  else
    echo "${PROJECT_TITLE}"
    return
  fi

  # Sadece tarih damgası (tekil DB yedeği)
  if [[ "${rest}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "${PROJECT_TITLE}"
    return
  fi
  # Tarih + veritabanı adı (çoklu yedek formatı)
  if [[ "${rest}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}_(.+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  echo "${PROJECT_TITLE}"
}

SUGGESTED_DB="$(infer_default_db)"

echo "Konteyner (hedef ortam): ${CONTAINER_NAME}"
echo "Dump dosyası (kaynak yol, ortamdan bağımsız): ${DUMP_ABS}"
echo "Dosya adından tahmin edilen hedef veritabanı: ${SUGGESTED_DB}"

if [[ -n "${HEDEF_DB_CLI}" ]]; then
  TARGET_DB="${HEDEF_DB_CLI}"
  echo "Hedef veritabanı (3. argümandan): ${TARGET_DB}"
else
  read -rp "Hedef veritabanı adı (Enter = tahmin edilen): " DB_ANS
  TARGET_DB="${DB_ANS:-${SUGGESTED_DB}}"
  echo "Hedef veritabanı: ${TARGET_DB}"
fi

if [[ ! "${TARGET_DB}" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Hata: Hedef veritabanı adı yalnızca harf, rakam ve alt çizgi içerebilir."
  exit 1
fi

DB_COUNT="$(
  docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -At -c \
    "SELECT count(*)::text FROM pg_database WHERE datname = '${TARGET_DB}' AND datistemplate = false;" | tr -d '[:space:]'
)"

if [[ "${DB_COUNT}" != "0" && "${DB_COUNT}" != "1" ]]; then
  echo "Hata: Veritabanı sorgusu beklenmeyen sonuç döndü: '${DB_COUNT}'"
  exit 1
fi

if [[ "${DB_COUNT}" == "1" ]]; then
  echo ""
  echo "========================================="
  echo "  UYARI: '${TARGET_DB}' veritabanı zaten mevcut."
  echo "  Devam etmek için veritabanı silinip yeniden"
  echo "  oluşturulacak (tüm veri kaybolur)."
  echo "========================================="
  read -rp "Mevcut veritabanı '${TARGET_DB}' silinsin mi? (e/h, varsayılan h): " DEL_ANS
  case "${DEL_ANS}" in
    [eE] | [eE][vV][eE][tT])
      if ! restore_verify_delete_password; then
        exit 1
      fi
      if ! restore_backup_before_delete "${TARGET_DB}"; then
        exit 1
      fi
      if ! restore_drop_database "${TARGET_DB}"; then
        exit 1
      fi
      if ! docker exec "${CONTAINER_NAME}" createdb -U "${POSTGRES_USER}" "${TARGET_DB}"; then
        echo "Hata: createdb başarısız."
        exit 1
      fi
      echo "Veritabanı yeniden oluşturuldu: ${TARGET_DB}"
      ;;
    *)
      echo "İşlem iptal edildi (veritabanı silinmedi)."
      exit 1
      ;;
  esac
else
  read -rp "Veritabanı '${TARGET_DB}' yok. Oluşturulsun mu? (e/h, varsayılan e): " CR_ANS
  case "${CR_ANS}" in
    "" | [eE] | [eE][vV][eE][tT])
      if ! docker exec "${CONTAINER_NAME}" createdb -U "${POSTGRES_USER}" "${TARGET_DB}"; then
        echo "Hata: createdb başarısız."
        exit 1
      fi
      echo "Veritabanı oluşturuldu: ${TARGET_DB}"
      ;;
    *)
      echo "İşlem iptal edildi."
      exit 1
      ;;
  esac
fi

CONTAINER_TMP="/tmp/pg_restore_${TARGET_DB}_$$.dump"

echo ""
echo "Dosya konteynere kopyalanıyor..."
if ! docker cp "${DUMP_ABS}" "${CONTAINER_NAME}:${CONTAINER_TMP}"; then
  echo "Hata: docker cp başarısız."
  exit 1
fi

RESTORE_CMD=(docker exec "${CONTAINER_NAME}" pg_restore -U "${POSTGRES_USER}" -d "${TARGET_DB}" --no-owner --no-acl -Fc "${CONTAINER_TMP}")

echo "pg_restore çalışıyor..."
if ! "${RESTORE_CMD[@]}"; then
  _rc=$?
  echo "Hata: pg_restore başarısız (çıkış kodu ${_rc})."
  docker exec "${CONTAINER_NAME}" rm -f "${CONTAINER_TMP}" 2>/dev/null || true
  exit 1
fi

docker exec "${CONTAINER_NAME}" rm -f "${CONTAINER_TMP}" 2>/dev/null || true

echo ""
echo "Restore tamamlandı. Hedef: ${TARGET_DB}"
