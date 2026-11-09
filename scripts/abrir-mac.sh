#!/bin/bash
# Liga o simulador do Firebase e abre a Rota no Chrome.
# Como usar: no Terminal, arraste este arquivo para a janela e aperte Enter.
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
npm --prefix functions run build >/dev/null
echo "== Rota: ligando o simulador do Firebase =="
npx firebase emulators:start --project demo-rota > emulador.log 2>&1 &
EMU=$!
trap "kill $EMU 2>/dev/null" EXIT
until curl -s http://127.0.0.1:4000 >/dev/null; do sleep 2; done
echo "Abrindo o app no Chrome (a primeira vez demora uns minutos)..."
cd app && flutter run -d chrome
