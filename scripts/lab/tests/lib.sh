# shellcheck shell=bash disable=SC2015,SC2016,SC2034
# Funções comuns dos testes na VM. Uso: . "$HERE/lib.sh" (define LAB, EV, T, fails e helpers).
# Requer: HERE (diretório do teste), EV (diretório de evidências), TEST_USER (conta com sessão gráfica).
LAB="$HERE/../lab.sh"
# shellcheck source=scripts/lab/config.sh
. "$HERE/../config.sh"
: "${TEST_USER:=teste}"
mkdir -p "$EV"
fails=0
T="$(mktemp -d)"

ok()  { echo "PASSOU: $*"; }
bad() { echo "FALHOU: $*"; fails=$((fails + 1)); }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

# Comando como TEST_USER com acesso à sessão gráfica
u() { VM_USER="$TEST_USER" "$LAB" ssh ". /usr/local/bin/luma-lab-sessenv 2>/dev/null; $1"; }
# Compara a saída de um comando na sessão com o esperado e mostra o observado quando difere
check_eq() {
	local d="$1" want="$2" got
	got="$(u "$3" 2>&1)"
	if [ "$got" = "$want" ]; then ok "$d"; else bad "$d (esperado '$want', observado '$got')"; fi
}
cfg() { printf 'kreadconfig6 --file %s --group %s --key %s --default %s' "${4:-kdeglobals}" "$1" "$2" "${3:-VAZIO}"; }

# Executa um script local como root na VM (senha via stdin do sudo; argumentos simples repassados)
as_root() {
	local f="$1"; shift
	"$LAB" ssh 'cat > /tmp/root.sh' < "$f" &&
		"$LAB" ssh "sudo -S -p '' bash /tmp/root.sh $*; rc=\$?; rm -f /tmp/root.sh; exit \$rc" < "$LAB_DIR/secrets/luma-password"
}
root_cmd() { printf '%s\n' "$1" > "$T/cmd.sh"; as_root "$T/cmd.sh"; }

shot() { sleep "${2:-6}"; "$LAB" screenshot "$EV/$1.png" >/dev/null 2>&1 && echo "captura: $1.png" || bad "captura $1"; }

wait_plasma() {
	local _
	for _ in $(seq 1 60); do
		u 'pgrep -x plasmashell >/dev/null && test -S "$XDG_RUNTIME_DIR/wayland-0"' 2>/dev/null && return 0
		sleep 3
	done
	return 1
}

# Área de trabalho pronta: splash encerrado e layout gravado (1º login de usuário novo é lento)
wait_desktop() {
	local _
	wait_plasma || return 1
	for _ in $(seq 1 60); do
		u '! pgrep -x ksplashqml >/dev/null && grep -q "^plugin=org.kde.panel" .config/plasma-org.kde.plasma.desktop-appletsrc' 2>/dev/null && { sleep 5; return 0; }
		sleep 3
	done
	return 1
}

# Repete um comando na sessão até ter sucesso (estado que o Plasma grava de forma assíncrona)
eventually() {
	local d="$1" secs="$2" cmd="$3" _
	for _ in $(seq 1 $((secs / 3))); do
		u "$cmd" >/dev/null 2>&1 && { ok "$d"; return 0; }
		sleep 3
	done
	bad "$d (não ocorreu em ${secs}s)"
}

# Liga a VM a partir de base-limpa (aborta o teste se não conseguir)
fresh_vm() {
	"$LAB" powerdown 180 >/dev/null 2>&1 || true
	"$LAB" snapshot-restore base-limpa >/dev/null || { bad "restaurar base-limpa (VM não desligou?)"; exit 1; }
	boot_vm
}
boot_vm() {
	"$LAB" run >>"$EV/vm-run.log" 2>&1 &
	"$LAB" wait-ssh 900 >/dev/null || { bad "VM não respondeu"; exit 1; }
}
reboot_vm() {
	"$LAB" powerdown 180 >/dev/null || { bad "desligar VM"; exit 1; }
	boot_vm
}

# Cria TEST_USER com login automático; senha opcional (arquivo local) para testes de bloqueio
setup_user() {
	local pwfile="${1:-}"
	[ -n "$pwfile" ] && "$LAB" ssh 'umask 077; cat > /tmp/test-user-password' < "$pwfile"
	as_root "$HERE/../guest/setup-test-user.sh" "$TEST_USER" "${2:-}" >/dev/null 2>&1 || bad "preparar conta $TEST_USER"
}
polkit_open() { windows | py "any('polkit' in w['cls'].lower() for w in d['windows'])" | grep -q True; }
# Se o diálogo de autenticação do polkit abrir em até N s, digita a senha (arquivo) e confirma
polkit_auth() {
	local pwfile="$1" tries="${2:-10}" _
	for _ in $(seq 1 "$tries"); do
		if polkit_open; then
			sleep 1; type_text "$(cat "$pwfile")"; "$LAB" key ret; return 0
		fi
		sleep 1
	done
	echo "info: janelas sem diálogo polkit: $(windows | py "[w['cls'] for w in d['windows']]")"
	return 1
}

# Janelas via KWin: JSON em uma linha; py() extrai um valor com uma expressão Python sobre 'd'
windows() { u 'luma-lab-windows'; }
py() { python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print($1)"; }

# Coordenada lógica → unidade abs do usb-tablet (0..32767)
abs_x() { echo $(( $1 * 32767 / SCREEN_W )); }
abs_y() { echo $(( $1 * 32767 / SCREEN_H )); }
mouse_to() { "$LAB" mouse move "$(abs_x "$1")" "$(abs_y "$2")"; }

# Digita texto via QMP. Suporta a-z, A-Z, 0-9, espaço, '-', '.' e '=', que ocupam as mesmas teclas no US e no ABNT2 da VM.
type_text() {
	local s="$1" i c keys=()
	for ((i = 0; i < ${#s}; i++)); do
		c="${s:i:1}"
		case "$c" in
			[a-z0-9]) keys+=("$c") ;;
			[A-Z]) keys+=("shift-${c,,}") ;;
			=) keys+=(equal) ;;
			" ") keys+=(spc) ;;
			-) keys+=(minus) ;;
			.) keys+=(dot) ;;
			*) echo "type_text: caractere não suportado: '$c'" >&2; return 2 ;;
		esac
	done
	"$LAB" key "${keys[@]}"
}
# Executa um comando DENTRO da sessão gráfica ativa (Konsole aberto pelo KRunner), como faria o usuário.
# Necessário para ações cuja autorização polkit depende de sessão local ativa.
session_cmd() {
	if ! u 'pgrep -x konsole >/dev/null'; then
		"$LAB" key alt-spc; sleep 3; type_text konsole; "$LAB" key ret; sleep 8
	fi
	type_text "$1"; "$LAB" key ret; sleep "${2:-4}"
}

cleanup() { "$LAB" powerdown 120 >/dev/null 2>&1 || true; rm -rf "$T"; }
trap cleanup EXIT
