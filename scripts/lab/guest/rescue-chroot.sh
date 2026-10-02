#!/bin/sh
# SOMENTE LABORATÓRIO. Executado como root na sessão live da ISO (via agente QEMU).
# Reproduz o procedimento de docs/usuario/recuperacao.md ("Recuperar pelo pendrive do Luma"): monta o
# sistema instalado sem criptografia em /dev/vda, entra por chroot, redefine a senha do usuário e confere
# a base de pacotes. uso: rescue-chroot.sh USUÁRIO — senha nova em /run/luma-lab/newpw (apagada no fim).
set -eu
m=/mnt/luma
mkdir -p "$m"
mount /dev/vda2 "$m"
mount /dev/vda1 "$m/boot/efi"
for d in dev dev/pts proc sys run; do mount --bind "/$d" "$m/$d"; done
printf '%s:%s\n' "$1" "$(cat /run/luma-lab/newpw)" | chroot "$m" chpasswd
chroot "$m" dpkg --configure -a
test -z "$(chroot "$m" dpkg --audit)"
chroot "$m" passwd -S "$1"
for d in run sys proc dev/pts dev boot/efi; do umount "$m/$d"; done
umount "$m"
rm -f /run/luma-lab/newpw
echo RESGATE-OK
