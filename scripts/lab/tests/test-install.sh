#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 9: instalar o Luma pela ISO live num disco VIRTUAL vazio (VM "lab-install"), como um usuário faria:
# instalador dirigido por mouse/teclado. Cobre cancelamento, queda de energia no meio da cópia, reinstalação
# sobre o disco sujo SEM internet, boot sem a ISO com Secure Boot, login, atualização e recuperação pela ISO.
# ENCRYPT=1 repete a instalação com o disco cifrado (LUKS) e valida o pedido de senha no boot.
# Nunca toca em disco físico: o único destino é o qcow2 da VM.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa9}"
export VM_NAME=lab-install VM_DISK_SIZE=32G
# 2,75 GiB: o live mais o instalador ocupam ~2,3 GiB; o host de 7,7 GiB não comporta mais (etapa 8, falha1)
export VM_RAM_MB="${VM_RAM_MB:-2816}"
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
# shellcheck source=scripts/lab/tests/install-lib.sh
. "$HERE/install-lib.sh"
cleanup() { "$LAB" kill >/dev/null 2>&1 || true; rm -rf "$T"; }
trap cleanup EXIT
V="$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)"
ISO="${ISO:-$LAB_DIR/iso-out/luma-${V}-amd64.iso}"
[ -f "$ISO" ] || { echo "ISO ausente: $ISO (rode scripts/build/build-iso.sh)" >&2; exit 2; }
ENCRYPT="${ENCRYPT:-0}"
LIVE_USER=luma
FULLNAME="Ana Teste"; NEWUSER=anat     # login sugerido pelo instalador para esse nome
P="e9"; [ "$ENCRYPT" = 1 ] && P="e9-luks"
# Senhas aleatórias por execução, digitáveis pelo teclado virtual; nunca gravadas no repositório
newpw() { head -c 48 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 14; }
newpw > "$T/pw"; newpw > "$T/pw2"
luma() { LIVE_USER=luma asu "$1"; }
inst() { LIVE_USER="$NEWUSER" asu "$1"; }
# Verificação como root pelo agente QEMU (a ISO e o sistema instalado não têm servidor SSH)
check_ga() { local d="$1"; shift; if ga "$1" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# Atalho do instalador no lugar certo e nenhuma pasta errada; conferido em toda inicialização da ISO
# (a falha de ordem de início da etapa 9 aparecia só em parte das inicializações)
check_shortcut() {
	check "atalho \"Instalar o Luma\" na área de trabalho ($1)" luma 'f="$(xdg-user-dir DESKTOP)/calamares-install-debian.desktop"; test "$(xdg-user-dir DESKTOP)" = "$HOME/Área de trabalho" && grep -q "Instalar o Luma" "$f"'
	check "sem pastas erradas na pasta pessoal ($1)" luma '! test -e "$HOME/Área" && ! test -e "$HOME/de" && ! test -e "$HOME/trabalho" && ! test -e "$HOME/Desktop"'
}
sb_on='test "$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | awk "{print \$NF}")" = 1'

check "checksum da ISO confere" bash -c "cd '$(dirname "$ISO")' && sha256sum -c '$(basename "$ISO").sha256'"
"$LAB" kill >/dev/null 2>&1 || true
rm -rf "$VM_DIR"; "$LAB" create >/dev/null

if [ "$ENCRYPT" != 1 ]; then
	# ---------- 1. Sessão live: configuração do instalador ----------
	boot_live
	check_ga "ISO inicia com Secure Boot ativo"          "$sb_on"
	check_ga "instalador com a marca Luma"               'grep -qx "branding: luma" /etc/calamares/settings.conf && test -f /etc/calamares/branding/luma/luma-logo.svg'
	check_ga "versão $V na marca do instalador"          "grep -q 'versionedName: *Luma $V' /etc/calamares/branding/luma/branding.desc"
	check_ga "usuários novos fora do grupo audio"        '! grep -q "^ *- audio" /etc/calamares/modules/users.conf'
	check_ga "fuso inicial America/Sao_Paulo, sem GeoIP" 'grep -q "^zone: *\"Sao_Paulo\"" /etc/calamares/modules/locale.conf && ! grep -v "^ *#" /etc/calamares/modules/locale.conf | grep -qi geoip'
	check_ga "carregador de boot já na imagem (instalação sem internet)" 'dpkg -s grub-efi-amd64-signed shim-signed cryptsetup-initramfs'
	check_ga "pacote luma-live $V presente"              "test \"\$(dpkg-query -W -f='\${Version}' luma-live)\" = $V"
	check_shortcut "1ª inicialização"
	check "sessão live sem bloqueio automático de tela"  luma 'test "$(kreadconfig6 --file kscreenlockerrc --group Daemon --key Autolock)" = false'
	shot "$P-01-live" 0

	# ---------- 2. Cancelar no resumo não altera o disco ----------
	before="$(disk_state)"
	if open_installer; then ok "instalador abre pela sessão (sem pedir senha)"; else bad "instalador não abriu"; exit 1; fi
	SHOT_PREFIX="$P-02-cancelar" inst_pages_to_summary "$FULLNAME" "$T/pw" || { bad "instalador não chegou ao resumo (cancelamento)"; exit 1; }
	if SHOT_PREFIX="$P-02-cancelar" inst_cancel_confirm; then ok "cancelar encerra o instalador"; else bad "cancelar não encerrou o instalador"; exit 1; fi
	after="$(disk_state)"
	[ "$after" = "$before" ] && [ "$after" = "vda disk ;" ] && ok "disco intacto após cancelar ($after)" || bad "disco mudou após cancelar: '$before' → '$after'"

	# ---------- 3. Queda de energia no meio da cópia ----------
	open_installer || { bad "instalador não reabriu"; exit 1; }
	SHOT_PREFIX="$P-03-corte" inst_pages_to_summary "$FULLNAME" "$T/pw" || { bad "instalador não chegou ao resumo (corte de energia)"; exit 1; }
	if inst_start; then ok "instalação iniciada (destino montado)"; else bad "instalação não iniciou"; shot "$P-03-falha" 0; exit 1; fi
	sleep 75
	check_ga "cópia em andamento antes do corte" 'pgrep -x rsync'
	shot "$P-03-antes-do-corte" 0
	"$LAB" kill >/dev/null 2>&1                # corte de energia
	"$LAB" run >>"$EV/vm-run.log" 2>&1 &       # sem a ISO: o disco pela metade não pode parecer um sistema válido
	if wait_agent 12; then bad "disco pela metade iniciou um sistema"; else ok "disco pela metade não inicia (sem ISO)"; fi
	shot "$P-03-sem-boot" 0
	"$LAB" kill >/dev/null 2>&1
fi

# ---------- 4. Instalação completa (sobre o disco sujo no modo normal), sem internet ----------
boot_live
check_shortcut "inicialização da instalação"
echo "info: disco antes da instalação: $(disk_state)"
"$LAB" link off >/dev/null 2>&1
ga 'for i in 1 2 3 4 5 6; do nmcli -t -f CONNECTIVITY general status | grep -qx full || exit 0; sleep 5; done; exit 1' >/dev/null 2>&1 \
	&& ok "rede desligada durante a instalação" || bad "rede continuou ativa"
open_installer || { bad "instalador não abriu"; exit 1; }
SHOT_PREFIX="$P-04" inst_pages_to_summary "$FULLNAME" "$T/pw" || { bad "instalador não chegou ao resumo"; shot "$P-04-falha" 0; exit 1; }
t0=$SECONDS
if inst_start; then ok "instalação iniciada"; else bad "instalação não iniciou"; shot "$P-04-falha" 0; exit 1; fi
sleep 30; shot "$P-04-instalando" 0
if inst_wait_done 45; then ok "instalação terminou em $(( (SECONDS - t0) / 60 )) min"; else bad "instalação não terminou em 45 min"; fi
sleep 6; shot "$P-04-concluido" 0
# O log do instalador registra o hash da senha da conta (usermod -p): fica mascarado na evidência
ga 'cat /root/.cache/calamares/session.log' 2>/dev/null |
	sed -E 's/"usermod" "-p" "[^!"][^"]*"/"usermod" "-p" "HASH-REMOVIDO"/' > "$EV/$P-04-calamares-session.log"
grep -q 'completion: succeeded' "$EV/$P-04-calamares-session.log" && ok "instalador relata sucesso" || bad "instalador não relatou sucesso (ver $P-04-calamares-session.log)"
luma 'qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive' 2>/dev/null | grep -qx false \
	&& ok "sessão live não bloqueou a tela durante a instalação" || bad "sessão live bloqueou a tela"
vm_poweroff

# ---------- 5. Primeiro boot pelo disco, sem ISO ----------
"$LAB" link on >/dev/null 2>&1 || true        # (VM desligada: o cabo volta ligado no próximo boot)
if SHOT_PREFIX="$P-05" boot_disk "$T/pw" 60; then ok "sistema instalado inicia sem a ISO"; else bad "sistema instalado não iniciou"; shot "$P-05-falha" 0; exit 1; fi
sleep 25; shot "$P-05-tela-de-login" 0
check_ga "não é sessão live"                         '! test -d /run/live/medium'
check_ga "Secure Boot ativo no sistema instalado"    "$sb_on"
check_ga "usuário criado, administrador (sudo)"      "id -nG $NEWUSER | tr ' ' '\n' | grep -qx sudo"
check_ga "usuário fora do grupo audio"               "! id -nG $NEWUSER | tr ' ' '\n' | grep -qx audio"
check_ga "conta root sem senha (bloqueada)"          'test "$(passwd -S root | cut -d" " -f2)" = L'
check_ga "senha do usuário definida"                 "test \"\$(passwd -S $NEWUSER | cut -d' ' -f2)\" = P"
check_ga "sem login automático"                      '! grep -rqs "^User=" /etc/sddm.conf /etc/sddm.conf.d'
check_ga "fuso America/Sao_Paulo"                    'test "$(timedatectl show -p Timezone --value)" = America/Sao_Paulo'
check_ga "idioma e formatos pt_BR"                   'grep -qx "LANG=pt_BR.UTF-8" /etc/default/locale && ! grep -q en_US /etc/default/locale'
check_ga "teclado br"                                'grep -q "XKBLAYOUT=\"br\"" /etc/default/keyboard'
check_ga "pacotes live e instalador removidos"       '! dpkg -l | grep -E "^ii +(live-boot|live-config|live-tools|luma-live|calamares)"'
check_ga "sem restos do instalador"                  '! test -e /etc/calamares && ! ls /usr/share/applications | grep -qi calamares'
check_ga "log do instalador (com hash de senha) não fica no sistema instalado" '! grep -rIqsF "\$y\$j9T\$" /var/log /root /home/*/.cache'
check_ga "nenhuma fonte APT trusted=yes nem da mídia" '! grep -rqs -E "trusted=yes|file:/run/live" /etc/apt/sources.list /etc/apt/sources.list.d'
check_ga "firewall ativo (deny incoming)"            'LANG=C ufw status verbose | grep -q "deny (incoming)"'
check_ga "nenhum serviço com falha"                  'test -z "$(systemctl --failed --no-legend)"'
check_ga "caminho de boot reserva completo (EFI/BOOT)" 'test -f /boot/efi/EFI/BOOT/BOOTX64.EFI && test -f /boot/efi/EFI/BOOT/grubx64.efi'
check_ga "swap ativa"                                'test -n "$(swapon --show --noheadings)"'
for p in luma-theme luma-session luma-firewall luma-ajustes; do
	check_ga "pacote $p $V instalado" "test \"\$(dpkg-query -W -f='\${Version}' $p)\" = $V"
done
if [ "$ENCRYPT" = 1 ]; then
	check_ga "raiz em volume cifrado (LUKS)"  'lsblk -n -o TYPE "$(findmnt -n -o SOURCE /)" | grep -qx crypt'
	check_ga "swap em volume cifrado"         'lsblk -n -o TYPE "$(swapon --show=NAME --noheadings | head -n1)" | grep -qx crypt'
	check_ga "nenhuma partição ext4/swap em claro" '! lsblk -n -o TYPE,FSTYPE /dev/vda | grep -E "^part +(ext4|swap)"'
fi
ga "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vda; cat /proc/cmdline; id $NEWUSER; LANG=C ufw status verbose | head -4; ls /boot/efi/EFI/*; cat /etc/apt/sources.list" > "$EV/$P-05-sistema-instalado.txt" 2>&1

# ---------- 6. Login pela tela ----------
if sddm_login "$NEWUSER" "$T/pw"; then ok "login com a senha escolhida no instalador"; else bad "login com a senha escolhida no instalador"; fi
sleep 40; shot "$P-06-desktop" 0
push_guest "$HERE/../guest/asuser.sh"
check "aparência Luma na conta nova"   inst 'kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage | grep -qx org.luma.desktop'
check "áudio disponível pela sessão (sem grupo audio)" inst 'wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "^Volume:"'

# ---------- 7. Atualização ----------
for _ in $(seq 1 12); do ga 'nmcli -t -f CONNECTIVITY general status | grep -qx full' >/dev/null 2>&1 && break; sleep 5; done
check_ga "rede de volta"                             'nmcli -t -f CONNECTIVITY general status | grep -qx full'
ga 'LANG=C apt-get update 2>&1' > "$EV/$P-07-apt-update.log"; rc=$?
[ $rc -eq 0 ] && ! grep -q -E '^(W|E):' "$EV/$P-07-apt-update.log" && ok "apt-get update sem erros nem avisos (fontes assinadas)" || bad "apt-get update (rc=$rc; ver $P-07-apt-update.log)"
ga 'LANG=C DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade 2>&1' > "$EV/$P-07-apt-upgrade.log" && ok "atualização do sistema concluída ($(grep -E '^[0-9]+ upgraded' "$EV/$P-07-apt-upgrade.log"))" || bad "atualização falhou"
ga 'LANG=C DEBIAN_FRONTEND=noninteractive apt-get -y install hello 2>&1 && hello' > "$EV/$P-07-apt-install.log" && ok "instalar pacote do repositório assinado" || bad "instalar pacote"
check_ga "base de pacotes íntegra após atualizar"    'test -z "$(dpkg --audit)" && apt-get check'

if [ "$ENCRYPT" != 1 ]; then
	# ---------- 8. Modo de recuperação do GRUB (root bloqueado) ----------
	ga 'systemd-run --on-active=1 systemctl reboot' >/dev/null 2>&1; sleep 4
	if wait_grub; then
		"$LAB" key down; sleep 1; "$LAB" key ret; sleep 1; "$LAB" key down; sleep 1
		shot "$P-08-grub-recovery" 0
		"$LAB" key ret; sleep 45; shot "$P-08-recovery-console" 0
		# Com root bloqueado o sulogin recusa: não pode haver shell no console
		check_ga "modo de recuperação ativo (rescue.target)" 'systemctl is-active rescue.target'
		check_ga "modo de recuperação não dá shell de root sem senha" '! ps -eo tty=,comm= | grep -E "^(tty1|console) +(bash|sh|dash)$"'
		# Enter segue para o login normal. O agente QEMU não volta depois dessa transição (serviço ligado ao
		# dispositivo, parado na troca de alvo), por isso a conferência é pela tela.
		"$LAB" key ret; sleep 45; shot "$P-08-apos-enter" 0
		# Console de texto é preto nesses pontos; a tela de login tem o fundo azulado
		graphical=1
		for xy in "300 900" "1600 900" "960 300"; do
			# shellcheck disable=SC2086  # xy são dois argumentos
			read -r r g b < <("$LAB" pixel $xy) || r=0
			[ $(( ${r:-0} + ${g:-0} + ${b:-0} )) -gt 60 ] || graphical=0
		done
		[ "$graphical" = 1 ] && ok "Enter no modo de recuperação segue para a tela de login gráfica" 			|| bad "sistema não voltou à tela gráfica após o modo de recuperação"
	else
		bad "menu do GRUB não apareceu"
	fi
	vm_poweroff

	# ---------- 9. Recuperação pela ISO: senha esquecida + consistência dos pacotes ----------
	boot_live
	check_shortcut "inicialização do resgate"
	check_ga "ISO inicia mesmo com sistema no disco" 'test -d /run/live/medium'
	push_guest "$HERE/../guest/rescue-chroot.sh"; push_guest "$T/pw2"
	ga "mv /run/luma-lab/pw2 /run/luma-lab/newpw; sh /run/luma-lab/rescue-chroot.sh $NEWUSER" > "$EV/$P-09-resgate.log" 2>&1
	grep -qx RESGATE-OK "$EV/$P-09-resgate.log" && ok "procedimento de resgate (docs/usuario/recuperacao.md) concluído" || bad "resgate falhou (ver $P-09-resgate.log)"
	vm_poweroff
	# A VM perde a entrada de boot da NVRAM ao iniciar pela mídia: este boot depende do caminho reserva EFI/BOOT
	if boot_disk "$T/pw" 36; then ok "disco inicia pelo caminho reserva após boot pela mídia"; else bad "disco não iniciou após o resgate"; shot "$P-09-falha" 0; exit 1; fi
	sleep 25
	type_text "$(cat "$T/pw")"; "$LAB" key ret; sleep 15
	check_ga "senha antiga recusada" "! pgrep -u $NEWUSER -x plasmashell"
	if sddm_login "$NEWUSER" "$T/pw2"; then ok "login com a senha redefinida pelo resgate"; else bad "login com a senha redefinida pelo resgate"; fi
	sleep 20; shot "$P-09-desktop-apos-resgate" 0
	check_ga "Secure Boot ativo após o resgate" "$sb_on"
fi

vm_poweroff
echo "falhas: $fails"
exit $((fails > 0))
