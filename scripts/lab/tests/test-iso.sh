#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 8: a ISO live gerada por build-iso.sh dá boot em UEFI com Secure Boot ativo, chega ao desktop
# Luma, contém os pacotes Luma, aplica os padrões, firewall ativo e abre apps. Verificação pelo agente QEMU
# (a ISO não tem servidor SSH). VM separada "lab-live" com disco vazio.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa8}"
export VM_NAME=lab-live
# 2,5 GiB: o live roda em RAM; com 3 GiB o host de 7,7 GiB paginou a VM do WSL (falha1)
export VM_RAM_MB="${VM_RAM_MB:-2560}"
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
V="$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)"
ISO="${ISO:-$LAB_DIR/iso-out/luma-${V}-amd64.iso}"
[ -f "$ISO" ] || { echo "ISO ausente: $ISO (rode scripts/build/build-iso.sh)" >&2; exit 2; }
LIVE_USER=luma
ga() { "$LAB" ga "$1"; }
asu() { ga "sh /run/luma-lab/asuser.sh $LIVE_USER '$1'"; }

check "checksum da ISO confere" bash -c "cd '$(dirname "$ISO")' && sha256sum -c '$(basename "$ISO").sha256'"
echo "info: $(tr '\n' ' ' < "${ISO%.iso}.manifest" 2>/dev/null)"

"$LAB" powerdown 60 >/dev/null 2>&1 || "$LAB" kill >/dev/null 2>&1 || true
rm -rf "$VM_DIR"; "$LAB" create >/dev/null
BOOT_ISO="$ISO" "$LAB" run >>"$EV/vm-run.log" 2>&1 &
for _ in $(seq 1 120); do ga true >/dev/null 2>&1 && break; sleep 5; done
check "ISO iniciou e o agente responde" ga true
for _ in $(seq 1 60); do ga "pgrep -u $LIVE_USER -x plasmashell" >/dev/null 2>&1 && break; sleep 5; done
check "sessão Plasma do usuário live ativa" ga "pgrep -u $LIVE_USER -x plasmashell"
sleep 30
ga "mkdir -p /run/luma-lab && echo $(base64 -w0 "$HERE/../guest/asuser.sh") | base64 -d > /run/luma-lab/asuser.sh" >/dev/null
shot E8-02-desktop-live 0

check "boot em modo UEFI"          ga 'test -d /sys/firmware/efi'
check "Secure Boot ativo (shim/GRUB/kernel assinados pelo Debian)" ga 'test "$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | awk "{print \$NF}")" = 1'
check "sistema live (live-boot)"   ga 'test -d /run/live/medium'
for p in luma-theme luma-session luma-firewall luma-ajustes luma-live; do
	check "pacote $p $V presente" ga "test \"\$(dpkg-query -W -f='\${Version}' $p)\" = $V"
done
check "calamares presente (instalação: test-install.sh)" ga 'command -v calamares'
check "locale pt_BR"                 ga 'grep -q "LANG=pt_BR.UTF-8" /etc/default/locale'
check "teclado br"                   ga 'grep -q "XKBLAYOUT=\"br\"" /etc/default/keyboard'
check "LookAndFeel Luma no live"     asu 'kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage | grep -qx org.luma.desktop'
check "esquema LumaLight no live"    asu 'kreadconfig6 --file kdeglobals --group General --key ColorScheme | grep -qx LumaLight'
check "painel superior e dock"       asu 'test "$(grep -c "^plugin=org.kde.panel" .config/plasma-org.kde.plasma.desktop-appletsrc)" = 2'
st="$(ga 'LANG=C ufw status | head -n1')"
[ "$st" = "Status: active" ] && ok "firewall ativo no live (serviço de 1º boot)" || bad "firewall no live: '$st'"
asu 'setsid -f dolphin >/dev/null 2>&1; setsid -f konsole >/dev/null 2>&1' >/dev/null 2>&1; sleep 15
check "Dolphin abre"  ga "pgrep -u $LIVE_USER -x dolphin"
check "Konsole abre"  ga "pgrep -u $LIVE_USER -x konsole"
shot E8-03-apps-live 1
ga 'uname -r; cat /etc/os-release | head -2; dpkg -l | grep -c ^ii' > "$EV/E8-04-sistema-live.txt" 2>&1

ga 'systemctl poweroff' >/dev/null 2>&1 || true
for _ in $(seq 1 40); do st="$("$LAB" status 2>/dev/null)"; [[ "$st" == desligada* ]] && break; sleep 3; done
echo "falhas: $fails"
exit $((fails > 0))
