$scriptRoot = $PSScriptRoot
$orchRoot = Resolve-Path (Join-Path $scriptRoot "..\..\SeleniumOrchestrator")
$versionConfig = Get-Content -Path "$scriptRoot/version.json" -Raw | ConvertFrom-Json
$major = $versionConfig.major
$minor = $versionConfig.minor
$patch = git -C "$orchRoot" rev-list HEAD --count

$version = "$major.$minor.$patch"

echo "------- 1 - Generate Version Info"
$content = "window.CSMMAINENDPOINT = `"/`";window.CSMVERSION = `"$Version`";"
Set-Content -Path "$orchRoot/SeleniumOrchestratorFrontend/myenv.js" -Value $content

echo "------- 1 - Generate Version Info - DONE"
echo "------- 2 - Build Api"
Push-Location "$orchRoot/SeleniumOrchestratorBackend"
docker build -t "zdory/selenium-orchestrator-api:latest" -t "zdory/selenium-orchestrator-api:$version" .
Pop-Location

echo "------- 2 - Build Api - DONE"
echo "------- 3 - Build Runner"
Push-Location "$orchRoot/SeleniumOrchestratorBackend/Utils/SeleniumRunner/SeleniumRunner.Api"
docker build -t "zdory/selenium-runner-api:latest" -t "zdory/selenium-runner-api:$version" .
Pop-Location

echo "------- 3 - Build Runner - DONE"
echo "------- 4 - Build UI"
Push-Location "$orchRoot/SeleniumOrchestratorFrontend"
docker build -f DockerfileProd -t "zdory/selenium-orchestrator-ui:latest" -t "zdory/selenium-orchestrator-ui:$version" .
Pop-Location

echo "------- 4 - Build UI - DONE"

$content = "window.CSMMAINENDPOINT = `"http://localhost:5020/`";window.CSMVERSION = `"dev`";"
Set-Content -Path "$orchRoot/SeleniumOrchestratorFrontend/myenv.js" -Value $content

echo "------- 5 - Publish Images"
docker push zdory/selenium-orchestrator-api:latest
docker push "zdory/selenium-orchestrator-api:$version"
docker push zdory/selenium-runner-api:latest
docker push "zdory/selenium-runner-api:$version"
docker push zdory/selenium-orchestrator-ui:latest
docker push "zdory/selenium-orchestrator-ui:$version"

echo "------- 5 - Publish Images - DONE"
