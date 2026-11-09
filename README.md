# Rota

**Seus relatórios feitos em poucos cliques.** App de iPhone e Android (um único código em Flutter) que transforma notas fiscais de viagem em relatório de despesas pronto, com os comprovantes em PDF.

- Especificação: *Rota: especificação do produto e plano técnico (v1)* (documento no Claude).
- Protótipo: *App de Despesas — Protótipo* (canvas no Claude).

## Estado atual: fase 1 (base e uso próprio)

O que já funciona, tudo testado no simulador do Firebase:

| Tela | O que faz |
|---|---|
| 1 · Entrar | Apple, Google ou e-mail (criar conta, entrar, esqueci a senha). "Sou empresa" avisa que chega na fase 3. |
| 2 · Cadastro | Nome e CPF obrigatórios. CPF validado na hora e **no servidor**, único por conta, gravado criptografado e mostrado mascarado. Consentimento LGPD. |
| 4 · Vincular | Modo individual (empresa: "em breve"). |
| 5 · Categorias | As 8 padrão com cores do protótipo; criar, reordenar, escolher a coluna do relatório e um limite por despesa. Pode pular. |
| 6 · Início | Período aberto, total, divisão por categoria, % pronto, pendências (sem comprovante, mais de 24 h sem subir) e últimos lançamentos. |
| 7/8/9 · Incluir despesa | Fotografar (leitura automática da nota no celular, sem internet), galeria, PDF, XML da NF-e ou digitar. Dividir a conta ou ajustar valor (o total da nota vai para a observação). Observação do veículo no combustível. "Salvar e próxima". |
| 13/14 · Despesas | Agrupadas por dia, filtro "sem comprovante", "salva no celular" / "salva na nuvem", editar e excluir. |
| 10 · Fechar período | Datas, % pronto, despesas sem comprovante com "Anexar", totais por categoria, adiantamento, total a reembolsar. |
| 11/12 · Relatório | PDF único (relatório + 1 comprovante por página em ordem de data, "Comprovante não anexado" em vermelho) e planilha no modelo DJ PRIMUS, com o nome "Relatório de gastos técnicos DD-MM-AAAA_DD-MM-AAAA_NOME". Gerados no celular, sem internet. |
| 17 · Meus relatórios | Lista dos relatórios emitidos; gera os arquivos de novo quando quiser. |
| 15 · Perfil | CPF bloqueado, editar dados, categorias, exportar meus dados (JSON), política e termos, excluir conta. |

Fica para as próximas fases (como na especificação): projetos, rascunhos, pendências completas, dados bancários e Pix (fase 2); empresa, aprovação e pagamento (fase 3); painéis, XP e medalhas (fase 4); site de vendas e lojas (fase 5).

## Como está organizado

```
app/          App Flutter (iPhone, Android e web)
  lib/core/       CPF, formatação de moeda e datas, tema
  lib/models/     Despesa, relatório, categoria, perfil
  lib/parsing/    Leitura do texto da nota (OCR) e do XML da NF-e
  lib/reports/    PDF e planilha no modelo DJ PRIMUS
  lib/services/   Login, banco offline, fotos, sincronização
  lib/screens/    Telas
functions/    Regras no servidor (cadastro com CPF, exclusão de conta)
firebase/     Regras de segurança do banco e das fotos, índices
tests/        Testes das regras e das funções no simulador
docs/         Guias (comece por docs/fase-1.md)
```

## Rodar e testar

Veja **[docs/fase-1.md](docs/fase-1.md)**: como abrir o app no simulador, testar no celular pela versão web, rodar os testes e o que fazer antes do primeiro uso real.

Instalação automática: `scripts/instalar-windows.bat` ou `scripts/instalar-mac.sh`; depois `scripts/abrir-windows.bat` ou `scripts/abrir-mac.sh`.

Testes (na raiz do repositório):

```bash
npm install && npm --prefix functions install
npm run test:rules        # tenta ler dados de outra conta e confirma o bloqueio
npm run test:functions    # cadastro, CPF repetido, exclusão de conta
cd app && flutter test    # CPF, leitura de nota, NF-e, PDF e planilha
```
