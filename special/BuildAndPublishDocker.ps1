# SeleniumOrchestrator — coklu mimari (linux/amd64 + linux/arm64) imaj yayini.
# Gerekce ve tuzaklar icin kardes dosyaya bak: BuildAndPublishDocker.sh
#
# Kullanim:
#   .\BuildAndPublishDocker.ps1 -Kuru     # ne yapacagini yazar, dokunmaz
#   .\BuildAndPublishDocker.ps1           # derle + push (latest + <surum>)
param(
    [switch]$Kuru,
    [string]$Platforms = "linux/amd64,linux/arm64",
    [string]$Builder = "so-builder"
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$orchRoot = Resolve-Path (Join-Path $scriptRoot "..\..\SeleniumOrchestrator")
$versionConfig = Get-Content -Path "$scriptRoot/version.json" -Raw | ConvertFrom-Json

$major = $versionConfig.major
$minor = $versionConfig.minor
$patch = git -C "$orchRoot" rev-list HEAD --count
$version = "$major.$minor.$patch"
$commit = git -C "$orchRoot" rev-parse --short HEAD

Write-Host "-- Surum ------------------------------------------"
Write-Host "   kaynak : $orchRoot @ $commit"
Write-Host "   surum  : $version   (tag: :latest + :$version)"
Write-Host "   mimari : $Platforms"
if ($Kuru) { Write-Host "   KURU MOD: hicbir sey derlenmez/gonderilmez" }

if (git -C "$orchRoot" status --porcelain) {
    Write-Host "   UYARI  : calisma agaci KIRLI - imaj commit'lenmemis kodla derlenecek"
}

# Coklu mimari manifest'i yalniz docker-container driver'i uretebilir.
docker buildx inspect $Builder *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "   builder '$Builder' yok -> olusturuluyor (docker-container)"
    if (-not $Kuru) { docker buildx create --name $Builder --driver docker-container --bootstrap | Out-Null }
}

# myenv.js: build icin prod damgasi; cikista MUTLAKA dev'e geri doner (finally).
$myenv = "$orchRoot/SeleniumOrchestratorFrontend/myenv.js"
$myenvDev = "window.CSMMAINENDPOINT = `"http://localhost:5020/`";window.CSMVERSION = `"dev`";`n"

function Yayinla([string]$Imaj, [string]$Baglam, [string]$Dockerfile) {
    Write-Host ""
    Write-Host "-- $Imaj ------------------------------------------"
    $argv = @("buildx", "build", "--builder", $Builder, "--platform", $Platforms,
              "-t", "${Imaj}:latest", "-t", "${Imaj}:$version", "--push")
    if ($Dockerfile) { $argv += @("-f", $Dockerfile) }
    $argv += $Baglam

    Write-Host "   $ docker $($argv -join ' ')"
    if (-not $Kuru) { & docker @argv }
}

try {
    if (-not $Kuru) {
        Set-Content -Path $myenv -NoNewline -Value "window.CSMMAINENDPOINT = `"/`";window.CSMVERSION = `"$version`";`n"
    }

    Yayinla "zdory/selenium-orchestrator-api" "$orchRoot/SeleniumOrchestratorBackend/."
    Yayinla "zdory/selenium-runner-api" "$orchRoot/SeleniumOrchestratorBackend/Utils/SeleniumRunner/SeleniumRunner.Api/."
    Yayinla "zdory/selenium-orchestrator-ui" "$orchRoot/SeleniumOrchestratorFrontend/." "$orchRoot/SeleniumOrchestratorFrontend/DockerfileProd"
}
finally {
    if (-not $Kuru) { Set-Content -Path $myenv -NoNewline -Value $myenvDev }
}

# script-base: YENIDEN DERLENMEZ, mevcut manifest yeni surum tag'ine KOPYALANIR.
# Gerekce ve tuzaklar kardes dosyada: BuildAndPublishDocker.sh (ayni bolum).
# Ozet: uclu sozlesme SURUM NUMARASI uzerinden kurulur; bu adim olmadan script-base
# eski numarada kalir ve arm64'te sessizce patlar. Yeniden derlemek apt'ten TAZE
# tarayici ceker -> dogrulanmamis Chrome/Chromium surumu yayina girer.
$scriptBase = "zdory/selenium-runner-script-base"
$scriptBaseKaynak = if ($env:SCRIPT_BASE_KAYNAK) { $env:SCRIPT_BASE_KAYNAK } else { "${scriptBase}:latest" }

Write-Host ""
Write-Host "-- $scriptBase (yeniden derleme YOK) --------------"
Write-Host "   kaynak : $scriptBaseKaynak"
Write-Host "   hedef  : ${scriptBase}:$version"
Write-Host "   $ docker buildx imagetools create -t ${scriptBase}:$version $scriptBaseKaynak"
if (-not $Kuru) { & docker buildx imagetools create -t "${scriptBase}:$version" $scriptBaseKaynak }

Write-Host ""
if ($Kuru) {
    Write-Host "-- KURU BITTI - hicbir sey gonderilmedi ($version) --"
} else {
    Write-Host "-- BITTI -- zdory/selenium-* : $version + latest -> $Platforms"
    Write-Host "            ${scriptBase}:$version (kopyalandi, yeniden derlenmedi)"
    Write-Host ""
    Write-Host "   Kurulum recetesindeki tag'leri $version'e cek:"
    Write-Host "     SeleniumOrchestrator/docker-compose.yml   (3 satir: ScriptBaseImageTag + 2 image)"
    Write-Host "     SeleniumOrchestrator/.claude/skills/csseeder-selenium-orchestrator-usage/SKILL.md  (IMAGE_TAG)"
}
