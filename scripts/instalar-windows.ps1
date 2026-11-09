# Instala tudo o que a Rota precisa no Windows 10/11 e prepara o projeto.
# Como usar: dê dois cliques no arquivo .bat de mesmo nome.
# Pode rodar de novo sem problema: o que já estiver instalado é pulado.

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Write-Host "`n== Rota: instalação ==`n" -ForegroundColor Yellow

function Tem($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function AtualizarPath {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Tem 'winget')) {
  Write-Host 'O winget (Instalador de Aplicativos) não foi encontrado. Instale o "Instalador de Aplicativos" pela Microsoft Store e rode este script de novo.' -ForegroundColor Red
  Read-Host 'Enter para sair'; exit 1
}

$pacotes = @(
  @{ id = 'Git.Git';                        cmd = 'git';  nome = 'Git' },
  @{ id = 'OpenJS.NodeJS.LTS';              cmd = 'node'; nome = 'Node.js' },
  @{ id = 'EclipseAdoptium.Temurin.21.JDK'; cmd = 'java'; nome = 'Java 21' },
  @{ id = 'Google.Chrome';                  cmd = $null;  nome = 'Google Chrome' }
)
foreach ($p in $pacotes) {
  if ($p.cmd -and (Tem $p.cmd)) { Write-Host "OK  $($p.nome) já instalado"; continue }
  Write-Host "... instalando $($p.nome)"
  winget install --id $p.id -e --accept-source-agreements --accept-package-agreements --silent | Out-Null
}
AtualizarPath

# Flutter (versão estável), em %USERPROFILE%\flutter
$flutterDir = Join-Path $env:USERPROFILE 'flutter'
if (-not (Tem 'flutter')) {
  if (-not (Test-Path (Join-Path $flutterDir 'bin\flutter.bat'))) {
    Write-Host '... baixando o Flutter (uns 1 GB, pode demorar)'
    $info = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    $hash = $info.current_release.stable
    $rel = $info.releases | Where-Object { $_.hash -eq $hash } | Select-Object -First 1
    $zip = Join-Path $env:TEMP 'flutter.zip'
    Invoke-WebRequest "$($info.base_url)/$($rel.archive)" -OutFile $zip
    Write-Host '... descompactando o Flutter'
    Expand-Archive $zip -DestinationPath $env:USERPROFILE -Force
    Remove-Item $zip
  }
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($userPath -notlike "*$flutterDir\bin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterDir\bin", 'User')
  }
  AtualizarPath
}
Write-Host 'OK  Flutter pronto'
flutter config --no-analytics | Out-Null

Write-Host '... preparando o projeto'
Set-Location $raiz
npm install
npm --prefix functions install
npm --prefix functions run build
Set-Location (Join-Path $raiz 'app')
flutter pub get

Write-Host "`nTudo instalado! Para abrir o app, rode scripts\abrir-windows.ps1`n" -ForegroundColor Green
Read-Host 'Enter para fechar'
