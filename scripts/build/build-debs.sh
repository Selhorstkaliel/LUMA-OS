#!/usr/bin/env bash
# Constrói os .deb do projeto num diretório limpo do WSL (fora de /mnt/c) e copia para $LAB_DIR/debs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lab/config.sh
. "$ROOT/scripts/lab/config.sh"
missing=()
for p in debhelper librsvg2-bin python3 lintian rsync; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
[ ${#missing[@]} -eq 0 ] || { echo "dependências de build ausentes: ${missing[*]} (apt-get install ${missing[*]})" >&2; exit 2; }
SRC="$LAB_DIR/build/src/luma-desktop"
rm -rf "$LAB_DIR/build/src"; mkdir -p "$SRC" "$LAB_DIR/debs"
# Arquivos em /mnt/c aparecem todos como executáveis no WSL; normalizar e marcar só o que deve executar.
rsync -rlt --chmod=D755,F644 --exclude .git --exclude build --exclude docs/evidence --exclude __pycache__ "$ROOT/" "$SRC/"
chmod +x "$SRC/debian/rules"
find "$SRC" -name '*.sh' -exec chmod +x {} +
(cd "$SRC" && dpkg-buildpackage -us -uc -b >"$LAB_DIR/build/dpkg-buildpackage.log" 2>&1) \
	|| { tail -30 "$LAB_DIR/build/dpkg-buildpackage.log" >&2; exit 1; }
cp "$LAB_DIR"/build/src/*.deb "$LAB_DIR/debs/"
lintian --fail-on error "$LAB_DIR"/build/src/*.changes || exit 1
ls -1 "$LAB_DIR"/debs/*.deb
