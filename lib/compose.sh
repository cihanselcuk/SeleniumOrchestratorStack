#!/usr/bin/env bash
# olustur_compose <ortam> <docker compose alt komutlari...>
#
# Ornek: olustur_compose test up -d
#        olustur_compose prod logs -f SeleniumOrchestratorBackend
#
# Gereklilik: load-definitions.sh sonrasi STACK_SOURCE_DIR, PROJECT_TITLE.

seleniumorchestrator_compose_log() {
  # Sadece gorsel; CI'da OLUSTUR_COMPOSE_SILENT=1 ile kapatilabilir
  if [ "${OLUSTUR_COMPOSE_SILENT:-}" = "1" ]; then
    return 0
  fi
  local line="--------------------------------------------------------------------------------"
  printf '\n%s\n' "${line}"
  printf '  olustur_compose  |  SeleniumOrchestratorStack  |  docker compose\n'
  printf '%s\n' "${line}"
  printf '  Ortam (stack)          : %s\n' "${1}"
  printf '  Compose proje adi      : %s\n' "${2}"
  printf '  DEPLOY_ENV (zorunlu)   : %s  (kabuk ezmesin diye env ile verilir)\n' "${3}"
  printf '  ASPNETCORE_ENV         : %s\n' "${4}"
  printf '  Compose dosyalari:\n'
  printf '    - %s\n' "${5}"
  printf '    - %s\n' "${6}"
  printf '  Env dosyalari:\n'
  printf '    - %s\n' "${7}"
  printf '    - %s\n' "${8}"
  printf '  Alt komut              : %s\n' "${9}"
  printf '%s\n\n' "${line}"
}

olustur_compose() {
  local stack_environment="${1:?'Kullanim: olustur_compose <test|prod> <docker compose komutlari...>'}"
  shift
  local compose_subcommands=("$@")

  local aspnet_environment
  case "${stack_environment}" in
    test)
      aspnet_environment=Test
      ;;
    prod)
      aspnet_environment=Prod
      ;;
    *)
      echo "Hata: olustur_compose yalnizca 'test' veya 'prod' kabul eder: '${stack_environment}'" >&2
      return 1
      ;;
  esac

  local compose_project_name="${PROJECT_TITLE}-${stack_environment}"
  local file_compose_base="${STACK_SOURCE_DIR}/docker-compose.base.yml"
  local file_compose_override="${STACK_SOURCE_DIR}/${PROJECT_TITLE}-${stack_environment}/docker-compose.yml"
  local file_env_shared="${STACK_SOURCE_DIR}/definitions.env"
  local file_env_stack="${STACK_SOURCE_DIR}/definitions.${stack_environment}.env"
  local subcmd_display
  if [ "${#compose_subcommands[@]}" -eq 0 ]; then
    subcmd_display="(yok - docker compose varsayilan)"
  else
    subcmd_display="${compose_subcommands[*]}"
  fi

  seleniumorchestrator_compose_log \
    "${stack_environment}" \
    "${compose_project_name}" \
    "${stack_environment}" \
    "${aspnet_environment}" \
    "${file_compose_base}" \
    "${file_compose_override}" \
    "${file_env_shared}" \
    "${file_env_stack}" \
    "${subcmd_display}"

  sudo env \
    DEPLOY_ENV="${stack_environment}" \
    ASPNETCORE_ENV="${aspnet_environment}" \
    docker compose \
    --project-name "${compose_project_name}" \
    -f "${file_compose_base}" \
    -f "${file_compose_override}" \
    --env-file "${file_env_shared}" \
    --env-file "${file_env_stack}" \
    "${compose_subcommands[@]}"
}