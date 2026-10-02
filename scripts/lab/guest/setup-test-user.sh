#!/usr/bin/env bash
# Executado como root DENTRO da VM de laboratório. uso: setup-test-user.sh [USUÁRIO] [admin]
# Cria a conta de teste com login automático no SDDM (somente laboratório: nunca vai para pacotes
# do produto) e acesso SSH por chave. Se /tmp/test-user-password existir, define essa senha
# (aleatória, gerada pelo laboratório) e apaga o arquivo; senão a senha fica bloqueada.
set -euo pipefail
U="${1:-teste}"
id "$U" >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Conta de teste" "$U"
# "admin": membro do grupo sudo, a identidade de administrador do polkit no Debian
if [ "${2:-}" = admin ]; then usermod -aG sudo "$U"; fi
if [ -s /tmp/test-user-password ]; then
	printf '%s:%s\n' "$U" "$(cat /tmp/test-user-password)" | chpasswd
	rm -f /tmp/test-user-password
else
	passwd -l "$U" >/dev/null
fi
install -d -m 0700 -o "$U" -g "$U" "/home/$U/.ssh"
install -m 0600 -o "$U" -g "$U" /home/luma/.ssh/authorized_keys "/home/$U/.ssh/authorized_keys"
# Somente laboratório: sem bloqueio automático nem escurecimento da tela durante os testes
install -d -o "$U" -g "$U" "/home/$U/.config"
printf '[Daemon]
Autolock=false
LockOnResume=false
' > "/home/$U/.config/kscreenlockerrc"
printf '[AC][Display]
DimDisplayWhenIdle=false
TurnOffDisplayWhenIdle=false
[AC][SuspendAndShutdown]
AutoSuspendAction=0
' > "/home/$U/.config/powerdevilrc"
chown "$U:$U" "/home/$U/.config/kscreenlockerrc" "/home/$U/.config/powerdevilrc"
# Somente laboratório: a conta "luma" (SSH dos testes) sai do grupo audio. Nesse grupo, o WirePlumber
# dela acessa a placa mesmo fora do assento e aplica o próprio volume no mixer de hardware, sobrescrevendo
# o do usuário em teste (causa do falso bloqueio E4-06; docs/evidence/etapa4/bloqueio-volume/README.md).
gpasswd -d luma audio >/dev/null 2>&1 || true
install -d /etc/sddm.conf.d
# Relogin=true: refaz o login automático após logout ou 'systemctl restart sddm' (usado nos testes)
printf '[Autologin]\nUser=%s\nSession=plasma.desktop\nRelogin=true\n' "$U" > /etc/sddm.conf.d/zz-luma-lab-autologin.conf
cat > /usr/local/bin/luma-lab-sessenv <<'ENV'
# Variáveis para comandos via SSH alcançarem a sessão gráfica do usuário
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY=wayland-0
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
export QT_QPA_PLATFORM=wayland
# A sessão Plasma inclui ~/.config/kdedefaults em XDG_CONFIG_DIRS; sem isso, valores iguais ao
# padrão do Look-and-Feel parecem ausentes para kreadconfig6 (ver docs/evidence/etapa2/falha4*)
# O mesmo vale para XDG_CURRENT_DESKTOP (associações), XDG_MENU_PREFIX (KService) etc.: importa o
# ambiente inteiro da sessão, exceto variáveis do próprio shell.
_luma_pid="$(pgrep -u "$(id -u)" -x plasmashell | head -n1)"
if [ -n "$_luma_pid" ]; then
	while IFS= read -r _luma_var; do export "$_luma_var"; done < <(tr '\0' '\n' < "/proc/$_luma_pid/environ" |
		grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | grep -v -E '^(PWD|OLDPWD|SHLVL|_|SSH_[A-Z_]*)=')
fi
unset _luma_pid _luma_var
ENV
# Consulta de janelas via script KWin (saída JSON no journal do usuário)
cat > /usr/local/bin/luma-lab-windows <<'WIN'
#!/bin/bash
# Imprime JSON com tamanho lógico da tela e janelas normais (classe, título, geometria, estados).
set -eu
. /usr/local/bin/luma-lab-sessenv
js="$(mktemp --suffix=.js)"; tag="lumaq$$"
cat > "$js" <<'JS'
const area = w => workspace.clientArea(KWin.MaximizeArea, w);
const ws = workspace.windowList().filter(w => w.normalWindow && w.resourceClass !== "xwaylandvideobridge").map(w => {
  const g = w.frameGeometry, a = area(w);
  return {cls: w.resourceClass, title: w.caption, minimized: w.minimized, active: workspace.activeWindow === w,
          x: g.x, y: g.y, w: g.width, h: g.height,
          maximized: Math.abs(g.x - a.x) < 2 && Math.abs(g.y - a.y) < 2 && Math.abs(g.width - a.width) < 2 && Math.abs(g.height - a.height) < 2};
});
print("LUMAQ " + JSON.stringify({screen: {w: workspace.virtualScreenSize.width, h: workspace.virtualScreenSize.height}, windows: ws}));
JS
since="$(date '+%Y-%m-%d %H:%M:%S')"
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$js" "$tag" >/dev/null
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 1
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$tag" >/dev/null
rm -f "$js"
journalctl --user --since "$since" -o cat | sed -n 's/^js: LUMAQ //p' | tail -n1
WIN
chmod 0755 /usr/local/bin/luma-lab-windows
systemctl restart sddm
