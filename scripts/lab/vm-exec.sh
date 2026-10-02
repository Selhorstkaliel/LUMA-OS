#!/usr/bin/env bash
# Executa um script local dentro da VM via SSH (evita problemas de aspas do wsl.exe).
# uso: vm-exec.sh ARQUIVO.sh [--sudo]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lab/config.sh
. "$HERE/config.sh"
script="${1:?uso: vm-exec.sh ARQUIVO.sh [--sudo]}"
"$HERE/lab.sh" wait-ssh 600 >/dev/null
if [ "${2:-}" = "--sudo" ]; then
	# A senha segue pelo stdin do sudo; o script vai por um arquivo temporário na VM.
	"$HERE/lab.sh" ssh 'cat > /tmp/vm-exec.sh' < "$script"
	# shellcheck disable=SC2016  # $? avaliado na VM
	"$HERE/lab.sh" ssh 'sudo -S -p "" bash /tmp/vm-exec.sh; rc=$?; rm -f /tmp/vm-exec.sh; exit $rc' < "$LAB_DIR/secrets/luma-password"
else
	"$HERE/lab.sh" ssh 'bash -s' < "$script"
fi
