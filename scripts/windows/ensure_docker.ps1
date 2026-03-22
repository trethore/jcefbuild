[CmdletBinding()]
param(
    [int]$TimeoutMinutes = 3
)

$serviceNames = @('docker', 'com.docker.service')
$services = foreach ($name in $serviceNames) {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service) {
        $service
    }
}

foreach ($service in $services) {
    if ($service.Status -ne 'Running') {
        Write-Host ("Starting service {0}..." -f $service.Name)
        Start-Service -Name $service.Name -ErrorAction SilentlyContinue
    }
}

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
    docker version *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Docker daemon is ready.'
        exit 0
    }

    foreach ($service in $services) {
        try {
            $service.Refresh()
            if ($service.Status -ne 'Running') {
                Start-Service -Name $service.Name -ErrorAction SilentlyContinue
            }
        } catch {
        }
    }

    Start-Sleep -Seconds 5
}

Write-Error 'Docker daemon did not become available in time.'
docker version
exit 1
