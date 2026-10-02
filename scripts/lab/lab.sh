#!/usr/bin/env bash
# Laboratório Luma: VM UEFI (QEMU/KVM + OVMF) para testar Debian trixie + Plasma.
# Executar dentro do WSL Debian (ou qualquer Debian trixie com /dev/kvm), como root:
#   wsl -d Debian -u root -- /mnt/c/.../scripts/lab/lab.sh <comando>
# Todos os comandos são idempotentes: repetir não duplica discos, chaves nem snapshots.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lab/config.sh
. "$SCRIPT_DIR/config.sh"

ISO_DIR="$LAB_DIR/iso"
SECRETS_DIR="$LAB_DIR/secrets"
SSH_KEY="$SECRETS_DIR/id_ed25519"
KNOWN_HOSTS="$SECRETS_DIR/known_hosts"
INSTALL_ISO="$ISO_DIR/luma-lab-install-${VM_NAME}.iso"
DISK="$VM_DIR/disk.qcow2"
VARS="$VM_DIR/OVMF_VARS.fd"
PIDFILE="$VM_DIR/qemu.pid"
QMP_SOCK="$VM_DIR/qmp.sock"
QGA_SOCK="$VM_DIR/qga.sock"
SNAP_DIR="$VM_DIR/snapshots"

log() { printf '[lab] %s\n' "$*" >&2; }
die() { printf '[lab] ERRO: %s\n' "$1" >&2; exit "${2:-1}"; }

ovmf_code() { if [ "$VM_SECUREBOOT" = 1 ]; then echo "$OVMF_DIR/OVMF_CODE_4M.secboot.fd"; else echo "$OVMF_DIR/OVMF_CODE_4M.fd"; fi; }
ovmf_vars_template() { if [ "$VM_SECUREBOOT" = 1 ]; then echo "$OVMF_DIR/OVMF_VARS_4M.ms.fd"; else echo "$OVMF_DIR/OVMF_VARS_4M.fd"; fi; }

cmd_check() {
	local missing=() b
	for b in "$QEMU" "$QEMU_IMG" "$XORRISO" gpg curl sha256sum mkpasswd ssh ssh-keygen socat; do
		command -v "$b" >/dev/null 2>&1 || missing+=("$b")
	done
	[ ${#missing[@]} -eq 0 ] || die "dependências ausentes: ${missing[*]}. Instale com: apt-get install qemu-system-x86 qemu-utils ovmf xorriso gnupg curl whois openssh-client socat" 2
	if [ ! -r "$(ovmf_code)" ] || [ ! -r "$(ovmf_vars_template)" ]; then
		die "firmware OVMF não encontrado em $OVMF_DIR (pacote ovmf)" 2
	fi
	[ -w /dev/kvm ] || die "/dev/kvm indisponível ou sem permissão; sem aceleração a VM é inviável" 2
	log "dependências OK ($("$QEMU" --version | head -n1))"
}

cmd_fetch_iso() {
	cmd_check
	mkdir -p "$ISO_DIR"
	local base="" url gnupg
	for url in $DEBIAN_CD_URLS; do
		if curl -fsSL "$url/SHA256SUMS" -o "$ISO_DIR/SHA256SUMS.tmp" && grep -q " $DEBIAN_ISO\$" "$ISO_DIR/SHA256SUMS.tmp"; then
			base="$url"; break
		fi
	done
	[ -n "$base" ] || die "$DEBIAN_ISO não encontrado em: $DEBIAN_CD_URLS"
	mv "$ISO_DIR/SHA256SUMS.tmp" "$ISO_DIR/SHA256SUMS"
	curl -fsSL "$base/SHA256SUMS.sign" -o "$ISO_DIR/SHA256SUMS.sign"

	gnupg="$WORK/gnupg"; mkdir -m 0700 "$gnupg"
	curl -fsSL "$DEBIAN_CD_KEY_URL" | gpg --homedir "$gnupg" --quiet --import
	gpg --homedir "$gnupg" --with-colons --fingerprint | grep -q "^fpr:::::::::$DEBIAN_CD_KEY_FPR:" \
		|| die "chave baixada não tem a impressão digital fixada $DEBIAN_CD_KEY_FPR"
	gpg --homedir "$gnupg" --status-fd 1 --verify "$ISO_DIR/SHA256SUMS.sign" "$ISO_DIR/SHA256SUMS" 2>/dev/null \
		| grep -q "^\[GNUPG:\] VALIDSIG $DEBIAN_CD_KEY_FPR " || die "assinatura de SHA256SUMS inválida"
	log "SHA256SUMS assinado por $DEBIAN_CD_KEY_FPR"

	if [ -f "$ISO_DIR/$DEBIAN_ISO" ] && (cd "$ISO_DIR" && grep " $DEBIAN_ISO\$" SHA256SUMS | sha256sum -c --quiet -); then
		log "$DEBIAN_ISO já presente e íntegra; download ignorado"
		return
	fi
	log "baixando $base/$DEBIAN_ISO"
	curl -fsSL --retry 3 -C - "$base/$DEBIAN_ISO" -o "$ISO_DIR/$DEBIAN_ISO.part"
	mv "$ISO_DIR/$DEBIAN_ISO.part" "$ISO_DIR/$DEBIAN_ISO"
	(cd "$ISO_DIR" && grep " $DEBIAN_ISO\$" SHA256SUMS | sha256sum -c -) || { rm -f "$ISO_DIR/$DEBIAN_ISO"; die "checksum da ISO não confere; arquivo removido"; }
}

cmd_secrets() {
	mkdir -p "$SECRETS_DIR"; chmod 0700 "$SECRETS_DIR"
	if [ ! -f "$SSH_KEY" ]; then
		ssh-keygen -q -t ed25519 -N '' -C "luma-lab@$VM_NAME" -f "$SSH_KEY"
		log "chave SSH criada"
	fi
	if [ ! -f "$SECRETS_DIR/luma-password" ]; then
		(umask 077; head -c 18 /dev/urandom | base64 | tr -d '\n' > "$SECRETS_DIR/luma-password")
		log "senha aleatória do usuário luma criada em $SECRETS_DIR/luma-password"
	fi
	if [ ! -f "$SECRETS_DIR/luma-password.hash" ] || [ "$SECRETS_DIR/luma-password" -nt "$SECRETS_DIR/luma-password.hash" ]; then
		(umask 077; mkpasswd -m sha-512 --stdin < "$SECRETS_DIR/luma-password" > "$SECRETS_DIR/luma-password.hash")
	fi
}

cmd_build_iso() {
	cmd_fetch_iso
	cmd_secrets
	local work stamp_new
	work="$WORK/build-iso"; mkdir -p "$work"
	sed -e "s|@PASSWORD_HASH@|$(cat "$SECRETS_DIR/luma-password.hash")|" \
		-e "s|@SSH_PUBKEY@|$(cat "$SSH_KEY.pub")|" \
		"$SCRIPT_DIR/preseed/lab-desktop.cfg.in" > "$work/preseed.cfg"
	grep -q '@[A-Z_]*@' "$work/preseed.cfg" && die "placeholder não substituído no preseed"

	# Carimbo independe do diretório temporário: ISO base + preseed renderizado + este script
	stamp_new="$(grep " $DEBIAN_ISO\$" "$ISO_DIR/SHA256SUMS"; sha256sum < "$work/preseed.cfg"; sha256sum < "$SCRIPT_DIR/lab.sh")"
	stamp_new="$(printf '%s' "$stamp_new" | sha256sum | cut -d' ' -f1)"
	if [ -f "$INSTALL_ISO" ] && [ "$(cat "$INSTALL_ISO.stamp" 2>/dev/null)" = "$stamp_new" ]; then
		log "ISO de instalação atualizada; nada a fazer"
		return
	fi

	"$XORRISO" -osirrox on -indev "$ISO_DIR/$DEBIAN_ISO" -extract /boot/grub/grub.cfg "$work/grub.orig.cfg" 2>/dev/null
	"$XORRISO" -indev "$ISO_DIR/$DEBIAN_ISO" -find /install.amd/vmlinuz 2>/dev/null | grep -q vmlinuz \
		|| die "kernel do instalador /install.amd/vmlinuz não encontrado na ISO"
	{
		echo 'menuentry "Luma lab: instalação automática (apaga /dev/vda)" {'
		echo '    linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed/lab-desktop.cfg locale=pt_BR.UTF-8 keymap=br hostname=lab-desktop domain=lan --- quiet'
		echo '    initrd /install.amd/initrd.gz'
		echo '}'
		cat "$work/grub.orig.cfg"
		echo 'set default=0'
		echo 'set timeout=3'
	} > "$work/grub.cfg"

	rm -f "$INSTALL_ISO"
	"$XORRISO" -indev "$ISO_DIR/$DEBIAN_ISO" -outdev "$INSTALL_ISO" \
		-map "$work/preseed.cfg" /preseed/lab-desktop.cfg \
		-map "$work/grub.cfg" /boot/grub/grub.cfg \
		-boot_image any replay 2>"$work/xorriso.log" || { cat "$work/xorriso.log" >&2; die "xorriso falhou"; }
	chmod 0600 "$INSTALL_ISO"   # contém hash de senha
	echo "$stamp_new" > "$INSTALL_ISO.stamp"
	log "ISO de instalação: $INSTALL_ISO"
}

cmd_create() {
	cmd_check
	mkdir -p "$VM_DIR" "$SNAP_DIR"
	if [ -f "$DISK" ]; then
		log "disco $DISK já existe; nada criado"
	else
		"$QEMU_IMG" create -q -f qcow2 "$DISK" "$VM_DISK_SIZE"
		log "disco criado: $DISK ($VM_DISK_SIZE, alocação dinâmica)"
	fi
	if [ ! -f "$VARS" ]; then
		cp "$(ovmf_vars_template)" "$VARS"
		log "variáveis UEFI criadas a partir de $(ovmf_vars_template)"
	fi
}

is_running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

qemu_args() {
	local machine="q35,accel=kvm"
	local -a a
	[ "$VM_SECUREBOOT" = 1 ] && machine="$machine,smm=on"
	# A ordem dos dispositivos define os endereços PCI (e o nome da interface, ex.: enp0s1) que o sistema
	# instalado em base-limpa conhece. Dispositivos novos entram sempre no FIM da lista.
	a=(-name "$VM_NAME" -machine "$machine" -cpu host -smp "$VM_CPUS" -m "$VM_RAM_MB"
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=$(ovmf_code)"
		-drive "if=pflash,format=raw,unit=1,file=$VARS"
		-drive "if=virtio,file=$DISK,format=qcow2,discard=unmap")
	# Sem placa de rede não há SSH: com VM_NET=0 a verificação é feita pelo agente QEMU (lab.sh ga)
	# -nic none: sem isso o QEMU cria uma placa padrão (e1000e no q35) quando não há -netdev
	if [ "$VM_NET" = 1 ]; then
		a+=(-netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$VM_SSH_PORT-:22,hostfwd=tcp:127.0.0.1:$VM_HTTP_PORT-:8080" -device "virtio-net-pci,netdev=n0")
	else
		a+=(-nic none)
	fi
	a+=(-device "virtio-vga,xres=$VM_XRES,yres=$VM_YRES"
		-device qemu-xhci -device usb-tablet -device usb-kbd)
	[ "$VM_AUDIO" = 1 ] && a+=(-audiodev "none,id=snd0" -device intel-hda -device "hda-duplex,audiodev=snd0")
	# VM_GUI=1: janela do QEMU na área de trabalho (no Windows, via WSLg) para uso manual; os testes usam "none"
	local display=none
	[ "${VM_GUI:-0}" = 1 ] && display="gtk,zoom-to-fit=on"
	a+=(-device virtio-rng-pci
		-display "$display" -vnc "127.0.0.1:$VM_VNC_DISPLAY"
		-qmp "unix:$QMP_SOCK,server=on,wait=off"
		-pidfile "$PIDFILE"
		-device virtio-serial -chardev "socket,path=$QGA_SOCK,server=on,wait=off,id=qga0"
		-device "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0")
	[ "$VM_SECUREBOOT" = 1 ] && a+=(-global "driver=cfi.pflash01,property=secure,value=on")
	# BOOT_ISO: mídia óptica no controlador AHCI embutido (não altera endereços PCI)
	# cache=none: lê a ISO sem encher o cache de páginas do WSL (falha1 da etapa 8: host sem memória)
	# bootindex=0: a mídia inicia antes do disco mesmo com sistema já instalado (equivale ao menu de boot do PC)
	[ -n "${BOOT_ISO:-}" ] && a+=(-drive "file=$BOOT_ISO,if=none,id=cd0,media=cdrom,readonly=on,cache=none"
		-device "ide-cd,drive=cd0,bootindex=0")
	printf '%s\0' "${a[@]}"
}

run_qemu() {
	is_running && die "VM $VM_NAME já está em execução (pid $(cat "$PIDFILE"))"
	local -a args
	mapfile -d '' args < <(qemu_args)
	"$QEMU" "${args[@]}" "$@"
}

cmd_install() {
	if [ -f "$DISK" ] && "$QEMU_IMG" snapshot -l -U "$DISK" | grep -qw base-limpa; then
		log "snapshot base-limpa já existe; instalação ignorada (apague $VM_DIR para refazer)"
		return
	fi
	cmd_build_iso
	cmd_create
	rm -f "$KNOWN_HOSTS"
	log "instalando (sem interação; pode levar 30–90 min). Serial: $VM_DIR/install-serial.log; tela: VNC 127.0.0.1:$((5900 + VM_VNC_DISPLAY))"
	is_running && die "VM $VM_NAME já está em execução"
	local -a args
	mapfile -d '' args < <(qemu_args)
	timeout "${INSTALL_TIMEOUT:-7200}" "$QEMU" "${args[@]}" \
		-cdrom "$INSTALL_ISO" -no-reboot -serial "file:$VM_DIR/install-serial.log" \
		|| die "instalação não terminou (timeout ou falha do QEMU); veja $VM_DIR/install-serial.log"
	log "instalador desligou a VM"
}

cmd_run() {
	[ -f "$DISK" ] || die "disco inexistente; execute 'install' primeiro"
	log "VM iniciando; SSH 127.0.0.1:$VM_SSH_PORT; VNC 127.0.0.1:$((5900 + VM_VNC_DISPLAY)). Processo em primeiro plano."
	run_qemu -serial "file:$VM_DIR/serial.log"
}

ssh_vm() {
	ssh -i "$SSH_KEY" -p "$VM_SSH_PORT" -o BatchMode=yes -o ConnectTimeout=5 \
		-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KNOWN_HOSTS" \
		-o LogLevel=ERROR "${VM_USER:-luma}@127.0.0.1" "$@"
}

cmd_wait_ssh() {
	local deadline=$((SECONDS + ${1:-600})) grace=$((SECONDS + 30))
	until ssh_vm true 2>/dev/null; do
		# QEMU pode ainda não ter gravado o pidfile logo após 'run &'
		is_running || [ $SECONDS -lt $grace ] || die "VM não está em execução"
		[ $SECONDS -lt $deadline ] || die "SSH não respondeu no prazo"
		sleep 5
	done
	log "SSH disponível"
}

qmp() {
	is_running || die "VM não está em execução"
	printf '{"execute":"qmp_capabilities"}\n%s\n' "$1" | socat -t 3 - "UNIX-CONNECT:$QMP_SOCK"
}

cmd_screenshot() {
	local out="${1:?uso: screenshot ARQUIVO.png}" tmp="$VM_DIR/screendump.png"
	rm -f "$tmp"
	qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$tmp\",\"format\":\"png\"}}" >/dev/null
	for _ in 1 2 3 4 5; do [ -s "$tmp" ] && break; sleep 1; done
	[ -s "$tmp" ] || die "screendump não gerou arquivo"
	cp "$tmp" "$out"
	log "captura salva em $out"
}

# Cor "R G B" de um pixel da tela (coordenadas da captura). Permite ao teste ler um indicador visual
# (ex.: verde/vermelho de um formulário) sem depender do que foi digitado às cegas.
cmd_pixel() {
	local x="${1:?uso: pixel X Y}" y="${2:?uso: pixel X Y}" tmp="$VM_DIR/screendump.ppm"
	rm -f "$tmp"
	qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$tmp\"}}" >/dev/null
	for _ in 1 2 3 4 5; do [ -s "$tmp" ] && break; sleep 1; done
	[ -s "$tmp" ] || die "screendump não gerou arquivo"
	python3 - "$tmp" "$x" "$y" <<'PY'
import sys
f = open(sys.argv[1], "rb"); x, y = int(sys.argv[2]), int(sys.argv[3])
# PPM binário (P6): "P6", largura, altura e valor máximo separados por espaço em branco, depois RGB
tok = []
while len(tok) < 4:
    line = f.readline()
    if not line.startswith(b"#"):
        tok += line.split()
w, h = int(tok[1]), int(tok[2])
if tok[0] != b"P6" or not (0 <= x < w and 0 <= y < h):
    sys.exit("pixel fora da tela %dx%d" % (w, h))
f.seek(f.tell() + 3 * (y * w + x))
print(*f.read(3))
PY
}

# Teclado via QMP: cada argumento é uma combinação de qcodes unidos por '-' (ex.: meta_l, alt-tab, ctrl-alt-t)
cmd_key() {
	local combo keys k
	[ $# -gt 0 ] || die "uso: key COMBO [COMBO...] (qcodes QEMU, ex.: meta_l alt-tab ret)"
	for combo in "$@"; do
		keys=""
		IFS='-' read -r -a parts <<<"$combo"
		for k in "${parts[@]}"; do keys="$keys{\"type\":\"qcode\",\"data\":\"$k\"},"; done
		qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[${keys%,}],\"hold-time\":50}}" | grep -q '"error"' && die "send-key falhou para $combo"
		sleep 0.3
	done
}

# Ponteiro absoluto (usb-tablet) via QMP. Coordenadas em unidades abs 0..32767 sobre a tela inteira.
#   mouse move X Y | mouse down|up [left|right] | mouse click [left|right] | mouse dblclick
cmd_mouse() {
	local op="${1:-}" b
	case "$op" in
		move)
			[ $# -eq 3 ] || die "uso: mouse move X Y (0..32767)"
			qmp "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$2}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$3}}]}}" >/dev/null ;;
		down|up)
			b="${2:-left}"
			qmp "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"btn\",\"data\":{\"down\":$([ "$op" = down ] && echo true || echo false),\"button\":\"$b\"}}]}}" >/dev/null ;;
		click) cmd_mouse down "${2:-left}"; sleep 0.1; cmd_mouse up "${2:-left}" ;;
		dblclick) cmd_mouse click; sleep 0.12; cmd_mouse click ;;
		wheel) b="wheel-${2:-up}"; cmd_mouse down "$b"; cmd_mouse up "$b" ;;
		*) die "uso: mouse move X Y | down|up|click [left|right] | dblclick | wheel up|down" ;;
	esac
}

# Executa um comando como root na VM pelo agente QEMU (funciona sem rede). Saída e código de retorno do comando.
cmd_ga() {
	is_running || die "VM não está em execução"
	[ $# -gt 0 ] || die "uso: ga COMANDO"
	python3 "$SCRIPT_DIR/qga.py" "$QGA_SOCK" "$*"
}

# Encerra o QEMU imediatamente (último recurso quando o convidado não desliga)
cmd_kill() {
	is_running || { log "VM já está desligada"; return; }
	qmp '{"execute":"quit"}' >/dev/null || true
	for _ in $(seq 1 20); do is_running || { log "VM encerrada à força"; return; }; sleep 1; done
	die "QEMU não encerrou"
}

# Liga/desliga o cabo da placa de rede virtual (simula falha de rede)
cmd_link() {
	case "${1:-}" in
		on) qmp '{"execute":"set_link","arguments":{"name":"n0","up":true}}' >/dev/null ;;
		off) qmp '{"execute":"set_link","arguments":{"name":"n0","up":false}}' >/dev/null ;;
		*) die "uso: link on|off" ;;
	esac
	log "link de rede: $1"
}

cmd_powerdown() {
	is_running || { log "VM já está desligada"; return; }
	# Com sessão Plasma aberta, o botão ACPI abre o diálogo de logout em vez de desligar;
	# por isso o desligamento ordenado via SSH vem primeiro e o ACPI fica como alternativa.
	if [ -f "$SECRETS_DIR/luma-password" ] &&
		VM_USER=luma ssh_vm 'sudo -S -p "" systemctl poweroff' < "$SECRETS_DIR/luma-password" >/dev/null 2>&1; then
		log "desligamento solicitado via SSH"
	else
		qmp '{"execute":"system_powerdown"}' >/dev/null
		log "desligamento solicitado via ACPI"
	fi
	local deadline=$((SECONDS + ${1:-180}))
	while is_running; do
		[ $SECONDS -lt $deadline ] || die "VM não desligou no prazo"
		sleep 2
	done
	log "VM desligada"
}

require_off() { ! is_running || die "desligue a VM antes (lab.sh powerdown)"; }

cmd_snapshot_save() {
	local name="${1:?uso: snapshot-save NOME}"
	require_off
	if "$QEMU_IMG" snapshot -l -U "$DISK" | awk 'NR>2 {print $2}' | grep -qx "$name"; then
		log "snapshot $name já existe; nada feito"
		return
	fi
	"$QEMU_IMG" snapshot -c "$name" "$DISK"
	cp "$VARS" "$SNAP_DIR/$name.vars.fd"
	log "snapshot $name criado"
}

cmd_snapshot_restore() {
	local name="${1:?uso: snapshot-restore NOME}"
	require_off
	"$QEMU_IMG" snapshot -a "$name" "$DISK"
	[ -f "$SNAP_DIR/$name.vars.fd" ] && cp "$SNAP_DIR/$name.vars.fd" "$VARS"
	log "snapshot $name restaurado"
}

# -U: leitura compartilhada, funciona com a VM ligada
cmd_snapshot_list() { "$QEMU_IMG" snapshot -l -U "$DISK"; }

cmd_status() {
	if is_running; then echo "em execução (pid $(cat "$PIDFILE"))"; else echo "desligada"; fi
	[ -f "$DISK" ] && "$QEMU_IMG" info -U "$DISK" | grep -E 'virtual size|disk size'
	[ -f "$DISK" ] && cmd_snapshot_list
	return 0
}

usage() {
	cat >&2 <<'EOF'
uso: lab.sh COMANDO
  check                 verifica dependências e /dev/kvm
  fetch-iso             baixa e verifica (GPG + SHA256) a netinst Debian fixada
  secrets               gera chave SSH e senha aleatória do laboratório
  build-iso             gera ISO de instalação automática (preseed)
  create                cria disco qcow2 e variáveis UEFI
  install               instala Debian + Plasma sem interação e desliga
  run                   inicia a VM em primeiro plano (BOOT_ISO=arquivo.iso para dar boot pela mídia)
  wait-ssh [SEG]        aguarda SSH
  ssh [CMD...]          executa comando na VM
  screenshot ARQ.png    captura a tela da VM
  pixel X Y             cor "R G B" de um pixel da tela
  key COMBO...          envia teclas (qcodes QEMU; ex.: meta_l alt-tab ret)
  mouse ...             ponteiro: move X Y (0..32767) | down|up|click [botão] | dblclick | wheel up|down
  link on|off           conecta/desconecta o cabo de rede virtual
  ga COMANDO            executa como root na VM pelo agente QEMU (sem rede)
  kill                  encerra o QEMU à força (último recurso)
  powerdown [SEG]       desligamento ACPI
  snapshot-save NOME | snapshot-restore NOME | snapshot-list
  status
EOF
	exit 64
}

main() {
	local c="${1:-}"; shift || true
	WORK="$(mktemp -d)"
	trap 'rm -rf "$WORK"' EXIT
	case "$c" in
		check) cmd_check ;;
		fetch-iso) cmd_fetch_iso ;;
		secrets) cmd_secrets ;;
		build-iso) cmd_build_iso ;;
		create) cmd_create ;;
		install) cmd_install ;;
		run) cmd_run ;;
		wait-ssh) cmd_wait_ssh "$@" ;;
		ssh) ssh_vm "$@" ;;
		screenshot) cmd_screenshot "$@" ;;
		pixel) cmd_pixel "$@" ;;
		key) cmd_key "$@" ;;
		mouse) cmd_mouse "$@" ;;
		link) cmd_link "$@" ;;
		ga) cmd_ga "$@" ;;
		kill) cmd_kill ;;
		powerdown) cmd_powerdown "$@" ;;
		snapshot-save) cmd_snapshot_save "$@" ;;
		snapshot-restore) cmd_snapshot_restore "$@" ;;
		snapshot-list) cmd_snapshot_list ;;
		status) cmd_status ;;
		*) usage ;;
	esac
}

main "$@"
