. "$PSScriptRoot/DockerHelpers.ps1"
Assert-DockerReady

Invoke-Docker --help
Invoke-Docker compose --help
if (Get-Command docker-compose -ErrorAction SilentlyContinue) { & docker-compose --help }

Remove-ProjectContainer -Name 'pr28-hello'
Invoke-Docker run --name pr28-hello --label ua.pr28.project=pr-28-docker hello-world

# Видалення образу без force; Docker відмовить, якщо він потрібен контейнеру.
Remove-ProjectContainer -Name 'pr28-busybox'
Invoke-Docker pull busybox
Invoke-Docker images busybox
$busyboxImageId = Invoke-Docker image inspect busybox --format '{{.Id}}'
Invoke-Docker image rm $busyboxImageId
Invoke-Docker pull busybox

Invoke-Docker run --name pr28-busybox --label ua.pr28.project=pr-28-docker busybox echo 'hello from busybox'
Invoke-Docker ps
Invoke-Docker ps -a
Invoke-Docker start pr28-busybox
Invoke-Docker stop pr28-busybox
Invoke-Docker rm pr28-busybox
