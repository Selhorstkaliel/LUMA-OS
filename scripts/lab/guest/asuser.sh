#!/bin/sh
# SOMENTE LABORATÓRIO. Executado como root na VM (via agente QEMU).
# uso: asuser.sh USUÁRIO COMANDO — roda COMANDO como USUÁRIO com o ambiente da sessão Plasma dele.
set -eu
u="$1"; shift
p="$(pgrep -u "$u" -x plasmashell | head -n1)"
[ -n "$p" ] || { echo "asuser: $u sem sessão Plasma" >&2; exit 3; }
uid="$(id -u "$u")"; gid="$(id -g "$u")"
# xargs acrescenta as variáveis da sessão (VAR=valor) depois dos argumentos fixos
# shellcheck disable=SC2016  # o script interno é expandido pelo sh -c, não aqui
exec xargs -0 -a "/proc/$p/environ" sh -c '
	uid="$1"; gid="$2"; cmd="$3"; shift 3
	exec env -i "$@" setpriv --reuid="$uid" --regid="$gid" --init-groups -- sh -c "cd; $cmd"
' sh "$uid" "$gid" "$*"
