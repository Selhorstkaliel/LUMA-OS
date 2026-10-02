#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 2: instala luma-theme numa VM limpa, aplica claro/escuro numa conta de teste, abre apps reais,
# muda resolução/escala, testa teclado e remove o pacote. Capturas em docs/evidence/etapa2.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa2}"
TEST_USER=teste
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
DEB="${DEB:-$LAB_DIR/debs/luma-theme_$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)_all.deb}"
appletsrc='.config/plasma-org.kde.plasma.desktop-appletsrc'  # relativo ao home remoto
[ -f "$DEB" ] || { echo "pacote $DEB ausente; rode scripts/build/build-debs.sh" >&2; exit 2; }

fresh_vm

# E2-02 instalação
"$LAB" ssh 'cat > /tmp/luma-theme.deb' < "$DEB"
setup_user ""   # sem senha: conta de teste só com login automático
root_cmd 'apt-get install -y /tmp/luma-theme.deb' > "$EV/E2-02-apt-install.log" 2>&1 && ok "apt instala luma-theme" || bad "apt instala luma-theme"
wait_plasma && ok "sessão Plasma da conta teste iniciou" || { bad "sessão Plasma não iniciou"; exit 1; }
sleep 10
check "Look-and-Feel claro listado"  u 'plasma-apply-lookandfeel --list | grep -qx org.luma.desktop'
check "Look-and-Feel escuro listado" u 'plasma-apply-lookandfeel --list | grep -qx org.luma.dark.desktop'
check "esquemas de cores listados"   u 'plasma-apply-colorscheme --list-schemes | grep -q LumaLight && plasma-apply-colorscheme --list-schemes | grep -q LumaDark'
shot E2-02-antes-breeze 2

# E2-03 aplicar tema claro com layout
u 'luma-appearance claro --reset-layout' >"$EV/E2-03-apply.log" 2>&1 && ok "luma-appearance claro --reset-layout" || bad "luma-appearance claro --reset-layout"
sleep 12
check_eq "ColorScheme=LumaLight" LumaLight "$(cfg General ColorScheme)"
check "LookAndFeelPackage gravado"   u 'test "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" = org.luma.desktop'
check "dois painéis no layout"       u "test \"\$(grep -c '^plugin=org.kde.panel' $appletsrc)\" = 2"
check "dock com icontasks e favoritos" u "grep -q '^plugin=org.kde.plasma.icontasks' $appletsrc && grep -q 'launchers=applications:org.kde.dolphin.desktop' $appletsrc"
check "dock flutuante e ajustado ao conteúdo" u 'grep -q "^floating=1" ~/.config/plasmashellrc && grep -q "^panelLengthMode=1" ~/.config/plasmashellrc'
check "wallpaper Luma aplicado"      u "grep -q '^Image=file:///usr/share/wallpapers/Luma' $appletsrc"
check_eq "ícones Papirus" Papirus "$(cfg Icons Theme)"
check_eq "decoração Luma (botões à esquerda)" "__aurorae__svg__Luma" "$(cfg org.kde.kdecoration2 theme VAZIO kwinrc)"
check_eq "botões fechar/minimizar/maximizar à esquerda" XIA "$(cfg org.kde.kdecoration2 ButtonsOnLeft VAZIO kwinrc)"
u 'cat ~/.config/plasmashellrc' > "$EV/E2-03-plasmashellrc.txt" 2>&1
shot E2-03-claro-1920x1080 4

# E2-04 apps reais
u 'for a in dolphin konsole systemsettings; do setsid -f $a >/dev/null 2>&1; done'
sleep 20
for a in dolphin konsole systemsettings; do check "$a em execução" u "pgrep -x $a"; done
shot E2-04-apps-claro 2

# E2-05 alternar para escuro (sem trocar layout)
u 'luma-appearance escuro' >>"$EV/E2-03-apply.log" 2>&1 && ok "luma-appearance escuro" || bad "luma-appearance escuro"
check "uso incorreto retorna 64"     u 'luma-appearance azul; test $? = 64'
sleep 10
check_eq "ColorScheme=LumaDark" LumaDark "$(cfg General ColorScheme)"
check_eq "ícones Papirus-Dark" Papirus-Dark "$(cfg Icons Theme)"
check_eq "decoração Luma escura" "__aurorae__svg__LumaEscuro" "$(cfg org.kde.kdecoration2 theme VAZIO kwinrc)"
check "layout mantido ao alternar"   u "test \"\$(grep -c '^plugin=org.kde.panel' $appletsrc)\" = 2"
shot E2-05-apps-escuro 4

# E2-06 resolução 1366x768. O EDID do virtio-gpu não oferece 1366x768 (ver E2-06-kscreen.txt), então a VM
# é reiniciada com 1366x768 como modo nativo; o login automático reabre a sessão (testa também persistência).
u 'pkill -x konsole; pkill -x dolphin; pkill -x systemsettings' || true
u 'kscreen-doctor -o' > "$EV/E2-06-kscreen.txt" 2>&1
VM_XRES=1366 VM_YRES=768 reboot_vm; wait_plasma || bad "sessão não voltou em 1366x768"
sleep 15
res_is() { u "kscreen-doctor -j | python3 -c 'import json,sys; o=json.load(sys.stdin)[\"outputs\"][0]; m=[x for x in o[\"modes\"] if x[\"id\"]==o[\"currentModeId\"]][0][\"size\"]; assert (m[\"width\"],m[\"height\"])==($1,$2), m'"; }
check "modo 1366x768 ativo"                 res_is 1366 768
u 'cat ~/.config/kdeglobals' > "$EV/E2-06-kdeglobals-apos-reinicio.txt" 2>&1
check_eq "tema escuro persistiu após reinício" LumaDark "$(cfg General ColorScheme)"
u 'setsid -f dolphin >/dev/null 2>&1'; shot E2-06-escuro-1366x768 10
u 'luma-appearance claro' >/dev/null 2>&1; shot E2-06-claro-1366x768 6
u 'pkill -x dolphin' || true
reboot_vm; wait_plasma || bad "sessão não voltou em 1920x1080"
sleep 15
OUT="$(u 'kscreen-doctor -j' 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["outputs"][0]["name"])' 2>/dev/null)"
u "kscreen-doctor output.$OUT.mode.1920x1080@60" >/dev/null 2>&1; sleep 6
check "modo 1920x1080 ativo"                res_is 1920 1080

# E2-07 escala 150%
u "kscreen-doctor output.$OUT.scale.1.5" >/dev/null 2>&1; sleep 6
check "escala 1,5 ativa" u "kscreen-doctor -j | python3 -c 'import json,sys; assert abs(json.load(sys.stdin)[\"outputs\"][0][\"scale\"]-1.5)<0.01'"
shot E2-07-claro-escala150 2
u "kscreen-doctor output.$OUT.scale.1" >/dev/null 2>&1; sleep 6

# E2-08 teclado: Meta abre o lançador, digitar e Enter abre o app; Alt+Tab alterna
u 'pkill -x konsole; pkill -x dolphin; pkill -x systemsettings' || true
sleep 3
"$LAB" key meta_l;             shot E2-08-meta-lancador 3
"$LAB" key k o n s o l e;      shot E2-08-busca-konsole 3
"$LAB" key ret; sleep 8
check "Konsole aberto só com teclado" u 'pgrep -x konsole'
u 'setsid -f dolphin >/dev/null 2>&1'; sleep 8
"$LAB" key alt-tab;            shot E2-08-alt-tab 1

# E2-09 remoção
root_cmd 'apt-get remove -y luma-theme' > "$EV/E2-09-apt-remove.log" 2>&1 && ok "apt remove luma-theme" || bad "apt remove luma-theme"
check "arquivos do tema removidos"    "$LAB" ssh '! ls -d /usr/share/plasma/look-and-feel/org.luma.* /usr/share/color-schemes/Luma*.colors /usr/share/wallpapers/Luma 2>/dev/null | grep -q .'
check "tema não listado após remoção" u '! plasma-apply-lookandfeel --list | grep -q org.luma'
root_cmd 'systemctl restart sddm' >/dev/null 2>&1
sleep 10
wait_plasma && ok "nova sessão inicia sem o tema" || bad "sessão não inicia após remoção"
sleep 20
check "plasmashell estável 20 s após login" u 'pgrep -x plasmashell'
shot E2-09-apos-remocao 2

echo "falhas: $fails"
exit $((fails > 0))
