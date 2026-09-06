#!/usr/bin/env bash
#
# provision-vps.sh — prepara a VPS para receber o Elcitadino via Kamal.
# Idempotente: pode rodar de novo sem quebrar nada.
#
# Uso (na VPS, como um usuário com sudo):
#   export KAMAL_PUBKEY="ssh-ed25519 AAAA... kamal@github-actions"
#   sudo --preserve-env=KAMAL_PUBKEY bash provision-vps.sh
#
# O que faz:
#   1. cria 2 GB de swap (se não houver)
#   2. instala Docker CE + buildx + compose (repo oficial)
#   3. cria o usuário `kamal` (grupo docker) com a KAMAL_PUBKEY em authorized_keys
#   4. cria os diretórios de dados do Postgres e de backup
#   5. instala o timer systemd de backup do Postgres
#
# NÃO mexe no Caddy nem no endless-notebook. O bloco do Caddy é aplicado à parte
# (ver deploy/Caddyfile.elcitadino).

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "rode com sudo"; exit 1; }
: "${KAMAL_PUBKEY:?defina KAMAL_PUBKEY com a chave pública do CI}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT=/opt/elcitadino

echo "==> 1/5  swap"
if ! swapon --show | grep -q .; then
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
	echo "    swap de 2G criado"
else
	echo "    já existe swap, ok"
fi

echo "==> 2/5  Docker CE"
if ! command -v docker >/dev/null 2>&1; then
	apt-get update -qq
	apt-get install -y -qq ca-certificates curl
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc
	. /etc/os-release
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
		> /etc/apt/sources.list.d/docker.list
	apt-get update -qq
	apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	systemctl enable --now docker
	echo "    docker $(docker --version)"
else
	echo "    docker já instalado: $(docker --version)"
fi

echo "==> 3/5  usuário kamal"
if ! id kamal >/dev/null 2>&1; then
	useradd --create-home --shell /bin/bash kamal
	echo "    usuário kamal criado"
fi
usermod -aG docker kamal
install -d -m 700 -o kamal -g kamal /home/kamal/.ssh
touch /home/kamal/.ssh/authorized_keys
grep -qF "$KAMAL_PUBKEY" /home/kamal/.ssh/authorized_keys || echo "$KAMAL_PUBKEY" >> /home/kamal/.ssh/authorized_keys
chmod 600 /home/kamal/.ssh/authorized_keys
chown -R kamal:kamal /home/kamal/.ssh
echo "    chave do CI instalada"

echo "==> 4/5  diretórios de dados"
# uid/gid 999 = usuário postgres dentro da imagem postgres:17-alpine
install -d -m 700 -o 999 -g 999 "$APP_ROOT/postgres/production" "$APP_ROOT/postgres/staging"
install -d -m 750 -o kamal -g kamal "$APP_ROOT/backups"
echo "    $APP_ROOT pronto"

echo "==> 5/5  timer de backup do Postgres"
install -m 0755 "$SCRIPT_DIR/pg-backup.sh" "$APP_ROOT/pg-backup.sh"
install -m 0644 "$SCRIPT_DIR/elcitadino-pg-backup.service" /etc/systemd/system/elcitadino-pg-backup.service
install -m 0644 "$SCRIPT_DIR/elcitadino-pg-backup.timer"   /etc/systemd/system/elcitadino-pg-backup.timer
systemctl daemon-reload
systemctl enable --now elcitadino-pg-backup.timer
echo "    timer ativo: $(systemctl is-active elcitadino-pg-backup.timer)"

cat <<EOF

==> pronto.

Próximos passos (fora deste script):
  - aplicar deploy/Caddyfile.elcitadino em /etc/caddy/Caddyfile e recarregar o Caddy
  - cadastrar os GitHub Secrets/Variables (ver deploy/README.md)
  - rodar o bootstrap:  Actions -> deploy -> Run workflow -> command=setup

Lembrete: o Docker publica portas ignorando o ufw. Aqui os containers publicam só em
127.0.0.1, então nada fica exposto — mas evite trocar para 0.0.0.0 nos deploy*.yml.
EOF
