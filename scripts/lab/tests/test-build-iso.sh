#!/usr/bin/env bash
# E1-05 (parte): build-iso é idempotente e a ISO contém preseed renderizado sem placeholders nem segredos em claro.
set -euo pipefail
LAB="$(dirname "$0")/../lab.sh"
# shellcheck source=scripts/lab/config.sh
. "$(dirname "$0")/../config.sh"
ISO="$LAB_DIR/iso/luma-lab-install-$VM_NAME.iso"
"$LAB" build-iso
m1="$(stat -c %Y "$ISO")"
out="$("$LAB" build-iso 2>&1)"
m2="$(stat -c %Y "$ISO")"
if [ "$m1" = "$m2" ] && grep -q "nada a fazer" <<<"$out"; then echo "PASSOU: segunda execução não reconstruiu a ISO"; else echo "FALHOU: ISO reconstruída sem mudança"; exit 1; fi
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
xorriso -osirrox on -indev "$ISO" -extract /preseed/lab-desktop.cfg "$t/p.cfg" -extract /boot/grub/grub.cfg "$t/g.cfg" >/dev/null 2>&1
grep -q '@[A-Z_]*@' "$t/p.cfg" && { echo "FALHOU: placeholder restante"; exit 1; }
# shellcheck disable=SC2016  # \$6\$ literal
grep -q 'user-password-crypted password \$6\$' "$t/p.cfg" && echo "PASSOU: senha só como hash SHA-512"
grep -qF "$(cut -d' ' -f2 "$LAB_DIR/secrets/id_ed25519.pub")" "$t/p.cfg" && echo "PASSOU: chave pública injetada"
grep -qF "$(cat "$LAB_DIR/secrets/luma-password")" "$t/p.cfg" && { echo "FALHOU: senha em claro na ISO"; exit 1; }
echo "PASSOU: senha em claro ausente"
head -3 "$t/g.cfg" | grep -q 'preseed/file=/cdrom/preseed/lab-desktop.cfg' && echo "PASSOU: entrada GRUB automática é a primeira"
xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null | grep -q 'UEFI.*y' && echo "PASSOU: imagem de boot UEFI preservada"
stat -c 'permissões ISO: %a' "$ISO"
