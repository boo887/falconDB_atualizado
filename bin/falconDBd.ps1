param([string]$action)

$root = Split-Path -Parent $PSScriptRoot
$compose = Join-Path $root "docker-compose.yml"

$containers = @("rp","dn0s1","dn0s2","dn0s3","dn1s1","dn1s2","dn1s3","dn2s1","dn2s2","dn2s3")

switch ($action) {
  "start" {
    Write-Host "Building image..."
    podman build -t falcondb:latest -f (Join-Path $root "Containerfile") $root
    Write-Host "Starting all servers..."
    podman compose -f $compose up -d
  }
  "stop" {
    Write-Host "Stopping all servers..."
    podman compose -f $compose down
  }
  "restart" {
    podman compose -f $compose down
    Start-Sleep -Seconds 2
    podman compose -f $compose build
    podman compose -f $compose up -d
  }
  "stat" {
    Write-Host "=== Container status ==="
    podman ps
    Write-Host ""
    Write-Host "=== Forever processes ==="
    foreach ($c in $containers) {
      Write-Host "--- $c ---"
      $result = podman exec $c forever list 2>$null
      if ($result) { $result } else { Write-Host "  container not running" }
    }
  }
  "clean" {
    Write-Host "Removing all containers..."
    podman rm -f $containers
  }
  default {
    Write-Host "Usage: falconDBd.ps1 {start|stop|restart|stat|clean}"
    exit 1
  }
}
