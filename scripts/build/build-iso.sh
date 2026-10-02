#!/usr/bin/env bash
# Constrói a ISO live do Luma num diretório limpo (fora de /mnt/c) e gera manifesto, checksum e log.
# Executar como root num Debian trixie (WSL do laboratório). Uso: build-iso.sh [DIR_SAÍDA]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lab/config.sh
. "$ROOT/scripts/lab/config.sh"
OUT="${1:-$LAB_DIR/iso-out}"
V="$(dpkg-parsechangelog -l "$ROOT/debian/changelog" -S Version)"
missing=()
for p in live-build debootstrap dpkg-dev; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
[ ${#missing[@]} -eq 0 ] || { echo "dependências ausentes: ${missing[*]}" >&2; exit 2; }
for p in luma-theme luma-session luma-firewall luma-ajustes luma-live; do
	[ -f "$LAB_DIR/debs/${p}_${V}_all.deb" ] || { echo "falta ${p}_${V}_all.deb; rode scripts/build/build-debs.sh" >&2; exit 2; }
done
W="$LAB_DIR/build/live"
# Diretório de trabalho sempre novo (build limpo); o cache de pacotes do live-build fica fora dele
mkdir -p "$LAB_DIR/build/live-cache" "$OUT"
rm -rf "$W"; mkdir -p "$W"
cp -r "$ROOT/live/auto" "$ROOT/live/config" "$W/"
chmod +x "$W"/auto/*
cp "$LAB_DIR"/debs/luma-{theme,session,firewall,ajustes,live}_"$V"_all.deb "$W/config/packages.chroot/"
# Arquivos sobrepostos à imagem (configuração do instalador). Em /mnt/c tudo aparece como executável:
# normalizar permissões; o logotipo e a versão entram aqui para não duplicar no repositório.
inc="$W/config/includes.chroot"
cp "$ROOT/theme/icons/luma-logo.svg" "$inc/etc/calamares/branding/luma/"
sed -i "s/@LUMA_VERSION@/$V/g" "$inc/etc/calamares/branding/luma/branding.desc"
find "$inc" -type d -exec chmod 755 {} +
find "$inc" -type f -exec chmod 644 {} +
chmod 755 "$inc"/usr/bin/*
ln -s "$LAB_DIR/build/live-cache" "$W/cache"
cd "$W"
lb config >/dev/null
start=$(date +%s)
lb build > /dev/null 2>&1 || { tail -40 build.log >&2; echo "lb build falhou; log em $W/build.log" >&2; exit 1; }
iso="$(ls "$W"/*.iso)"
name="luma-${V}-amd64"
cp "$iso" "$OUT/$name.iso"
cp build.log "$OUT/$name.build.log"
cp "$W"/*.packages "$OUT/$name.packages" 2>/dev/null || cp chroot.packages.live "$OUT/$name.packages"
(cd "$OUT" && sha256sum "$name.iso" > "$name.iso.sha256")
{
	echo "iso: $name.iso"
	echo "sha256: $(cut -d' ' -f1 "$OUT/$name.iso.sha256")"
	echo "tamanho: $(stat -c %s "$OUT/$name.iso")"
	echo "pacotes: $(wc -l < "$OUT/$name.packages")"
	echo "live-build: $(dpkg-query -W -f='${Version}' live-build)"
	echo "duração_s: $(( $(date +%s) - start ))"
	echo "data: $(date -u +%FT%TZ)"
} > "$OUT/$name.manifest"
cat "$OUT/$name.manifest"
