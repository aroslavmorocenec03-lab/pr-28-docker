param([int]$Port = 8080)
. "$PSScriptRoot/DockerHelpers.ps1"
Assert-DockerReady
$reportDirectory = Join-Path $script:ProjectRoot 'reports'
[System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$images = Invoke-Docker images
$containers = Invoke-Docker ps --filter label=ua.pr28.project=pr-28-docker
$allContainers = Invoke-Docker ps -a --filter label=ua.pr28.project=pr-28-docker
$stats = Invoke-Docker stats --no-stream static-website
$health = Invoke-Docker inspect --format '{{.State.Health.Status}}' static-website
$response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port" -UseBasicParsing
$timestamp = [DateTimeOffset]::UtcNow.ToString('u')
$utf8 = New-Object System.Text.UTF8Encoding($false)

$evidence = @{'docker-images.txt'=$images; 'docker-ps.txt'=$containers; 'docker-ps-all.txt'=$allContainers; 'docker-stats.txt'=$stats}
foreach ($name in $evidence.Keys) {
    [System.IO.File]::WriteAllText((Join-Path $reportDirectory $name), ($evidence[$name] -join [Environment]::NewLine), $utf8)
}
[System.IO.File]::WriteAllText((Join-Path $reportDirectory 'http-check.txt'), "UTC: $timestamp`nHTTP status: $($response.StatusCode)`nHealth: $health`nURL: http://localhost:$Port", $utf8)

$imagesHtml = [System.Net.WebUtility]::HtmlEncode(($images -join [Environment]::NewLine))
$containersHtml = [System.Net.WebUtility]::HtmlEncode(($containers -join [Environment]::NewLine))
$evidenceHtml = @"
<!doctype html><html lang="uk"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Фактичні результати Docker — ПР-28</title>
<style>body{font:16px system-ui;margin:32px;color:#203247}pre{padding:20px;background:#f2f5f8;border:1px solid #d3dee8;overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere}h1{font-size:26px}p{color:#63778b}</style>
<h1>Практична №28 — результати Docker</h1><p>Час отримання: $timestamp UTC. Нижче наведено фактичний вивід команд Docker CLI.</p>
<h2>docker images</h2><pre>$imagesHtml</pre><h2>docker ps — контейнери практичної</h2><pre>$containersHtml</pre>
<p>HTTP: $($response.StatusCode). Healthcheck: $health.</p></html>
"@
[System.IO.File]::WriteAllText((Join-Path $reportDirectory 'evidence.html'), $evidenceHtml, $utf8)
Write-Host 'Фактичні текстові результати записано в reports/. Додайте також скриншоти списків і сайту.'
