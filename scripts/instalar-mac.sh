#!/bin/bash
# Instala tudo o que a Rota precisa no Mac e prepara o projeto.
# Como usar: no Terminal, arraste este arquivo para a janela e aperte Enter.
# Pode rodar de novo sem problema: o que já estiver instalado é pulado.
set -e
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
echo; echo "== Rota: instalação =="; echo

if ! command -v brew >/dev/null; then
  echo "... instalando o Homebrew (vai pedir a senha do Mac)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

command -v node >/dev/null || brew install node@22 && brew link --overwrite node@22 2>/dev/null || true
if ! /usr/libexec/java_home -v 21 >/dev/null 2>&1; then brew install --cask temurin@21; fi
command -v flutter >/dev/null || brew install --cask flutter
[ -d "/Applications/Google Chrome.app" ] || brew install --cask google-chrome
flutter config --no-analytics >/dev/null

echo "... preparando o projeto"
cd "$RAIZ"
npm install
npm --prefix functions install
npm --prefix functions run build
cd app && flutter pub get

echo; echo "Tudo instalado! Para abrir o app, rode scripts/abrir-mac.sh"; echo
