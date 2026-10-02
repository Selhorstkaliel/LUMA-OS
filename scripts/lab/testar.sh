#!/usr/bin/env bash
# Abre o Luma numa janela para testar à mão (VM "lab-teste", disco VIRTUAL de 32 GiB; nada do PC é alterado).
# No Windows (PowerShell):  wsl -d Debian -u root /mnt/c/.../scripts/lab/testar.sh [iso|disco|novo]
#   iso    (padrão) liga pela ISO mais recente: sessão live, com o instalador
#   disco  liga pelo disco virtual, depois de instalar (fechar a janela da ISO antes)
#   novo   apaga o disco virtual de teste
# A janela prende o teclado/mouse ao clicar; Ctrl+Alt+G solta. Fechar a janela desliga a VM na hora.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export VM_NAME=lab-teste VM_DISK_SIZE=32G VM_RAM_MB="${VM_RAM_MB:-2816}" VM_GUI=1
# shellcheck source=scripts/lab/config.sh
. "$HERE/config.sh"
LAB="$HERE/lab.sh"
case "${1:-iso}" in
	iso)
		V="$(dpkg-parsechangelog -l "$HERE/../../debian/changelog" -S Version)"
		ISO="${ISO:-$LAB_DIR/iso-out/luma-${V}-amd64.iso}"
		[ -f "$ISO" ] || { echo "ISO ausente: $ISO (rode scripts/build/build-iso.sh)" >&2; exit 2; }
		"$LAB" create
		BOOT_ISO="$ISO" exec "$LAB" run ;;
	disco)
		[ -f "$VM_DIR/disk.qcow2" ] || { echo "ainda não há disco de teste: rode 'testar.sh iso' e instale" >&2; exit 2; }
		exec "$LAB" run ;;
	novo)
		"$LAB" kill 2>/dev/null || true
		rm -rf "$VM_DIR"; echo "disco de teste apagado" ;;
	*) echo "uso: testar.sh [iso|disco|novo]" >&2; exit 64 ;;
esac
