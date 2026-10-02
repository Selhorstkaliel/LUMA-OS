#!/usr/bin/env bash
# Verificações leves (E1-07): sintaxe e ShellCheck de todos os scripts shell; YAML/QML entram quando existirem.
set -euo pipefail
cd "$(dirname "$0")/../.."
mapfile -t files < <(git ls-files -co --exclude-standard -- '*.sh' 'theme/bin/*' 'security/firewall/luma-firewall-setup' 'live/auto/*' 'apps/ajustes/data/luma-ajustes' 'live-session/2000-luma-live-session' 'live-session/luma-efi-fallback' 'live-session/luma-installer-cleanup' 'windows/luma-windows-run' 'live/config/includes.chroot/usr/bin/*')
[ ${#files[@]} -gt 0 ] || { echo "nenhum script"; exit 0; }
rc=0
for f in "${files[@]}"; do bash -n "$f" || { echo "sintaxe: $f"; rc=1; }; done
shellcheck -x "${files[@]}" || rc=1
# shellcheck disable=SC2016  # \$ literal no padrão de hash crypt
if grep -rIl --exclude-dir=.git -E 'BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|\$6\$[./A-Za-z0-9]{8,}|\$y\$j9T\$[./A-Za-z0-9]{8,}' . ; then echo "possível segredo no repositório"; rc=1; fi
# Só sintaxe (ast), sem gravar __pycache__ na árvore
python3 -B -c "import ast,sys; [ast.parse(open(f,encoding='utf-8').read(), f) for f in sys.argv[1:]]" apps/ajustes/luma_ajustes/*.py theme/tools/*.py || rc=1
[ $rc -eq 0 ] && echo "lint OK (${#files[@]} scripts)"
exit $rc
