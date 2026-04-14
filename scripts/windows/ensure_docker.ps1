[CmdletBinding()]
param(
    [int]$TimeoutMinutes = 3,
    [string]$DataRoot = ''
)

$serviceNames = @('docker', 'com.docker.service')

function Get-DockerConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }

    $rawContent = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($rawContent)) {
        return @{}
    }

    $configObject = $rawContent | ConvertFrom-Json
    $config = @{}

    foreach ($property in $configObject.PSObject.Properties) {
        $config[$property.Name] = $property.Value
    }

    return $config
}

function Set-DockerDataRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DesiredRoot
    )

    if ([string]::IsNullOrWhiteSpace($DesiredRoot)) {
        return $false
    }

    $rootDrive = Split-Path -Path $DesiredRoot -Qualifier
    if ($rootDrive -and -not (Test-Path -LiteralPath $rootDrive)) {
        throw ('Requested Docker data-root drive does not exist: {0}' -f $rootDrive)
    }

    New-Item -ItemType Directory -Path $DesiredRoot -Force | Out-Null

    $configDir = 'C:\ProgramData\Docker\config'
    $configPath = Join-Path $configDir 'daemon.json'
    $config = Get-DockerConfig -Path $configPath
    $currentRoot = [string]$config['data-root']

    if ($currentRoot -and [string]::Compare($currentRoot, $DesiredRoot, $true) -eq 0) {
        Write-Host ('Docker data-root already set to {0}.' -f $DesiredRoot)
        return $false
    }

    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    $config['data-root'] = $DesiredRoot
    $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding Ascii

    Write-Host ('Configured Docker data-root: {0}' -f $DesiredRoot)
    return $true
}

$dockerConfigUpdated = $false
if (-not [string]::IsNullOrWhiteSpace($DataRoot)) {
    $dockerConfigUpdated = Set-DockerDataRoot -DesiredRoot $DataRoot
}

$services = foreach ($name in $serviceNames) {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service) {
        $service
    }
}

if ($dockerConfigUpdated) {
    foreach ($service in $services) {
        if ($service.Status -eq 'Running') {
            Write-Host ('Stopping service {0} to apply Docker config...' -f $service.Name)
            Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
        }
    }

    Start-Sleep -Seconds 5

    foreach ($service in $services) {
        $service.Refresh()
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
