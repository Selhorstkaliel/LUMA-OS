#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# E1-02..E1-05: a VM instalada inicia em UEFI/Secure Boot, entrega Plasma, aceita só chave SSH,
# snapshot base-limpa é criado uma vez e a restauração descarta alterações.
# Saída: linhas PASSOU/FALHOU; capturas em $EVIDENCE (padrão docs/evidence/etapa1).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HERE/../lab.sh"
EVIDENCE="${EVIDENCE:-$HERE/../../../docs/evidence/etapa1}"
mkdir -p "$EVIDENCE"
fails=0
ok()  { echo "PASSOU: $*"; }
bad() { echo "FALHOU: $*"; fails=$((fails + 1)); }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
vm() { "$LAB" ssh "$@"; }

boot() {
	"$LAB" run >>"$EVIDENCE/vm-run.log" 2>&1 &
	"$LAB" wait-ssh 900 || { bad "SSH não respondeu após boot"; return 1; }
}
cleanup() { "$LAB" powerdown 120 >/dev/null 2>&1 || true; }
trap cleanup EXIT

# 1. Boot e ambiente
boot || exit 1
echo "info: $(vm 'grep PRETTY_NAME /etc/os-release; uname -r; dpkg-query -W -f="\${Package} \${Version} " plasma-workspace kwin-wayland' | tr '\n' ' ')"
check "Debian trixie instalado"                 vm 'grep -qx VERSION_CODENAME=trixie /etc/os-release'
check "boot em modo UEFI"                        vm 'test -d /sys/firmware/efi'
check "Secure Boot ativo (shim/grub/kernel Debian)" vm 'test "$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | awk "{print \$NF}")" = 1'
# plasmashell --version exige display (aborta via SSH); a versão vem do dpkg (ver falha3 em docs/evidence/etapa1)
check "Plasma 6 instalado"                       vm 'dpkg-query -W -f="\${Version}" plasma-workspace | grep -q "^4:6\."'
check "sessão Plasma Wayland disponível"         vm 'test -f /usr/share/wayland-sessions/plasma.desktop'
check "SDDM ativo"                               vm 'systemctl is-active --quiet sddm'
check "sem unidades systemd com falha"           vm 'test -z "$(systemctl --failed --no-legend --plain)"'
check "locale pt_BR e teclado br"                vm 'grep -q pt_BR.UTF-8 /etc/default/locale && grep -q br /etc/default/keyboard'
check "SSH recusa senha"                         bash -c "! ssh -p \${VM_SSH_PORT:-2222} -o BatchMode=yes -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null luma@127.0.0.1 true"
check "sudo exige senha (sem NOPASSWD)"          bash -c "! \"$LAB\" ssh 'sudo -n true'"
sleep 20   # SDDM terminar de desenhar
"$LAB" screenshot "$EVIDENCE/E1-02-sddm.png" >/dev/null 2>&1 && ok "captura da tela de login" || bad "captura da tela de login"
"$LAB" powerdown 180 >/dev/null || bad "desligamento ACPI"

# 2. Snapshot base-limpa (idempotente)
"$LAB" snapshot-save base-limpa
out="$("$LAB" snapshot-save base-limpa 2>&1)"; grep -q "já existe" <<<"$out" && ok "snapshot-save repetido não duplica" || bad "snapshot-save repetido: $out"
[ "$("$LAB" snapshot-list | grep -cw base-limpa)" = 1 ] && ok "exatamente um snapshot base-limpa" || bad "contagem de snapshots"
out="$("$LAB" install 2>&1)"; grep -q "instalação ignorada" <<<"$out" && ok "install repetido não reinstala" || bad "install repetido: $out"
out="$("$LAB" create 2>&1)"; grep -q "já existe" <<<"$out" && ok "create repetido não recria disco" || bad "create repetido: $out"

# 3. Restauração descarta alterações
boot || exit 1
vm 'echo alterado > ~/marcador-snapshot && sync'
check "marcador criado"                          vm 'test -f ~/marcador-snapshot'
"$LAB" powerdown 180 >/dev/null
"$LAB" snapshot-restore base-limpa
boot || exit 1
check "restauração removeu o marcador"           vm '! test -e ~/marcador-snapshot'
check "SDDM ativo após restauração"              vm 'systemctl is-active --quiet sddm'
"$LAB" powerdown 180 >/dev/null

echo "falhas: $fails"
exit $((fails > 0))
