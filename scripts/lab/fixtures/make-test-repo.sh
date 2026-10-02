#!/usr/bin/env bash
# SOMENTE LABORATÓRIO. Gera repositórios APT planos para testar a verificação de assinaturas:
#   bom/           assinado pela chave A (confiável) — controle positivo
#   chave-errada/  assinado pela chave B (não confiável)
#   adulterado/    assinado pela chave A e com Packages alterado DEPOIS da assinatura
# e confiavel.gpg (chave pública A). As chaves são descartáveis, sem senha, e ficam fora do repositório.
set -euo pipefail
OUT="${1:?uso: make-test-repo.sh DIRETÓRIO_DE_SAÍDA}"
for b in gpg dpkg-deb apt-ftparchive; do command -v "$b" >/dev/null || { echo "ausente: $b (apt-get install gnupg dpkg-dev apt-utils)" >&2; exit 2; }; done
GH="$OUT/.gnupg"
rm -rf "$OUT"; mkdir -p "$OUT" "$GH"; chmod 700 "$GH"

pk="$OUT/src/luma-teste-assinatura"
mkdir -p "$pk/DEBIAN" "$pk/usr/share/doc/luma-teste-assinatura"
cat > "$pk/DEBIAN/control" <<CTRL
Package: luma-teste-assinatura
Version: 1.0
Architecture: all
Maintainer: Laboratório Luma <luma-dev@example.invalid>
Description: pacote de teste de assinatura (somente laboratório)
CTRL
echo "pacote de teste" > "$pk/usr/share/doc/luma-teste-assinatura/LEIA"
dpkg-deb --root-owner-group -b "$pk" "$OUT/luma-teste-assinatura_1.0_all.deb" >/dev/null

fpr() { gpg --homedir "$GH" --with-colons --list-keys "$1" | awk -F: '/^fpr/ {print $10; exit}'; }
for k in A B; do
	gpg --homedir "$GH" --batch --passphrase '' --quick-gen-key "Luma lab repo $k <lab-$k@example.invalid>" ed25519 sign 1d 2>/dev/null
done
A="$(fpr lab-A@example.invalid)"; B="$(fpr lab-B@example.invalid)"
gpg --homedir "$GH" --export "$A" > "$OUT/confiavel.gpg"

mkrepo() {
	local d="$OUT/$1" key="$2"
	mkdir -p "$d"; cp "$OUT"/*.deb "$d/"
	(cd "$d" && apt-ftparchive packages . > Packages && apt-ftparchive release . > Release &&
		gpg --homedir "$GH" --batch --yes -u "$key" --clearsign -o InRelease Release 2>/dev/null)
}
mkrepo bom "$A"
mkrepo chave-errada "$B"
mkrepo adulterado "$A"
printf 'Package: luma-teste-assinatura\nVersion: 9.9\nArchitecture: all\n\n' >> "$OUT/adulterado/Packages"
rm -rf "$OUT/src" "$OUT"/*.deb
echo "repositórios de teste em $OUT (chave confiável $A)"
