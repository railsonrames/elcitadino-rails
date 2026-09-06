# Deploy — Elcitadino

Como sair de "tenho uma VPS com o endless-notebook rodando" até "Elcitadino online,
com staging e deploy de produção por release".

> Detalhe do pipeline em si (o que o `deploy.yml` faz e como recriá-lo):
> [`PIPELINE.md`](./PIPELINE.md).

## Arquitetura

```
Internet ──HTTPS──▶ Caddy (nativo na VPS, :80/:443, TLS Let's Encrypt automático)
                      │  reverse_proxy por host
        ┌─────────────┼──────────────────────────┬───────────────────────┐
        ▼             ▼                           ▼                       ▼
 notebook.railson  elcitadino.railson.click  staging.elcitadino…   (hostname OVH → redir)
   :8080              :3000                     :3001
 endless-notebook  container Docker           container Docker
 (systemd, Go)     ghcr.io/railsonrames/elcitadino  (mesma imagem)
                      │                           │
                      ▼                           ▼
               elcitadino-db              elcitadino-staging-db
               postgres:17-alpine         postgres:17-alpine
               /opt/elcitadino/postgres/production   …/staging
```

- **Caddy continua sendo o único proxy de borda.** O Kamal roda com `proxy: false` e
  publica cada container só em `127.0.0.1:<porta>`; o Caddy encaminha por host e cuida do TLS.
- **Kamal 2** gere o container da app + o Postgres (accessory). Imagem no **ghcr.io**.
- **Dois destinos Kamal na mesma VPS:** produção (`config/deploy.yml`) e staging
  (`config/deploy.staging.yml`, via `kamal deploy -d staging`). Containers, rede e volume
  com prefixo distinto — isolados.
- **Solid Queue** roda dentro do Puma (`SOLID_QUEUE_IN_PUMA=true`), incluindo as tarefas
  de `config/recurring.yml`.
- **db:prepare** roda no boot do container (`bin/docker-entrypoint`) e cria/migra as 4
  bases (`primary/cache/queue/cable`).
- **Backup** diário dos dois Postgres por timer systemd (`pg-backup.sh`, retém 14).

Arquivos deste diretório:

| arquivo | vai para | o quê |
|---|---|---|
| `provision-vps.sh` | roda 1x na VPS | swap, Docker, usuário `kamal`, dirs de dados, timer de backup |
| `Caddyfile.elcitadino` | trecho colado em `/etc/caddy/Caddyfile` | vhosts do Elcitadino (prod + staging) |
| `pg-backup.sh` | `/opt/elcitadino/pg-backup.sh` | `pg_dump` dos dois bancos |
| `elcitadino-pg-backup.{service,timer}` | `/etc/systemd/system/` | backup diário 03:00 |

---

## Passo 1 — DNS

No painel de `railson.click`, criar (deixando o apex e o `www` do GitHub Pages intocados):

| tipo | nome | valor |
|---|---|---|
| `A` | `elcitadino` | `51.195.220.76` |
| `AAAA` | `elcitadino` | `2001:41d0:801:2000::869f` |
| `A` | `staging.elcitadino` | `51.195.220.76` |
| `AAAA` | `staging.elcitadino` | `2001:41d0:801:2000::869f` |
| `A` | `notebook` | `51.195.220.76` |
| `AAAA` | `notebook` | `2001:41d0:801:2000::869f` |

Esperar propagar:

```bash
dig +short elcitadino.railson.click          # deve devolver 51.195.220.76
dig +short staging.elcitadino.railson.click
```

O Caddy só emite o certificado depois disso.

## Passo 2 — Chave SSH dedicada ao CI

No **seu computador**, par exclusivo do deploy, **sem passphrase**:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/elcitadino-deploy -N "" -C "kamal@github-actions"
```

- **Privada** (`~/.ssh/elcitadino-deploy`) → GitHub Secret `SSH_PRIVATE_KEY`.
- **Pública** (`~/.ssh/elcitadino-deploy.pub`) → entra no `provision-vps.sh` como `KAMAL_PUBKEY`.

## Passo 3 — Provisionar a VPS

Copiar a pasta `deploy/` para a VPS e rodar o script, passando a **pública** do passo 2:

```bash
scp -r deploy ubuntu@51.195.220.76:/tmp/elcitadino-deploy
ssh ubuntu@51.195.220.76 \
  "export KAMAL_PUBKEY=\"$(cat ~/.ssh/elcitadino-deploy.pub)\" && \
   sudo --preserve-env=KAMAL_PUBKEY bash /tmp/elcitadino-deploy/provision-vps.sh"
```

Ao final: swap de 2 GB, Docker CE, usuário `kamal` (grupo `docker`) com a chave do CI,
`/opt/elcitadino/{postgres/{production,staging},backups}` e o `elcitadino-pg-backup.timer`
ativo. **Não** mexe no Caddy nem no endless-notebook.

Teste o acesso do CI:

```bash
ssh -i ~/.ssh/elcitadino-deploy kamal@51.195.220.76 'docker version --format "{{.Server.Version}}"'
```

Tem que responder sem pedir senha.

## Passo 4 — Caddy

Gerar o hash da senha do staging (na VPS ou onde tiver o Caddy):

```bash
caddy hash-password        # digite a senha; copie o hash $2a$...
```

Editar `deploy/Caddyfile.elcitadino`, trocar `REPLACE_WITH_BCRYPT_HASH` pelo hash, e
**acrescentar os blocos** ao `/etc/caddy/Caddyfile` da VPS. Substituir o bloco atual do
hostname OVH pela migração do endless-notebook:

```caddy
notebook.railson.click {
	encode zstd gzip
	reverse_proxy 127.0.0.1:8080
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "DENY"
		Referrer-Policy "same-origin"
		-Server
	}
	log { output file /var/log/caddy/endless-notebook.log { roll_size 10M roll_keep 5 } }
}

vps-1aee2939.vps.ovh.net {
	redir https://notebook.railson.click{uri} permanent
}
```

Validar e recarregar:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

## Passo 5 — Secrets e Variables no GitHub

Repo `railsonrames/elcitadino-rails` → **Settings → Secrets and variables → Actions**.

**Secrets:**

| secret | valor |
|---|---|
| `RAILS_MASTER_KEY` | conteúdo de `config/master.key` |
| `SSH_PRIVATE_KEY` | conteúdo **inteiro** de `~/.ssh/elcitadino-deploy` |
| `ELCITADINO_DATABASE_PASSWORD` | senha forte (a mesma vale para o app e o container Postgres) |

Pela CLI:

```bash
gh secret set RAILS_MASTER_KEY              < config/master.key
gh secret set SSH_PRIVATE_KEY               < ~/.ssh/elcitadino-deploy
gh secret set ELCITADINO_DATABASE_PASSWORD --body "$(openssl rand -base64 30)"
```

> `KAMAL_REGISTRY_PASSWORD` **não** é secret — o workflow usa o `GITHUB_TOKEN` do run
> para logar no ghcr.io. `SSH_HOST` também não: o IP está no `config/deploy.yml`.

**Variable** (aba Variables) — o kill-switch:

```bash
gh variable set DEPLOY_ENABLED --body "true"
```

Com `false` (ou ausente), o job `deploy` é pulado.

**Environments** (`Settings → Environments`): criar `staging` e `production`. Em
`production`, marcar **Required reviewers** (você) → todo deploy de produção pausa
esperando aprovação.

## Passo 6 — Bootstrap (primeira vez, por destino)

O primeiro deploy precisa subir os accessories (Postgres) — é o `kamal setup`.
Faça pela pipeline, sem Docker local:

**Actions → deploy → Run workflow**
- `command = setup`, `destination = staging` → executa
- de novo com `command = setup`, `destination = production`

Cada um: builda a imagem, faz push pro ghcr, sobe `elcitadino[-staging]-db`, sobe o
container da app (que roda `db:prepare`), e bate em `/up`.

## Passo 7 — Operação normal

| Ação | Como |
|---|---|
| **Deploy de staging** | `git push origin main` (automático) |
| **Deploy de produção** | `gh release create v0.1.0 --generate-notes` (pausa p/ aprovação) |
| **Deploy manual** | Actions → deploy → Run workflow → escolher destino |
| **Rollback** | Actions → Run workflow → `command = rollback` + destino. Ou `bin/kamal rollback [-d staging]` local |
| **Pausar tudo** | `gh variable set DEPLOY_ENABLED --body false` |
| **Logs** | `bin/kamal logs [-d staging]` ou, na VPS, `docker logs -f elcitadino-web-<sha>` |
| **Console** | `bin/kamal console [-d staging]` |
| **Migrations** | rodam sozinhas no boot (`db:prepare`). Forçar: `bin/kamal app exec [-d staging] "bin/rails db:migrate"` |

### Backups

```bash
systemctl list-timers elcitadino-pg-backup
ls -lh /opt/elcitadino/backups/
sudo systemctl start elcitadino-pg-backup       # backup sob demanda
```

**Restaurar** (exemplo, produção):

```bash
gunzip -c /opt/elcitadino/backups/production-YYYYmmdd-HHMMSS.sql.gz \
  | docker exec -i elcitadino-db psql -U elcitadino -d elcitadino_production
```

---

## Migrar para outra VPS

1. Provisionar a nova VPS: instalar Caddy (pacote oficial) + rodar `provision-vps.sh`.
2. Copiar `/etc/caddy/Caddyfile` (ajustar IPs se necessário) e recarregar.
3. Trocar o IP em `config/deploy.yml`, `config/deploy.staging.yml` e no `ssh-keyscan`
   do `.github/workflows/deploy.yml`.
4. Restaurar o último dump em `/opt/elcitadino/backups/` para os containers `*-db`
   (subir os accessories antes: `bin/kamal accessory boot db [-d staging]`).
5. Atualizar os registros DNS (`A`/`AAAA`) para o novo IP.
6. `Run workflow → command = setup` para cada destino.

Tudo que é estado vive em: os volumes `/opt/elcitadino/postgres/*` (banco), o Cloudinary
(uploads — externo, nada a migrar) e os Secrets do GitHub.

## Sugestões (opcionais)

- **Monitor externo**: `https://elcitadino.railson.click/up` no healthchecks.io / UptimeRobot.
- **Backup off-site**: `restic`/`rclone` empurrando `/opt/elcitadino/backups/` para um bucket
  (OVH Object Storage, Backblaze B2). Backup na mesma máquina não protege contra perda de disco.
- **Snapshot da OVH**: habilitar snapshot automático da VPS no painel.
- **`known_hosts` fixo no CI**: secret `SSH_KNOWN_HOSTS` com a saída de
  `ssh-keyscan 51.195.220.76`, em vez do `ssh-keyscan` dentro do workflow (evita TOFU).
- **Encadear com o CI**: fazer o `deploy.yml` depender do `ci.yml` via `workflow_run`
  para só publicar staging quando os testes passarem.

## Troubleshooting

| Sintoma | Causa provável | Correção |
|---|---|---|
| `deploy` aparece **Skipped** | `DEPLOY_ENABLED` != `true` | `gh variable set DEPLOY_ENABLED --body true` |
| `Permission denied (publickey)` | `SSH_PRIVATE_KEY` incompleta ou pública não está no `kamal@` | recadastrar o secret; conferir `/home/kamal/.ssh/authorized_keys` |
| Kamal: `Error response from daemon: ... denied` no ghcr | pacote privado sem permissão | garantir `permissions: packages: write` no job (já está) e que o pacote está ligado ao repo |
| App sobe mas 502 no Caddy | container não está em `127.0.0.1:3000/3001` | `docker ps`; conferir `options.publish` no `deploy*.yml` |
| `PG::ConnectionBad` nos logs da app | accessory não subiu, ou `DB_HOST` errado | `bin/kamal accessory boot db [-d staging]`; `DB_HOST` = `elcitadino-db` / `elcitadino-staging-db` |
| `db:prepare` falha com permissão | usuário do Postgres sem CREATEDB | o `POSTGRES_USER` do container é superuser; recriar o accessory se foi alterado à mão |
| Health check falha só no 1º deploy | Caddy ainda emitindo o certificado | esperar 1–2 min e *Re-run*; conferir DNS |
| staging pede senha no `/up` | matcher `@needs_auth` não exclui `/up` | conferir o bloco `not path /up /up/*` no Caddyfile |
| Deploy derruba o site por alguns segundos | esperado com `proxy: false` (sem kamal-proxy) | aceitável nesta escala; ver "near-zero-downtime" no plano |
