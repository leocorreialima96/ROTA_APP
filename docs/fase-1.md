# Fase 1: base e uso próprio

A fase 1 substitui a planilha da DJ PRIMUS no dia a dia: login, cadastro com CPF, lançar despesa com foto e leitura da nota, funcionamento offline, modo individual, fechar o período e gerar o PDF com comprovantes e a planilha no modelo.

Ela roda no **simulador do Firebase** (Emulator Suite), no plano gratuito, com o projeto de demonstração `demo-rota`. Nada vai para a nuvem de verdade até você seguir a seção "Antes do primeiro uso real".

## 1. Instalar uma vez

- [Flutter](https://docs.flutter.dev/get-started/install) (canal stable)
- [Node.js 22](https://nodejs.org)
- Java 21 (o simulador do Firebase precisa)

```bash
npm install
npm --prefix functions install
cd app && flutter pub get
```

## 2. Ligar o simulador

Na raiz do repositório:

```bash
npm --prefix functions run build
npx firebase emulators:start --project demo-rota
```

O painel do simulador abre em http://127.0.0.1:4000 (usuários, banco, fotos e logs das funções).

## 3. Abrir o app

Num outro terminal:

```bash
cd app
flutter run -d chrome
```

O app já vem apontado para o simulador. Para Google e Apple, o simulador mostra uma tela de login de mentira, em que você escolhe uma conta de teste.

### No celular, pela versão web

1. Descubra o IP do computador na rede (ex.: `192.168.0.10`).
2. Em `firebase.json`, troque `"host": "127.0.0.1"` por `"host": "0.0.0.0"` em todos os simuladores (assim o celular alcança o computador) e religue o simulador.
3. Gere a versão web apontando para o computador:

   ```bash
   cd app
   flutter build web --no-web-resources-cdn --dart-define=EMULATOR_HOST=192.168.0.10
   ```

4. No celular, na mesma rede Wi-Fi, abra `http://192.168.0.10:5000`.

Na versão web não há leitura automática da nota (o ML Kit só existe no app de iPhone e Android): a foto vai como comprovante e os campos são preenchidos à mão. O PDF de comprovante e o XML da NF-e funcionam igual.

### No Android (emulador ou aparelho)

```bash
flutter run --dart-define=EMULATOR_HOST=10.0.2.2        # emulador do Android Studio
flutter run --dart-define=EMULATOR_HOST=192.168.0.10    # aparelho na mesma rede
```

## 4. Testes

| Comando | O que confere |
|---|---|
| `cd app && flutter test` | CPF, valores em reais, leitura do texto da nota, NF-e, PDF (1 página por comprovante) e planilha no modelo DJ PRIMUS |
| `npm --prefix functions test` | Validação, máscara e criptografia do CPF |
| `npm run test:rules` | Tenta ler, alterar e apagar dados de outra conta (e sem login) e confirma que tudo é bloqueado; despesa fechada não muda; foto de despesa fechada não é trocada |
| `npm run test:functions` | Cadastro, CPF repetido recusado, CPF nunca gravado aberto, exclusão de conta liberando o CPF |

O GitHub roda tudo isso a cada envio (`.github/workflows/ci.yml`).

## 5. Como os dados ficam protegidos

- **Offline primeiro:** a despesa é gravada no celular na hora (cache do Firestore) e a foto fica guardada no aparelho (Hive) até subir. Cada despesa mostra "salva no celular" ou "salva na nuvem", e o Início avisa se algo passar de 24 h sem subir.
- **Regras no servidor:** cada pessoa só lê e escreve as próprias despesas e fotos. Uma despesa fechada não pode mais ser alterada nem apagada. O app não consegue gravar CPF nem trocar o "dono" de nada. Veja `firebase/firestore.rules` e `firebase/storage.rules`.
- **CPF:** validado e checado como único pela função `completeRegistration`, guardado criptografado (AES-256-GCM) num documento que só o servidor lê, e mostrado como `***.982.247-**`.
- **LGPD:** consentimento no cadastro, exportação dos dados e exclusão da conta pelo Perfil, registro de auditoria no servidor.

## 6. Antes do primeiro uso real

Faça nesta ordem, só quando for lançar notas de verdade:

1. **Plano Blaze e alerta de orçamento.** No console do Firebase, ative o Blaze e crie um alerta de orçamento (sugestão: R$ 50/mês). O Blaze não tem limite automático de gastos.
2. **Ligar o app ao projeto real** (região São Paulo):

   ```bash
   dart pub global activate flutterfire_cli
   cd app && flutterfire configure
   ```

   Isso substitui `app/lib/firebase_options.dart`. Depois troque `demo-rota` pelo id do projeto em `.firebaserc`.
3. **Login:** em Authentication, ligue E-mail/senha, Google e Apple (o Apple exige a conta de desenvolvedor da Apple).
4. **Segredos do CPF:**

   ```bash
   openssl rand -base64 32 | npx firebase functions:secrets:set CPF_ENCRYPTION_KEY
   openssl rand -base64 32 | npx firebase functions:secrets:set CPF_PEPPER
   ```

   Guarde uma cópia desses valores num lugar seguro: sem eles, o CPF criptografado não pode ser lido.
5. **Publicar regras, índices e funções:**

   ```bash
   npx firebase deploy --only firestore,storage,functions
   ```

6. **Backup diário e recuperação de 7 dias** (Google Cloud, troque `SEU-PROJETO`):

   ```bash
   gcloud firestore databases update --database='(default)' --enable-pitr --project=SEU-PROJETO
   gcloud firestore backups schedules create --database='(default)' --recurrence=daily --retention=14w --project=SEU-PROJETO
   ```

7. **Versões das fotos** (guarda fotos apagadas ou trocadas; proposta: 90 dias):

   ```bash
   gcloud storage buckets update gs://SEU-PROJETO.firebasestorage.app --versioning
   ```

   e uma regra de ciclo de vida apagando versões antigas depois de 90 dias.
8. **Rodar o app sem o simulador:** `flutter run --dart-define=USE_EMULATORS=false`.

A exportação mensal para outra região, o teste trimestral de restauração e o App Check entram junto com o lançamento (fase 5), como na especificação.

## 7. Decisões tomadas nesta fase

- **Colunas do relatório:** segui o modelo atual da DJ PRIMUS (Ferramentas/Outros e Estacionamento/Lava Rápido juntos). Cada categoria escolhe a sua coluna, então dá para mudar sem mexer no código. (Item em aberto na especificação.)
- **Nome do arquivo:** usa o início e o fim do período escolhidos no fechamento.
- **NF-e pelo XML:** vira uma página-resumo no PDF (emitente, CNPJ, chave, itens e total).
- **Dados bancários e Pix:** a tela e o campo no relatório entram na fase 2.
- **Gamificação:** XP, nível, sequência e medalhas ficaram para a fase 4; o Início já tem os espaços.
