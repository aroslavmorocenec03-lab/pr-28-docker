$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:ProjectLabel = 'pr-28-docker'

function Invoke-Docker {
    & docker @args
    if ($LASTEXITCODE -ne 0) {
        throw ('Docker завершився з помилкою: docker ' + ($args -join ' '))
    }
}

function Assert-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Встановіть Docker Desktop і відкрийте новий термінал.'
    }
    $engineType = Invoke-Docker info --format '{{.OSType}}'
    if ($engineType -ne 'linux') { throw 'Для цієї роботи потрібен режим Linux containers.' }
}

function Remove-ProjectContainer {
    param([Parameter(Mandatory = $true)][string]$Name)
    $containerNames = @(Invoke-Docker ps -a --format '{{.Names}}')
    if ($containerNames -notcontains $Name) { return }
    $labelsJson = Invoke-Docker inspect --format '{{json .Config.Labels}}' $Name
    $labels = $labelsJson | ConvertFrom-Json
    if ($labels.'ua.pr28.project' -ne $script:ProjectLabel) {
        throw ('Контейнер ' + $Name + ' не належить цій практичній. Оберіть іншу назву вручну.')
    }
    Invoke-Docker stop $Name
    Invoke-Docker rm $Name
}
