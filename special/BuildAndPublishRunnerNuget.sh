#!/bin/bash

# ===========================
# Coklu .NET NuGet Yayin Scripti (macOS / Linux)
# ===========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_ROOT="$(cd "${SCRIPT_DIR}/../../SeleniumOrchestrator" && pwd)"
RUNNER_DIR="${ORCH_ROOT}/SeleniumOrchestratorBackend/Utils/SeleniumRunner"

project_paths=(
  "${RUNNER_DIR}/SeleniumRunner.Client/SeleniumRunner.Client.csproj"
  "${RUNNER_DIR}/SeleniumRunner.Client.Types/SeleniumRunner.Client.Types.csproj"
)

output_dir="${RUNNER_DIR}/nupkg"
api_key="${NUGET_API_KEY:-}"
nuget_source="https://api.nuget.org/v3/index.json"

if [[ -z "$api_key" ]]; then
  echo "HATA: NUGET_API_KEY ortam degiskeni tanimli degil."
  exit 1
fi

echo "$output_dir klasoru temizleniyor..."
rm -rf "$output_dir"
mkdir -p "$output_dir"

for project_path in "${project_paths[@]}"
do
  echo ""
  echo "----------------------------- Paketleniyor: $project_path -----------------------------"

  dotnet clean "$project_path"
  dotnet restore "$project_path"
  dotnet build "$project_path" --configuration Release

  dotnet pack "$project_path" \
    --configuration Release \
    --output "$output_dir" \
    /p:IncludeSymbols=true \
    /p:SymbolPackageFormat=snupkg
done

echo ""
echo "Paketler olusturuldu:"
ls -1 "$output_dir"/*.nupkg

for pkg in "$output_dir"/*.nupkg
do
  if [[ "$pkg" == *.snupkg ]]; then
    continue
  fi

  echo ""
  echo "----------------------------- Yayinlaniyor: $(basename "$pkg") -----------------------------"

  dotnet nuget push "$pkg" \
    --api-key "$api_key" \
    --source "$nuget_source" \
    --skip-duplicate
done

echo ""
echo "Tum projeler NuGet'e gonderildi."
