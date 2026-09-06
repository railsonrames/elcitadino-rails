# Pipeline CI/CD — GitHub Actions

Companheiro do [`deploy/README.md`](./README.md). Aqui o foco é só o
`.github/workflows/deploy.yml`: o que ele faz e por quê.

A pipeline de **qualidade** (testes, rubocop, brakeman, importmap audit) fica no
`.github/workflows/ci.yml` e roda em todo push/PR — independente desta.

---

## Visão geral

```
push na main ───────────▶ deploy  (destino = staging)
release publicado (v*) ──▶ deploy  (destino = production, com aprovação)
Run workflow (manual) ───▶ deploy  (destino e comando à escolha: deploy | setup | rollback)
```

Um único job, `deploy`, que:

1. faz checkout + prepara Ruby (bundler cache) + buildx
2. escreve a chave SSH e sobe um `ssh-agent`
3. roda `bin/kamal <comando> [-d staging]`
   - `deploy` builda a imagem no runner, faz push pro **ghcr.io**, e no servidor:
     `docker pull` → sobe o container novo → `db:prepare` no entrypoint → para o antigo
   - `setup` faz o bootstrap (sobe os accessories Postgres) — usado só na 1ª vez por destino
   - `rollback` volta para a imagem anterior
4. bate em `https://<host>/up` até responder `200`

## Como o destino é decidido

```yaml
DEST: ${{ (github.event_name == 'release' || github.event.inputs.destination == 'production')
          && 'production' || 'staging' }}
```

- `release` publicado → **production**
- `workflow_dispatch` → o que você escolher no dropdown
- qualquer outra coisa (push na `main`) → **staging**

`production` só roda de fato porque o secret/registry/SSH são os mesmos; o que muda entre
destinos é só o `-d staging` passado ao Kamal, que faz ele mesclar `config/deploy.staging.yml`.

## Trava de concorrência

```yaml
concurrency:
  group: elcitadino-${{ ...destino... }}
  cancel-in-progress: false
```

Dois deploys do mesmo destino não rodam em paralelo — o segundo espera. Não cancela um
deploy no meio (cancelar um `docker` pela metade é pior que esperar). Staging e produção
têm grupos diferentes, então não bloqueiam um ao outro.

## Kill-switch

```yaml
if: vars.DEPLOY_ENABLED == 'true'
```

Enquanto a *repository variable* `DEPLOY_ENABLED` não for `true`, o job aparece como
**Skipped**. Liga o auto-deploy só quando a VPS está pronta; desliga rápido se precisar.

## Segredos

| de onde vem | o quê |
|---|---|
| `secrets.GITHUB_TOKEN` (automático) | login no ghcr.io (`KAMAL_REGISTRY_PASSWORD`) — efêmero, escopo do run |
| `secrets.SSH_PRIVATE_KEY` | chave do usuário `kamal` na VPS |
| `secrets.RAILS_MASTER_KEY` | `config/credentials.yml.enc` (Cloudinary, secret_key_base…) |
| `secrets.ELCITADINO_DATABASE_PASSWORD` | senha do Postgres — app e container |

O `.kamal/secrets` do repo só faz o *mapeamento* `NOME=$ENV` — nenhum valor cru é versionado.

## Environments

O job declara `environment: production|staging`. Criando o Environment `production` com
**Required reviewers**, cada deploy de produção pausa esperando um clique. Sem criar, a
referência é inofensiva.

## O que a pipeline pressupõe (feito pelo `provision-vps.sh`)

- Docker instalado na VPS.
- Usuário `kamal` no grupo `docker`, com a pública do CI em `authorized_keys`.
- `/opt/elcitadino/postgres/{production,staging}` existindo (bind-mount dos accessories).
- Caddy com os vhosts apontando para `127.0.0.1:3000` (prod) e `:3001` (staging).

Sem isso, `kamal setup`/`deploy` falha (SSH, permissão de Docker, ou 502 no Caddy).

## Recriar do zero (se o `deploy.yml` sumir)

1. `mkdir -p .github/workflows && $EDITOR .github/workflows/deploy.yml`
2. Colar o conteúdo atual do arquivo (está versionado — use `git show`).
3. Conferir os pré-requisitos acima e os Secrets/Variables do [`README.md`](./README.md#passo-5).
4. `Actions → deploy → Run workflow → command=setup` para cada destino.

## Endurecendo (opcional)

- **Fixar host key**: secret `SSH_KNOWN_HOSTS` = saída de `ssh-keyscan 51.195.220.76`,
  e no step *Configure SSH* trocar o `ssh-keyscan` por um `printf` desse valor.
- **Só deployar staging se o CI passou**: `on: workflow_run: workflows: [CI]: types:
  [completed]` + `if: github.event.workflow_run.conclusion == 'success'`.
- **`workflow_dispatch` com confirmação**: input obrigatório (digitar `deploy`) para não
  clicar sem querer.
- **Assinar a imagem** (cosign) e verificar no servidor antes de subir.
- **Notificar em falha**: step final `if: failure()` mandando webhook/e-mail.
