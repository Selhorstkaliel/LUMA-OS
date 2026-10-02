#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 4: integrações reais da central de controle (bandeja do Plasma; decisão 0003).
# Áudio (PipeWire), rede (NetworkManager) e energia (power-profiles-daemon/UPower): caminho feliz,
# falha, ausência de dispositivo, acesso negado e persistência após reinício.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa4}"
TEST_USER=teste
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
V="$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)"
NIC=enp0s1
vol() { u 'wpctl get-volume @DEFAULT_AUDIO_SINK@' 2>/dev/null; }                 # "Volume: 0.40" ou "... [MUTED]"
vnum() { vol | awk '{print $2}'; }
gt() { python3 -c "import sys; sys.exit(0 if float('$1') > float('$2') + 0.001 else 1)"; }
tray_x() { echo $((SCREEN_W - $1)); }   # ícones da bandeja contados a partir da borda direita (coordenadas lógicas)

fresh_vm
for p in luma-theme luma-session; do "$LAB" ssh "cat > /tmp/$p.deb" < "$LAB_DIR/debs/${p}_${V}_all.deb"; done
root_cmd 'apt-get install -y /tmp/luma-theme.deb /tmp/luma-session.deb' > "$EV/E4-00-apt-install.log" 2>&1 || bad "instalar pacotes Luma"
setup_user ""
wait_desktop || { bad "área de trabalho não ficou pronta"; exit 1; }
u 'pkill -f plasma-welcome' || true
check "agente QEMU responde (verificação sem rede)" "$LAB" ga true
SCREEN_W="$(windows | py "int(d['screen']['w'])")"; SCREEN_H="$(windows | py "int(d['screen']['h'])")"
echo "info: tela lógica ${SCREEN_W}x${SCREEN_H}; $(vol); perfil $(u 'powerprofilesctl get')"

# ---------- Áudio ----------
v0="$(vnum)"
"$LAB" key volumeup; sleep 2; v1="$(vnum)"
gt "$v1" "$v0" && ok "tecla Aumentar volume ($v0 → $v1)" || bad "tecla Aumentar volume ($v0 → $v1)"
"$LAB" key volumedown volumedown; sleep 2; v2="$(vnum)"
gt "$v1" "$v2" && ok "tecla Diminuir volume ($v1 → $v2)" || bad "tecla Diminuir volume ($v1 → $v2)"
"$LAB" key audiomute; sleep 2
vol | grep -q MUTED && ok "tecla Mudo silencia" || bad "tecla Mudo ($(vol))"
"$LAB" key audiomute; sleep 2
vol | grep -q MUTED && bad "tecla Mudo não reativou ($(vol))" || ok "tecla Mudo reativa"
# Rolagem sobre o ícone de volume da bandeja. Posições medidas no layout 0.6 (bandeja, Central de Controle, relógio):
# volume a 127 px lógicos da borda direita, rede a 158, energia/brilho a 186.
v3="$(vnum)"; mouse_to "$(tray_x 127)" 12; sleep 1
"$LAB" mouse wheel up; sleep 0.5; "$LAB" mouse wheel up; sleep 2; v4="$(vnum)"
gt "$v4" "$v3" && ok "rolar sobre o ícone de volume ($v3 → $v4)" || bad "rolar sobre o ícone de volume ($v3 → $v4)"
"$LAB" mouse click; shot E4-01-popup-volume 3
"$LAB" key esc
u 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.63' && ok "definir volume 0.63 para teste de persistência" || bad "definir volume"

# ---------- Rede ----------
check_eq "rede conectada (NetworkManager)" full 'nmcli -t -f CONNECTIVITY general'
mouse_to "$(tray_x 158)" 12; "$LAB" mouse click; shot E4-02-popup-rede 3; "$LAB" key esc
# Falha: cabo desconectado
"$LAB" link off; sleep 10
st="$("$LAB" ga "nmcli -t -f DEVICE,STATE dev status | grep ^$NIC:" 2>/dev/null)"
[ "$st" = "$NIC:unavailable" ] && ok "cabo desconectado: $NIC indisponível" || bad "cabo desconectado: estado '$st'"
check "plasmashell estável sem rede" "$LAB" ga "pgrep -u $TEST_USER -x plasmashell"
shot E4-03-sem-cabo 1
"$LAB" link on
"$LAB" wait-ssh 90 >/dev/null && sleep 5
check_eq "cabo reconectado: conexão volta sozinha" full 'nmcli -t -f CONNECTIVITY general'
# Acesso negado: sessão SSH remota de usuário sem privilégio não controla a rede
# timeout: se NÃO fosse negado, a rede (e esta conexão SSH) cairia
out="$(VM_USER="$TEST_USER" timeout 30 "$LAB" ssh "nmcli device disconnect $NIC" 2>&1)"; rc=$?
st="$("$LAB" ga "nmcli -t -f DEVICE,STATE dev status | grep ^$NIC:" 2>/dev/null)"
[ $rc -ne 0 ] && [ "$st" = "$NIC:connected" ] && ok "sessão remota sem privilégio: desconectar negado ($out)" || { bad "desconexão remota não negada (rc=$rc, $st)"; "$LAB" ga "nmcli device connect $NIC" >/dev/null 2>&1; }
# Caminho permitido: usuário na sessão local ativa (como o applet)
session_cmd "nmcli device disconnect $NIC" 6
st="$("$LAB" ga "nmcli -t -f DEVICE,STATE dev status | grep ^$NIC:" 2>/dev/null)"
[ "$st" = "$NIC:disconnected" ] && ok "sessão local ativa desconecta a rede" || bad "sessão local: desconectar ($st)"
shot E4-04-desconectado-pelo-usuario 1
session_cmd "nmcli device connect $NIC" 10
"$LAB" wait-ssh 90 >/dev/null
check_eq "sessão local ativa reconecta" full 'nmcli -t -f CONNECTIVITY general'

# ---------- Energia ----------
session_cmd "powerprofilesctl set power-saver" 4
check_eq "perfil de energia alterado na sessão" power-saver 'powerprofilesctl get'
check "sem bateria: UPower só com dispositivo de exibição" "$LAB" ga "test \"\$(upower -e | grep -c battery_)\" = 0"
u 'pkill -x konsole' || true
mouse_to "$(tray_x 186)" 12; "$LAB" mouse click; shot E4-05-popup-energia 3; "$LAB" key esc

# ---------- Persistência após reinício ----------
reboot_vm; wait_desktop || bad "sessão após reinício"
# Bloqueio conhecido: docs/evidence/etapa4/bloqueio-volume/README.md
check_eq "volume mantido após reinício" 0.63 "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print \$2}'"
check_eq "perfil de energia mantido após reinício" power-saver 'powerprofilesctl get'
check_eq "rede conectada após reinício" full 'nmcli -t -f CONNECTIVITY general'

# ---------- Ausência de dispositivo de áudio ----------
VM_AUDIO=0 reboot_vm; wait_desktop || bad "sessão sem placa de som"
# Sem placa, o WirePlumber cria só a saída fictícia "Dummy Output"; nenhum dispositivo [alsa]
check "sem placa de som: nenhum dispositivo ALSA" u '! wpctl status | sed -n "/Audio/,/Sinks:/p" | grep -q "\[alsa\]"'
"$LAB" key volumeup; sleep 3
check "sem placa de som: plasmashell estável após tecla de volume" u 'pgrep -x plasmashell'
mouse_to "$(tray_x 127)" 12; "$LAB" mouse click; shot E4-06-sem-placa-de-som 3; "$LAB" key esc

# ---------- Ausência de placa de rede (verificação pelo agente QEMU) ----------
"$LAB" powerdown 180 >/dev/null || { bad "desligar VM"; exit 1; }
VM_NET=0 "$LAB" run >>"$EV/vm-run.log" 2>&1 &
for _ in $(seq 1 100); do "$LAB" ga "pgrep -u $TEST_USER -x plasmashell" >/dev/null 2>&1 && break; sleep 5; done
sleep 30
check "sem placa de rede: sessão Plasma ativa" "$LAB" ga "pgrep -u $TEST_USER -x plasmashell"
check "sem placa de rede: NetworkManager sem ethernet" "$LAB" ga "test \"\$(nmcli -t -f TYPE dev status | grep -c ethernet)\" = 0"
shot E4-07-sem-placa-de-rede 1
"$LAB" ga "systemctl poweroff" >/dev/null 2>&1 || true
# Sem "| grep -q": com pipefail, o SIGPIPE no lab.sh status tornaria o teste falso (falha3)
vm_off() { local st; st="$("$LAB" status 2>/dev/null)"; [[ "$st" == desligada* ]]; }
for _ in $(seq 1 60); do vm_off && break; sleep 3; done
vm_off || { shot E4-08-desligamento-demorado 0; bad "VM sem rede não desligou pelo agente em 180 s"; "$LAB" kill; }

# ---------- Volta ao normal ----------
boot_vm; wait_desktop || bad "sessão após voltar ao hardware normal"
check_eq "placa de som de volta: volume preservado" 0.63 "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print \$2}'"
check_eq "placa de rede de volta: conectada" full 'nmcli -t -f CONNECTIVITY general'

echo "PENDENTE (hardware): Wi-Fi físico, Bluetooth, brilho de painel interno e bateria real — sem dispositivo na VM."
echo "falhas: $fails"
exit $((fails > 0))
