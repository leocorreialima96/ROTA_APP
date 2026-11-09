# Liga o simulador do Firebase e abre a Rota no Chrome.
# Como usar: dê dois cliques no arquivo .bat de mesmo nome.

$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz
Write-Host "`n== Rota: ligando o simulador do Firebase (janela separada) ==`n" -ForegroundColor Yellow
npm --prefix functions run build | Out-Null
Start-Process powershell -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', "Set-Location '$raiz'; npx firebase emulators:start --project demo-rota"

Write-Host 'Esperando o simulador ficar pronto...'
for ($i = 0; $i -lt 120; $i++) {
  try { Invoke-WebRequest 'http://127.0.0.1:4000' -UseBasicParsing -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep 2 }
}

Write-Host 'Abrindo o app no Chrome (a primeira vez demora uns minutos)...' -ForegroundColor Green
Set-Location (Join-Path $raiz 'app')
flutter run -d chrome
