#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 3: sessão Luma para um usuário NOVO (padrões via luma-session), janelas por mouse/teclado,
# Alt+Tab, notificações, pesquisa, bloqueio com senha, persistência após logout/reinício e purge.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa3}"
TEST_USER=novo
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
V="$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)"
for p in luma-theme luma-session luma-ajustes; do
	[ -f "$LAB_DIR/debs/${p}_${V}_all.deb" ] || { echo "pacote ${p}_${V} ausente; rode scripts/build/build-debs.sh" >&2; exit 2; }
done
# Senha aleatória digitável (a-z0-9) para testar o desbloqueio; fica só nos segredos do laboratório
PW="$LAB_DIR/secrets/novo-password"
[ -s "$PW" ] || (umask 077; tr -dc 'a-z0-9' < /dev/urandom | head -c 16 > "$PW")
appletsrc='.config/plasma-org.kde.plasma.desktop-appletsrc'  # relativo ao home remoto
win() { windows | py "$1"; }   # expressão sobre d (JSON de luma-lab-windows)
k() { win "[w for w in d['windows'] if w['cls']=='$1'][0]['$2']"; }

fresh_vm
"$LAB" ssh 'cat > /tmp/luma-theme.deb' < "$LAB_DIR/debs/luma-theme_${V}_all.deb"
"$LAB" ssh 'cat > /tmp/luma-session.deb' < "$LAB_DIR/debs/luma-session_${V}_all.deb"
"$LAB" ssh 'cat > /tmp/luma-ajustes.deb' < "$LAB_DIR/debs/luma-ajustes_${V}_all.deb"
root_cmd 'apt-get install -y /tmp/luma-theme.deb /tmp/luma-session.deb /tmp/luma-ajustes.deb' > "$EV/E3-00-apt-install.log" 2>&1 && ok "apt instala luma-theme, luma-session e luma-ajustes" || bad "apt instala pacotes"
setup_user "$PW"
wait_desktop && ok "primeiro login do usuário novo (área de trabalho pronta)" || { bad "área de trabalho do usuário novo não ficou pronta em 3 min"; exit 1; }

# E3-01 usuário novo recebe os padrões Luma sem nenhum comando
check_eq "novo: LookAndFeelPackage" org.luma.desktop "$(cfg KDE LookAndFeelPackage)"
check_eq "novo: esquema LumaLight"  LumaLight "$(cfg General ColorScheme)"
check_eq "novo: fonte Inter (padrão do sistema)" Inter "kreadconfig6 --file kdeglobals --group General --key font | cut -d, -f1"
eventually "novo: painel superior e dock" 60 "test \"\$(grep -c '^plugin=org.kde.panel' $appletsrc)\" = 2"
eventually "novo: dock com favoritos" 60 "grep -q 'launchers=applications:org.kde.dolphin.desktop' $appletsrc"
eventually "novo: wallpaper Luma" 60 "grep -q '^Image=file:///usr/share/wallpapers/Luma' $appletsrc"
check_eq "novo: botões de janela à esquerda" XIA "$(cfg org.kde.kdecoration2 ButtonsOnLeft VAZIO kwinrc)"
check_eq "tela de bloqueio usa wallpaper Luma" "file:///usr/share/wallpapers/Luma" 'kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image'
shot E3-01-usuario-novo 2
u 'pkill -f plasma-welcome' || true

# E3-02 janelas por mouse e teclado
u 'setsid -f konsole >/dev/null 2>&1'; sleep 8
SCREEN_W="$(win "int(d['screen']['w'])")"; SCREEN_H="$(win "int(d['screen']['h'])")"
x="$(k org.kde.konsole x | cut -d. -f1)"; y="$(k org.kde.konsole y | cut -d. -f1)"; w="$(k org.kde.konsole w | cut -d. -f1)"
echo "info: tela lógica ${SCREEN_W}x${SCREEN_H}; konsole em $x,$y largura $w"
# mover: arrastar a barra de título
mouse_to $((x + w / 2)) $((y + 12)); "$LAB" mouse down; sleep 0.3
for s in 1 2 3 4; do mouse_to $((x + w / 2 + 50 * s)) $((y + 12 + 30 * s)); sleep 0.2; done
"$LAB" mouse up; sleep 1
nx="$(k org.kde.konsole x | cut -d. -f1)"; ny="$(k org.kde.konsole y | cut -d. -f1)"
[ $((nx - x)) -ge 190 ] && [ $((nx - x)) -le 210 ] && [ $((ny - y)) -ge 110 ] && [ $((ny - y)) -le 130 ] \
	&& ok "mover janela arrastando o título (Δ=$((nx - x)),$((ny - y)))" || bad "mover janela (Δ=$((nx - x)),$((ny - y)), esperado ~200,120)"
x="$nx"; y="$ny"
# maximizar e restaurar: duplo clique no título
mouse_to $((x + w / 2)) $((y + 12)); "$LAB" mouse dblclick; sleep 2
check_eq "maximizar (duplo clique no título)" True "luma-lab-windows | python3 -c \"import json,sys; print([w for w in json.load(sys.stdin)['windows'] if w['cls']=='org.kde.konsole'][0]['maximized'])\""
shot E3-02-maximizada 1
mouse_to $((SCREEN_W / 2)) 45; "$LAB" mouse dblclick; sleep 2
check_eq "restaurar (duplo clique no título)" False "luma-lab-windows | python3 -c \"import json,sys; print([w for w in json.load(sys.stdin)['windows'] if w['cls']=='org.kde.konsole'][0]['maximized'])\""
# minimizar: botão amarelo da decoração Luma (segundo a partir da esquerda; fechar=+24, minimizar=+46, maximizar=+68)
x="$(k org.kde.konsole x | cut -d. -f1)"; y="$(k org.kde.konsole y | cut -d. -f1)"; w="$(k org.kde.konsole w | cut -d. -f1)"
mouse_to $((x + 46)) $((y + 20)); "$LAB" mouse click; sleep 2
check_eq "minimizar (botão)" True "luma-lab-windows | python3 -c \"import json,sys; print([w for w in json.load(sys.stdin)['windows'] if w['cls']=='org.kde.konsole'][0]['minimized'])\""
# Alt+Tab devolve a janela minimizada
"$LAB" key alt-tab; sleep 2
check_eq "Alt+Tab restaura a minimizada" "False True" "luma-lab-windows | python3 -c \"import json,sys; w=[w for w in json.load(sys.stdin)['windows'] if w['cls']=='org.kde.konsole'][0]; print(w['minimized'], w['active'])\""
# Alt+Tab alterna entre duas janelas
u 'setsid -f dolphin >/dev/null 2>&1'; sleep 8
check_eq "Dolphin ativo ao abrir" True "luma-lab-windows | python3 -c \"import json,sys; print([w for w in json.load(sys.stdin)['windows'] if w['cls']=='org.kde.dolphin'][0]['active'])\""
"$LAB" key alt-tab; sleep 2
check_eq "Alt+Tab alterna para Konsole" True "luma-lab-windows | python3 -c \"import json,sys; print([w for w in json.load(sys.stdin)['windows'] if w['cls']=='org.kde.konsole'][0]['active'])\""
shot E3-02-duas-janelas 1
# fechar: botão vermelho, o primeiro à esquerda (Konsole, ativo) e Alt+F4 (Dolphin)
x="$(k org.kde.konsole x | cut -d. -f1)"; y="$(k org.kde.konsole y | cut -d. -f1)"; w="$(k org.kde.konsole w | cut -d. -f1)"
mouse_to $((x + 24)) $((y + 20)); "$LAB" mouse click; sleep 3
check "fechar pelo botão X" u '! pgrep -x konsole'
"$LAB" key alt-tab; sleep 1; "$LAB" key alt-f4; sleep 3
check "fechar com Alt+F4" u '! pgrep -x dolphin'

# E3-03 notificações (interface padrão org.freedesktop.Notifications)
nid="$(u 'gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify "Luma" 0 "dialog-information" "Teste Luma" "Notificação de teste da etapa 3" "[]" "{}" 8000' 2>&1)"
[[ "$nid" =~ ^\(uint32\ [1-9][0-9]*,\)$ ]] && ok "notificação aceita pelo servidor ($nid)" || bad "notificação ($nid)"
shot E3-03-notificacao 2

# E3-04 pesquisa (KRunner: Alt+Espaço)
"$LAB" key alt-spc; sleep 3; type_text dolphin; shot E3-04-krunner 3
"$LAB" key ret; sleep 8
check "KRunner abre Dolphin pela busca" u 'pgrep -x dolphin'
u 'pkill -x dolphin' || true; sleep 2

# E3-05 bloqueio exige autenticação (Meta+L)
locked() { u 'loginctl show-session "$(loginctl show-user "$USER" -p Display --value)" -p LockedHint --value'; }
"$LAB" key meta_l-l; sleep 5
[ "$(locked)" = yes ] && ok "Meta+L bloqueia a sessão" || bad "Meta+L não bloqueou ($(locked))"
shot E3-05-bloqueada 1
"$LAB" key ctrl; sleep 2; type_text senhaerrada1; "$LAB" key ret; sleep 6
[ "$(locked)" = yes ] && ok "senha errada não desbloqueia" || bad "senha errada desbloqueou!"
shot E3-05-senha-errada 0
sleep 4; type_text "$(cat "$PW")"; "$LAB" key ret; sleep 6
[ "$(locked)" = no ] && ok "senha correta desbloqueia" || bad "senha correta não desbloqueou ($(locked))"
shot E3-05-desbloqueada 1

# E3-06 persistência: escolha do usuário sobrevive a logout e reinício
u 'luma-appearance escuro' >/dev/null 2>&1 && ok "usuário escolhe tema escuro" || bad "luma-appearance escuro"
pid1="$(u 'pgrep -x plasmashell')"
u 'qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout' >/dev/null 2>&1
sleep 15; wait_plasma || bad "relogin após logout"
sleep 15
pid2="$(u 'pgrep -x plasmashell')"
[ -n "$pid2" ] && [ "$pid1" != "$pid2" ] && ok "logout encerrou a sessão e novo login ocorreu" || bad "logout não reiniciou a sessão ($pid1 → $pid2)"
check_eq "após logout: esquema LumaDark" LumaDark "$(cfg General ColorScheme)"
check "após logout: 2 painéis"             u "test \"\$(grep -c '^plugin=org.kde.panel' $appletsrc)\" = 2"
shot E3-06-apos-logout 1
reboot_vm
wait_plasma || bad "sessão após reinício"
sleep 20
check_eq "após reinício: esquema LumaDark" LumaDark "$(cfg General ColorScheme)"
check_eq "após reinício: LookAndFeel escuro" org.luma.dark.desktop "$(cfg KDE LookAndFeelPackage)"
check "após reinício: 2 painéis"             u "test \"\$(grep -c '^plugin=org.kde.panel' $appletsrc)\" = 2"
shot E3-06-apos-reinicio 1

# E3-07 purge de luma-session remove os padrões do sistema, mantém escolhas do usuário e o tema
root_cmd 'apt-get purge -y luma-session' > "$EV/E3-07-apt-purge.log" 2>&1 && ok "apt purge luma-session" || bad "apt purge luma-session"
check "padrões /etc/xdg removidos" "$LAB" ssh '! test -e /etc/xdg/kdeglobals && ! test -e /etc/xdg/kscreenlockerrc'
check "luma-theme continua instalado" "$LAB" ssh 'dpkg -s luma-theme >/dev/null'
check_eq "escolha do usuário mantida" LumaDark "$(cfg General ColorScheme)"

echo "falhas: $fails"
exit $((fails > 0))
