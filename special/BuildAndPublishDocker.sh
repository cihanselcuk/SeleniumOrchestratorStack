#!/usr/bin/env bash
# SeleniumOrchestrator — coklu mimari (linux/amd64 + linux/arm64) imaj yayini.
#
# NEDEN buildx: eski surum duz "docker build" kullaniyordu -> imaj YALNIZ derleyen
# makinenin mimarisinde cikiyordu. arm64 bir makineden (mac mini) kosuldugunda Hub'daki
# coklu mimarili :latest, arm64-only bir manifest ile EZILIR ve amd64 sunucular imaji
# cekemez ("no matching manifest for linux/amd64"). Uc Dockerfile de derleme asamasini
# "FROM --platform=$BUILDPLATFORM" ile builder'in KENDI mimarisinde kosturuyor; cikti
# portable IL (dotnet publish) ya da statik web dosyasi oldugu icin QEMU'ya girilmez.
#
# NEDEN sudo YOK: "sudo docker push" root'un ~/.docker/config.json'ina bakar; kimlik
# (credsStore=desktop) KULLANICI oturumunda durur -> push "denied" ile duser. Ayrica
# "sudo tee" repoya root sahipli bir myenv.js birakir ve sonraki sudosuz kosu onu ezemez.
#
# Kullanim:
#   ./BuildAndPublishDocker.sh --kuru     # ne yapacagini yazar, hicbir seye dokunmaz
#   ./BuildAndPublishDocker.sh            # derle + push (latest + <surum>)
#   PLATFORMS=linux/amd64 ./BuildAndPublishDocker.sh   # tek mimari istenirse
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_ROOT="$(cd "${SCRIPT_DIR}/../../SeleniumOrchestrator" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/version.json"

PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDER:-so-builder}"

KURU=0
[ "${1:-}" = "--kuru" ] && KURU=1

# ── Surum: major.minor dosyadan, patch uygulama deposunun commit sayisindan ──────
major=$(python3 -c "import json; print(json.load(open('${VERSION_FILE}'))['major'])")
minor=$(python3 -c "import json; print(json.load(open('${VERSION_FILE}'))['minor'])")
patch=$(git -C "${ORCH_ROOT}" rev-list HEAD --count)
version="$major.$minor.$patch"
commit=$(git -C "${ORCH_ROOT}" rev-parse --short HEAD)

echo "── Surum ────────────────────────────────────────────"
echo "   kaynak    : ${ORCH_ROOT} ($(git -C "${ORCH_ROOT}" rev-parse --abbrev-ref HEAD) @ ${commit})"
echo "   surum     : ${version}   (tag: :latest + :${version})"
echo "   mimari    : ${PLATFORMS}"
[ "$KURU" = "1" ] && echo "   KURU MOD  : hicbir sey derlenmez/gonderilmez"

# Commit'lenmemis degisiklik sessizce yayina girmesin: imaj calisma agacindan
# derlenir, ama SURUM NUMARASI commit sayisindan gelir -> ikisi ayrisirsa
# "1.15.72" iki farkli iceriki gosterir.
if [ -n "$(git -C "${ORCH_ROOT}" status --porcelain)" ]; then
    echo "   ⚠ UYARI   : calisma agaci KIRLI — imaj commit'lenmemis kodla derlenecek"
fi

# ── On kontroller ────────────────────────────────────────────────────────────────
if ! docker buildx ls >/dev/null 2>&1; then
    echo "HATA: 'docker buildx ls' calismiyor."
    echo "  Muhtemel sebep: gecmiste 'sudo docker' kosuldugu icin ~/.docker altinda"
    echo "  root sahipli dosyalar var (buildx/activity, buildx/refs, .buildNodeID)."
    echo "  Cozum : sudo chown -R \"$(id -un)\":staff ~/.docker"
    echo "  Gecici: export BUILDX_CONFIG=\$HOME/.buildx-so"
    exit 1
fi

# Coklu mimari manifest'i YALNIZ docker-container driver'i uretebilir; varsayilan
# "docker" driver'i "manifest lists are not supported" ile duser.
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
    echo "   builder '${BUILDER}' yok → olusturuluyor (docker-container)"
    [ "$KURU" = "1" ] || docker buildx create --name "$BUILDER" --driver docker-container --bootstrap >/dev/null
fi

# ── myenv.js: prod damgasi (build icin) — cikista MUTLAKA dev'e geri doner ───────
# Eski surumde geri yazma satiri build'lerden SONRA geliyordu: build patlarsa dosya
# prod icerigiyle kaliyor ve farkinda olmadan sonraki dev kosusuna siziyordu.
MYENV="${ORCH_ROOT}/SeleniumOrchestratorFrontend/myenv.js"
MYENV_DEV='window.CSMMAINENDPOINT = "http://localhost:5001/";window.CSMVERSION = "dev";'
# \n ONEMLI: dosya depoda satir sonuyla duruyor; onsuz yazmak her kosudan
# sonra repoyu "kirli" birakir (tek fark: eksik newline).
myenv_geri_al() { printf '%s\n' "$MYENV_DEV" > "$MYENV"; }

if [ "$KURU" = "0" ]; then
    trap myenv_geri_al EXIT
    printf 'window.CSMMAINENDPOINT = "/";window.CSMVERSION = "%s";\n' "$version" > "$MYENV"
fi

# ── Derle + gonder ───────────────────────────────────────────────────────────────
# Tek gecis: buildx hem derler hem her iki tag'i push eder (ayri "docker push"
# adimi YOK — coklu mimari manifest yerel imaj deposunda durmaz).
yayinla() {
    local imaj="$1" baglam="$2" dockerfile="${3:-}"
    echo ""
    echo "── ${imaj} ─────────────────────────────────────────"
    local -a komut=(docker buildx build --builder "$BUILDER" --platform "$PLATFORMS"
                    -t "${imaj}:latest" -t "${imaj}:${version}" --push)
    [ -n "$dockerfile" ] && komut+=(-f "$dockerfile")
    komut+=("$baglam")

    printf '   $ %s\n' "${komut[*]}"
    [ "$KURU" = "1" ] || "${komut[@]}"
}

yayinla zdory/selenium-orchestrator-api \
        "${ORCH_ROOT}/SeleniumOrchestratorBackend/."

yayinla zdory/selenium-runner-api \
        "${ORCH_ROOT}/SeleniumOrchestratorBackend/Utils/SeleniumRunner/SeleniumRunner.Api/."

yayinla zdory/selenium-orchestrator-ui \
        "${ORCH_ROOT}/SeleniumOrchestratorFrontend/." \
        "${ORCH_ROOT}/SeleniumOrchestratorFrontend/DockerfileProd"

echo ""
if [ "$KURU" = "1" ]; then
    echo "── KURU BITTI — hicbir sey gonderilmedi (${version}) ──"
else
    echo "── BITTI ── zdory/selenium-{orchestrator-api,runner-api,orchestrator-ui}:${version} + :latest → ${PLATFORMS}"
    echo "   dogrula: docker buildx imagetools inspect zdory/selenium-orchestrator-api:${version}"
fi
