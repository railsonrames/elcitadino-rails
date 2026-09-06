#!/usr/bin/env bash
#
# Backup dos bancos Postgres do Elcitadino (produção + staging).
# Instalado em /opt/elcitadino/pg-backup.sh, disparado por elcitadino-pg-backup.timer.
#
# Faz pg_dump via `docker exec` no container accessory do Kamal, comprime e mantém os
# KEEP mais recentes por destino. Backup na mesma máquina NÃO cobre perda de disco —
# ver "Sugestões" no deploy/README.md para off-site.

set -euo pipefail

DEST_DIR=/opt/elcitadino/backups
KEEP=14
stamp=$(date +%Y%m%d-%H%M%S)

mkdir -p "$DEST_DIR"

dump_one() {
	local name="$1" container="$2"
	docker inspect "$container" >/dev/null 2>&1 || { echo "skip $name: container $container ausente"; return 0; }
	local out="$DEST_DIR/${name}-${stamp}.sql.gz"
	docker exec "$container" pg_dump -U elcitadino -d elcitadino_production --clean --if-exists \
		| gzip -9 > "$out"
	echo "ok: $out ($(du -h "$out" | cut -f1))"
	# retenção
	ls -1t "$DEST_DIR/${name}-"*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f
}

dump_one production elcitadino-db
dump_one staging    elcitadino-staging-db
