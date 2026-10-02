#!/usr/bin/env bash
# SOMENTE LABORATÓRIO. Gera luma-teste-recuperacao_1.0_all.deb: na PRIMEIRA configuração o postinst
# bloqueia, deixando o pacote em "half-configured" para o teste cortar a energia de forma determinística
# (simula falha durante a configuração de um pacote). Na recuperação (dpkg --configure -a) termina normalmente.
set -euo pipefail
OUT="${1:?uso: make-recovery-pkg.sh DIRETÓRIO_DE_SAÍDA}"
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
mkdir -p "$d/DEBIAN" "$d/usr/share/doc/luma-teste-recuperacao" "$OUT"
cat > "$d/DEBIAN/control" <<CTRL
Package: luma-teste-recuperacao
Version: 1.0
Architecture: all
Maintainer: Laboratório Luma <luma-dev@example.invalid>
Description: pacote de teste de recuperação (somente laboratório)
CTRL
cat > "$d/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
M=/var/lib/luma-teste-recuperacao/primeira-configuracao
if [ "$1" = configure ] && [ ! -e "$M" ]; then
	mkdir -p "$(dirname "$M")"
	touch "$M"
	sleep 900
fi
exit 0
POST
chmod 755 "$d/DEBIAN/postinst"
echo "somente laboratório" > "$d/usr/share/doc/luma-teste-recuperacao/LEIA"
dpkg-deb --root-owner-group -b "$d" "$OUT/luma-teste-recuperacao_1.0_all.deb" >/dev/null
echo "$OUT/luma-teste-recuperacao_1.0_all.deb"
