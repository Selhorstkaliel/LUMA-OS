#!/usr/bin/env bash
# Executa um teste gravando a saída e o código de retorno num log. uso: run-logged.sh LOG TESTE [VAR=valor...]
# (o "$?" não pode ir na linha de comando do wsl.exe: ele é expandido antes de chegar ao bash)
set -uo pipefail
log="$1"; test="$2"; shift 2
mkdir -p "$(dirname "$log")"
env "$@" "$(dirname "$0")/$test" > "$log" 2>&1
rc=$?
echo "exit=$rc" >> "$log"
exit $rc
