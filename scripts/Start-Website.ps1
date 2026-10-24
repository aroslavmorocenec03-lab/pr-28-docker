param([int]$Port = 8080, [switch]$Initial)
. "$PSScriptRoot/DockerHelpers.ps1"
Assert-DockerReady
if ($Port -lt 1 -or $Port -gt 65535) { throw 'Порт має бути від 1 до 65535.' }

$buildContext = $script:ProjectRoot
$imageTag = 'my-static-website:latest'
if ($Initial) {
    $buildContext = Join-Path $script:ProjectRoot '.work/initial'
    [System.IO.Directory]::CreateDirectory((Join-Path $buildContext 'html')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:ProjectRoot 'Dockerfile') -Destination (Join-Path $buildContext 'Dockerfile') -Force
    Copy-Item -LiteralPath (Join-Path $script:ProjectRoot 'examples/index.initial.html') -Destination (Join-Path $buildContext 'html/index.html') -Force
    $imageTag = 'my-static-website:v1'
}

Invoke-Docker build -t $imageTag $buildContext
Remove-ProjectContainer -Name 'static-website'
Invoke-Docker run -d --name static-website --label ua.pr28.project=pr-28-docker -p "127.0.0.1:${Port}:80" $imageTag

$healthy = $false
for ($attempt = 0; $attempt -lt 25; $attempt++) {
    $health = Invoke-Docker inspect --format '{{.State.Health.Status}}' static-website
    if ($health -eq 'healthy') { $healthy = $true; break }
    if ($health -eq 'unhealthy') { throw 'Healthcheck контейнера не пройдено.' }
    Start-Sleep -Seconds 2
}
if (-not $healthy) { throw 'Не вдалося дочекатися готовності контейнера.' }

$response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port" -UseBasicParsing
if ($response.StatusCode -ne 200 -or $response.Content -notmatch 'Hello [Dd]ocker') { throw 'Сайт не пройшов HTTP-перевірку.' }
if (-not $Initial -and $response.Content -notmatch 'data-site-version="2"') { throw 'Контейнер не віддає оновлену версію сайту.' }
Write-Host "Сайт: http://localhost:$Port"
Write-Host "HTTP $($response.StatusCode), healthcheck: healthy, образ: $imageTag"
