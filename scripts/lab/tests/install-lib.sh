# shellcheck shell=bash disable=SC2015,SC2016,SC2034
# Funções para dirigir o instalador (Calamares) da ISO live pela tela, como um usuário: mouse e teclado
# via QMP, estado das janelas via KWin. Uso: depois de lib.sh. Requer ISO e LIVE_USER.
# Coordenadas dos controles: unidades lógicas relativas à janela do instalador (negativo = a partir da
# borda direita/inferior), medidas nas capturas de docs/evidence/etapa9.

ga() { "$LAB" ga "$1"; }
asu() { ga "sh /run/luma-lab/asuser.sh $LIVE_USER '$1'"; }
gwin() { asu 'sh /run/luma-lab/windows.sh'; }
push_guest() { ga "mkdir -p /run/luma-lab && echo $(base64 -w0 "$1") | base64 -d > /run/luma-lab/$(basename "$1")" >/dev/null; }
wait_agent() { local _; for _ in $(seq 1 "${1:-60}"); do ga true >/dev/null 2>&1 && return 0; sleep 5; done; return 1; }
vm_off() { local st; st="$("$LAB" status 2>/dev/null | head -n1)"; [[ "$st" == desligada* ]]; }

# Liga a VM pela ISO (a mídia tem prioridade sobre o disco) e espera a área de trabalho live
boot_live() {
	local _ j
	BOOT_ISO="$ISO" "$LAB" run >>"$EV/vm-run.log" 2>&1 &
	wait_agent 120 || { bad "ISO não iniciou (agente sem resposta)"; exit 1; }
	for _ in $(seq 1 60); do ga "pgrep -u $LIVE_USER -x plasmashell" >/dev/null 2>&1 && break; sleep 5; done
	ga "pgrep -u $LIVE_USER -x plasmashell" >/dev/null 2>&1 || { bad "sessão live não iniciou"; exit 1; }
	sleep 30
	push_guest "$HERE/../guest/asuser.sh"; push_guest "$HERE/../guest/windows.sh"
	# Somente laboratório: sem repetição automática de tecla nos apps X11 (o instalador), para uma tecla
	# virtual solta com atraso não virar várias
	asu 'xset r off' >/dev/null 2>&1 || true
	j="$(gwin)"
	SCREEN_W="$(py "d['screen']['w']" <<<"$j")"; SCREEN_H="$(py "d['screen']['h']" <<<"$j")"
}

# Liga a VM pelo disco, sem ISO. Com ENCRYPT=1 digita a senha do disco ($1) no pedido do GRUB; se a senha
# sair errada (tecla virtual perdida) o GRUB não segue: desliga e tenta de novo (até 3 vezes).
boot_disk() {
	local i
	for i in 1 2 3; do
		"$LAB" run >>"$EV/vm-run.log" 2>&1 &
		[ "${ENCRYPT:-0}" = 1 ] || { wait_agent "${2:-60}"; return; }
		sleep 15; [ "$i" = 1 ] && shot "${SHOT_PREFIX}-pedido-senha-disco" 0
		type_text "$(cat "$1")"; "$LAB" key ret
		wait_agent 30 && return 0
		echo "info: sistema cifrado não iniciou na tentativa $i"; shot "${SHOT_PREFIX}-boot-tentativa-$i" 0
		"$LAB" kill >/dev/null 2>&1; sleep 3
	done
	return 1
}

# Desliga a VM (sem SSH) e espera o QEMU encerrar: pelo agente; sem agente, botão de energia (ACPI) na
# tela de login; por último, força
vm_poweroff() {
	local _
	ga 'systemctl poweroff' >/dev/null 2>&1 || true
	for _ in $(seq 1 20); do vm_off && return 0; sleep 3; done
	"$LAB" powerdown 90 >/dev/null 2>&1 && return 0
	"$LAB" kill >/dev/null 2>&1
}

# Geometria "x y w h" da janela principal (False) ou do diálogo (True) do instalador
inst_geom() {
	gwin | py "next((' '.join(str(int(w[k])) for k in 'xywh') for w in d['windows'] if 'calamares' in w['cls'].lower() and w['dialog'] == $1), '')"
}
# Clique relativo à janela: inst_click False|True DX DY
inst_click() {
	local g x y w h px py_
	g="$(inst_geom "$1")"; [ -n "$g" ] || { echo "inst_click: janela do instalador não encontrada" >&2; return 1; }
	read -r x y w h <<<"$g"
	if [ "$2" -ge 0 ]; then px=$((x + $2)); else px=$((x + w + $2)); fi
	if [ "$3" -ge 0 ]; then py_=$((y + $3)); else py_=$((y + h + $3)); fi
	mouse_to "$px" "$py_"; sleep 0.4; "$LAB" mouse click
}
inst_next() { inst_click False -146 -19; }       # Próximo / Instalar
inst_cancel() { inst_click False -49 -19; }      # Cancelar

# Abre o instalador pelo KRunner (precisa partir da sessão ativa: o pkexec nega fora dela).
# Até 3 tentativas: sob carga do host o teclado virtual pode perder ou repetir uma tecla.
open_installer() {
	local _ i
	for i in 1 2 3; do
		"$LAB" key alt-spc; sleep 3; type_text calamares; sleep 3; "$LAB" key ret
		for _ in $(seq 1 15); do [ -n "$(inst_geom False 2>/dev/null)" ] && { sleep 5; return 0; }; sleep 3; done
		"$LAB" key esc; sleep 2
	done
	return 1
}

# Cancela pelo botão e confirma no diálogo; confere que o instalador encerrou (até 3 tentativas)
inst_cancel_confirm() {
	local _ i
	for i in 1 2 3; do
		inst_cancel
		for _ in $(seq 1 8); do [ -n "$(inst_geom True 2>/dev/null)" ] && break; sleep 2; done
		[ "$i" = 1 ] && shot "${SHOT_PREFIX}-dialogo" 0
		inst_click True -140 -24                 # "Sim"
		for _ in $(seq 1 8); do ga '! pgrep -x calamares' >/dev/null 2>&1 && return 0; sleep 2; done
	done
	return 1
}

# Estado do disco de destino visto pelo sistema live
disk_state() { ga 'lsblk -n -o NAME,TYPE,FSTYPE /dev/vda | tr -s " " | tr "\n" ";"'; }

# Indicador de validação do instalador (círculo verde com "✓" ou quadrado vermelho com "×") numa posição
# relativa à janela: sucesso se o pixel for verde. É assim que o teste sabe se as duas senhas digitadas
# às cegas ficaram iguais.
inst_ok_at() {
	local g x y w h r gr b
	g="$(inst_geom False)"; [ -n "$g" ] || return 1
	read -r x y w h <<<"$g"
	read -r r gr b < <("$LAB" pixel "$(( (x + $1) * VM_XRES / SCREEN_W ))" "$(( (y + $2) * VM_YRES / SCREEN_H ))") || return 1
	[ "$gr" -gt $((r + 40)) ]
}
# Digita a mesma senha em dois campos seguidos (foco no 1º) e confere o indicador em ($2,$3); se as teclas
# virtuais falharem, limpa os dois campos e redigita (até 3 vezes)
inst_type_twice() {
	local i
	for i in 1 2 3; do
		type_text "$(cat "$1")"; "$LAB" key tab; type_text "$(cat "$1")"; sleep 3
		inst_ok_at "$2" "$3" && return 0
		echo "info: senhas não conferem na tentativa $i; redigitando"
		"$LAB" key ctrl-a backspace shift-tab ctrl-a backspace; sleep 1
	done
	return 1
}

# Percorre as páginas até o resumo: idioma, localização, teclado, disco inteiro (ENCRYPT=1 cifra), usuário.
# $1 = nome completo, $2 = arquivo com a senha (da conta e, se cifrado, do disco). Falha se alguma página
# não chegar ao estado esperado (o resumo é reconhecido pela janela mais alta).
inst_pages_to_summary() {
	local erase_y=111 h
	# Com partições no disco a página oferece "lado a lado" e "substituir" antes de "Formatar o disco"
	disk_state | grep -q part && erase_y=228
	inst_next; sleep 6                      # Bem-vindo → Localização
	shot "${SHOT_PREFIX}-localizacao" 0
	inst_next; sleep 6                      # → Teclado
	inst_next; sleep 20                     # → Partições (espera a leitura dos discos)
	inst_click False 205 "$erase_y"; sleep 6
	if [ "${ENCRYPT:-0}" = 1 ]; then
		inst_click False 205 413; sleep 3   # "Criptografar sistema"
		"$LAB" key tab
		inst_type_twice "$2" 996 403 || { shot "${SHOT_PREFIX}-particoes" 0; echo "senha do disco não aceita" >&2; return 1; }
	fi
	shot "${SHOT_PREFIX}-particoes" 0
	inst_next; sleep 6                      # → Usuários (foco no nome)
	type_text "$1"; "$LAB" key tab; sleep 2
	"$LAB" key tab tab; sleep 1             # login e nome do computador ficam os sugeridos
	inst_type_twice "$2" 621 261 || { shot "${SHOT_PREFIX}-usuario" 0; echo "senha da conta não aceita" >&2; return 1; }
	shot "${SHOT_PREFIX}-usuario" 0
	inst_next; sleep 6                      # → Resumo
	shot "${SHOT_PREFIX}-resumo" 0
	h="$(inst_geom False | cut -d' ' -f4)"
	[ "${h:-0}" -gt 650 ] || { echo "página de resumo não apareceu (altura ${h:-?})" >&2; return 1; }
}

# Login na tela do SDDM com a senha do arquivo $2; redigita se a sessão não abrir (até 3 vezes)
sddm_login() {
	local _ i
	for i in 1 2 3; do
		type_text "$(cat "$2")"; "$LAB" key ret
		for _ in $(seq 1 18); do ga "pgrep -u $1 -x plasmashell" >/dev/null 2>&1 && return 0; sleep 5; done
		echo "info: login não abriu a sessão na tentativa $i"
	done
	return 1
}

inst_mounted() { ga 'findmnt -rn -o TARGET | grep -q "^/tmp/calamares-root-"'; }
# Clica em Instalar e espera a cópia começar (raiz do destino montada)
inst_start() {
	local _
	inst_next
	for _ in $(seq 1 40); do inst_mounted && return 0; sleep 4; done
	return 1
}
# Espera o fim da instalação (destino desmontado), até $1 minutos
inst_wait_done() {
	local _
	for _ in $(seq 1 $(( ${1:-40} * 6 ))); do inst_mounted || return 0; sleep 10; done
	return 1
}

# Espera o menu do GRUB do sistema instalado: tela 1280x800 com a imagem de fundo (PNG grande)
wait_grub() {
	local _ f="$T/grub.png"
	for _ in $(seq 1 120); do
		"$LAB" screenshot "$f" >/dev/null 2>&1 && file -b "$f" | grep -q '1280 x 800' && [ "$(stat -c %s "$f")" -gt 100000 ] && return 0
		sleep 0.5
	done
	return 1
}
