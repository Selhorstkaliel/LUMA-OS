#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 5: aplicativos Linux pela loja existente (Discover/PackageKit sobre APT assinado do Debian),
# instalar/abrir/atualizar/remover com autenticação polkit real, documentos com espaços e acentos,
# associações de arquivo, permissões entre usuários e suporte a Flatpak/portais.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa5}"
TEST_USER=novo
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
V="$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)"
PW="$LAB_DIR/secrets/novo-password"
[ -s "$PW" ] || (umask 077; tr -dc 'a-z0-9' < /dev/urandom | head -c 16 > "$PW")
APP=kpat                                    # app pequeno do Debian, fora da instalação padrão
OLD_FLATPAK=1.16.6-1~deb13u2                # versão do ponto de lançamento; a de trixie-security é mais nova
DOC='Documentos/Relatório de teste.txt'     # espaço e acento no caminho
installed() { "$LAB" ssh "dpkg-query -W -f='\${Status}' $1 2>/dev/null | grep -q 'install ok installed'"; }
not_installed() { ! installed "$1"; }
wait_for() { local n="$1"; shift; for _ in $(seq 1 "$n"); do "$@" >/dev/null 2>&1 && return 0; sleep 3; done; return 1; }

fresh_vm
for p in luma-theme luma-session; do "$LAB" ssh "cat > /tmp/$p.deb" < "$LAB_DIR/debs/${p}_${V}_all.deb"; done
root_cmd 'apt-get install -y /tmp/luma-theme.deb /tmp/luma-session.deb' > "$EV/E5-00-apt-install.log" 2>&1 || bad "instalar pacotes Luma"
# Cenário de atualização real: volta o flatpak para a versão do lançamento pontual (existe no arquivo do Debian)
root_cmd "apt-get update -qq && apt-get install -y --allow-downgrades flatpak=$OLD_FLATPAK" >> "$EV/E5-00-apt-install.log" 2>&1 \
	&& ok "cenário de atualização: flatpak $OLD_FLATPAK instalado" || bad "preparar cenário de atualização"
setup_user "$PW" admin
wait_desktop || { bad "área de trabalho não ficou pronta"; exit 1; }
u 'pkill -f plasma-welcome' || true
echo "info: $(u 'pkcon --version 2>/dev/null | head -1; plasma-discover --version 2>/dev/null')"

# E5-01 acesso negado: sessão SSH remota não instala, mesmo sendo administrador (sem agente polkit)
VM_USER="$TEST_USER" timeout 90 "$LAB" ssh "pkcon -y -p install $APP" > "$EV/E5-01-negado.log" 2>&1
installed "$APP" && bad "instalação pela sessão remota não foi negada" || ok "sessão remota: instalação negada pelo polkit"

# E5-02 instalar pela sessão local com autenticação de administrador
# Sem -y: "--noninteractive" do pkcon proíbe a interação do polkit (falha1: "Failed to obtain authentication")
# Confirma "[N/y]" só se o diálogo polkit ainda não abriu (senão o "y" iria para o campo de senha)
pk() { session_cmd "LANG=C pkcon $1" 8; if ! polkit_open; then "$LAB" key y ret; sleep 3; fi; }
pk "install $APP"
shot E5-02-polkit 1
polkit_auth "$PW" 20 && ok "diálogo polkit pediu a senha do administrador" || bad "diálogo polkit não apareceu"
wait_for 80 installed "$APP" && ok "instalar $APP pela loja (PackageKit/APT)" || bad "instalar $APP"
shot E5-03-instalado 2

# E5-03 abrir o app instalado pelo lançador (KRunner)
"$LAB" key alt-spc; sleep 3; type_text "$APP"; "$LAB" key ret; sleep 10
check "abrir $APP" u "pgrep -x $APP"
shot E5-04-app-aberto 1
u "pkill -x $APP" || true

# E5-04 loja existente abre (Discover)
u 'setsid -f plasma-discover >/dev/null 2>&1'; sleep 25
check "Discover em execução" u 'pgrep -x plasma-discover'
shot E5-05-discover 1
u 'pkill -x plasma-discover' || true; sleep 2

# E5-05 atualizar
"$LAB" key alt-tab; sleep 1
pk update
polkit_auth "$PW" 20 || echo "info: sem novo diálogo polkit (autorização mantida)"
new="$(for _ in $(seq 1 100); do v="$("$LAB" ssh "dpkg-query -W -f='\${Version}' flatpak")"; [ "$v" != "$OLD_FLATPAK" ] && { echo "$v"; break; }; sleep 3; done)"
[ -n "$new" ] && ok "atualizar: flatpak $OLD_FLATPAK → $new" || bad "atualização não aplicada"
shot E5-06-atualizado 1

# E5-06 remover
if installed "$APP"; then
	pk "remove $APP"
	polkit_auth "$PW" 20 || echo "info: sem novo diálogo polkit (autorização mantida)"
	wait_for 60 not_installed "$APP" && ok "remover $APP" || bad "remover $APP"
else
	bad "remover $APP: não testado, o app não estava instalado"
fi
u 'pkill -x konsole' || true

# E5-07 documento com espaço e acento: abrir pela associação padrão, editar e salvar
u "mkdir -p Documentos && printf 'linha original\n' > \"$DOC\""
assoc="$(u 'xdg-mime query default text/plain')"
echo "info: text/plain → $assoc"
[ -n "$assoc" ] && u "test -n \"\$(find /usr/share/applications -name '$assoc')\"" && ok "associação text/plain → $assoc" || bad "associação text/plain ($assoc)"
u "grep -E '^(text/plain|application/pdf|image/png|inode/directory)=' /usr/share/applications/kde-mimeapps.list" > "$EV/E5-07-kde-mimeapps.txt" 2>&1
u "setsid -f xdg-open \"\$HOME/$DOC\" >/dev/null 2>&1"
title=""
for _ in $(seq 1 20); do
	title="$(windows | py "([w['title'] for w in d['windows'] if w['active']] or [''])[0]")"
	[[ "$title" == *"Relatório de teste.txt"* ]] && break; sleep 2
done
[[ "$title" == *"Relatório de teste.txt"* ]] && ok "arquivo com espaço/acento aberto ($title)" || bad "abrir documento (janela ativa: '$title')"
"$LAB" key ctrl-end; type_text " editado"; "$LAB" key ctrl-s; sleep 3
# Ctrl+End no Kate vai para depois da quebra de linha final: o texto entra na 2ª linha (falha3)
check_eq "salvar no mesmo caminho" "linha original| editado" "paste -sd'|' \"$DOC\""
shot E5-07-documento 1
"$LAB" key ctrl-shift-s; sleep 4; shot E5-08-salvar-como 0
"$LAB" key ctrl-a; type_text "copia final"; "$LAB" key ret; sleep 3
check "salvar como novo nome com espaço" u 'ls Documentos/ | grep -q "^copia final"'
"$LAB" key ctrl-q; sleep 2

# E5-08 associações de outros tipos comuns
for mt in application/pdf image/png inode/directory; do
	a="$(u "xdg-mime query default $mt")"
	[ -n "$a" ] && ok "associação $mt → $a" || bad "associação $mt vazia"
done

# E5-09 permissões: outro usuário (luma, via SSH, sem sudo) não lê os documentos de "novo"
check "home do usuário com modo 700" "$LAB" ssh "test \"\$(stat -c %a /home/$TEST_USER)\" = 700"
check "outro usuário não lê o documento" "$LAB" ssh "! cat \"/home/$TEST_USER/$DOC\" 2>/dev/null"

# E5-10 Flatpak e portais disponíveis (Flathub não pré-configurado: decisão 0004)
check "flatpak instalado" "$LAB" ssh 'command -v flatpak'
check "backend Flatpak do Discover" "$LAB" ssh 'dpkg-query -W -f="\${Status}" plasma-discover-backend-flatpak | grep -q "install ok"'
check "portal KDE disponível" "$LAB" ssh 'test -f /usr/share/xdg-desktop-portal/portals/kde.portal'
check "serviço de portais ativo na sessão" u 'systemctl --user is-active xdg-desktop-portal'
echo "info: remotos flatpak: $(u 'flatpak remotes --columns=name 2>/dev/null | tr "\n" " "')"

echo "falhas: $fails"
exit $((fails > 0))
