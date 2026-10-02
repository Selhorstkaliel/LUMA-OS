#!/usr/bin/env bash
# E1-06: lab.sh deve falhar com código 2 e mensagem clara quando falta dependência.
set -u
LAB="$(dirname "$0")/../lab.sh"
fail=0
expect() { # descrição, código esperado, comando...
	local d="$1" want="$2"; shift 2
	local out rc
	out="$("$@" 2>&1)"; rc=$?
	if [ "$rc" = "$want" ]; then echo "PASSOU: $d (exit $rc) :: ${out##*$'\n'}"; else echo "FALHOU: $d (exit $rc, esperado $want) :: $out"; fail=1; fi
}
expect "qemu ausente"       2  env QEMU=/nao/existe/qemu "$LAB" check
expect "OVMF ausente"       2  env OVMF_DIR=/nao/existe "$LAB" check
expect "xorriso ausente"    2  env XORRISO=/nao/existe/xorriso "$LAB" check
expect "ambiente completo"  0  "$LAB" check
expect "comando inválido"   64 "$LAB" nao-existe
exit $fail
