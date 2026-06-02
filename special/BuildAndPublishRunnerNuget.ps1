param (
    [string[]]$projectPaths,
    [string]$outputDir,
    [string]$apiKey = $env:NUGET_API_KEY
)

$scriptRoot = $PSScriptRoot
$orchRoot = Resolve-Path (Join-Path $scriptRoot "..\..\SeleniumOrchestrator")
$runnerDir = Join-Path $orchRoot "SeleniumOrchestratorBackend/Utils/SeleniumRunner"

if (-not $projectPaths) {
    $projectPaths = @(
        (Join-Path $runnerDir "SeleniumRunner.Client\SeleniumRunner.Client.csproj"),
        (Join-Path $runnerDir "SeleniumRunner.Client.Types\SeleniumRunner.Client.Types.csproj")
    )
}
if (-not $outputDir) {
    $outputDir = Join-Path $runnerDir "nupkg"
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "NUGET_API_KEY ortam degiskenini ayarlayin ya da -apiKey parametresi gecin."
}

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$nugetSource = "https://api.nuget.org/v3/index.json"

if (Test-Path $outputDir) {
    Remove-Item $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDir | Out-Null

foreach ($projectPath in $projectPaths) {
    Write-Host "----------------------------- Isleniyor: $projectPath -----------------------------"

    dotnet clean $projectPath
    dotnet restore $projectPath
    dotnet build $projectPath --configuration Release

    dotnet pack $projectPath `
        --configuration Release `
        --output $outputDir `
        /p:IncludeSymbols=true `
        /p:SymbolPackageFormat=snupkg
}

Write-Host "`n Tum NuGet paketleri olusturuldu:"
Get-ChildItem $outputDir -Filter "*.nupkg"

$packages = Get-ChildItem $outputDir -Filter "*.nupkg" | Where-Object { $_.Name -notlike "*.snupkg" }

foreach ($pkg in $packages) {
    Write-Host "----------------------------- Yayinlaniyor: $($pkg.Name) -----------------------------"
    dotnet nuget push $pkg.FullName `
        --api-key $apiKey `
        --source $nugetSource `
        --skip-duplicate
}
