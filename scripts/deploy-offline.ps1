<#
Builds both images and saves them as dist\labour-backend.tar.gz and dist\labour-frontend.tar.gz (old files in dist\ are removed).
Optionally copies them to a VM that GitHub cannot reach and starts them. Needs Docker Desktop and, for copying, the OpenSSH client (scp/ssh).

  .\scripts\deploy-offline.ps1                                    # build + save into dist\ only (copy the files yourself)
  .\scripts\deploy-offline.ps1 -VmHost 10.0.0.5 -VmUser azureuser -Deploy
  .\scripts\deploy-offline.ps1 -VmHost 10.0.0.5 -VmUser azureuser -JumpHost bastion.example.com -Deploy

First deploy only: put backend.env (copy of backend\.env.example, filled in) into -RemoteDir on the VM.
#>
param(
    [string] $VmHost,
    [string] $VmUser,
    [string] $JumpHost,
    [string] $RemoteDir = '/opt/labour-manager',
    [string] $Platform = 'linux/amd64', # must match `uname -m` on the VM (x86_64 = linux/amd64, aarch64 = linux/arm64)
    [switch] $Deploy
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Invoke-Native([scriptblock] $Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $Command" }
}

$env:DOCKER_DEFAULT_PLATFORM = $Platform
Invoke-Native { docker compose -f docker-compose.yml -f docker-compose.build.yml build }

New-Item -ItemType Directory -Force dist | Out-Null
Get-ChildItem dist -File | Remove-Item
foreach ($name in 'labour-backend', 'labour-frontend') {
    $tar = "dist/$name.tar"
    Invoke-Native { docker save -o $tar "${name}:latest" }
    $in = [IO.File]::OpenRead($tar)
    $out = [IO.File]::Create("$tar.gz")
    $gz = [IO.Compression.GZipStream]::new($out, [IO.Compression.CompressionMode]::Compress)
    try { $in.CopyTo($gz) } finally { $gz.Dispose(); $out.Dispose(); $in.Dispose() }
    Remove-Item $tar
    Write-Host ("{0}.gz  sha256 {1}" -f $tar, (Get-FileHash "$tar.gz").Hash)
}

if (-not $VmHost) {
    Write-Host "`nImages are in dist\. Copy them, docker-compose.yml and backend.env to the VM, then see README section 'Docker deployment'."
    return
}

$target = "$VmUser@$VmHost"
$jump = if ($JumpHost) { @('-J', $JumpHost) } else { @() }
Invoke-Native { ssh @jump $target "mkdir -p $RemoteDir" }
Invoke-Native { scp @jump dist/labour-backend.tar.gz dist/labour-frontend.tar.gz docker-compose.yml "${target}:$RemoteDir/" }

if ($Deploy) {
    $remote = "cd $RemoteDir && test -f backend.env && " +
        "docker load -i labour-backend.tar.gz && docker load -i labour-frontend.tar.gz && " +
        "docker compose up -d && docker compose ps"
    Invoke-Native { ssh @jump $target $remote }
}
else {
    Write-Host "`nCopied. On the VM: cd $RemoteDir; docker load -i each .tar.gz; docker compose up -d"
}
