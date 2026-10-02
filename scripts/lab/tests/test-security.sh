#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2317  # ok/bad nunca falham; comandos remotos em aspas simples de propósito; cleanup via trap
# Etapa 7: controles de segurança verificáveis em VM.
#  - usuário comum não modifica o sistema; ações privilegiadas negadas;
#  - firewall luma-firewall: entrada bloqueada (teste diferencial com regra temporária);
#  - APT rejeita repositório com chave não confiável e com índice adulterado (controle positivo incluído);
#  - recuperação após falha controlada (energia cortada durante o dpkg);
#  - cobertura real de confinamento (AppArmor/Flatpak) registrada, sem promessas.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="${EVIDENCE:-$HERE/../../../docs/evidence/etapa7}"
TEST_USER=teste
# shellcheck source=scripts/lab/tests/lib.sh
. "$HERE/lib.sh"
V="$(dpkg-parsechangelog -l "$HERE/../../../debian/changelog" -S Version)"
REPOS="$LAB_DIR/fixtures/repos"
"$HERE/../fixtures/make-test-repo.sh" "$REPOS" > "$EV/E7-00-fixtures.log" 2>&1 || { echo "falha ao gerar repositórios de teste" >&2; exit 2; }
http_ok() { curl -s -m 5 -o /dev/null "http://127.0.0.1:$VM_HTTP_PORT/"; }

fresh_vm
for p in luma-theme luma-session luma-firewall; do "$LAB" ssh "cat > /tmp/$p.deb" < "$LAB_DIR/debs/${p}_${V}_all.deb"; done
# Laboratório: libera o SSH ANTES do firewall (o produto não instala servidor SSH)
root_cmd 'apt-get install -y ufw >/dev/null && ufw allow 22/tcp comment "somente laboratorio: ssh"' > "$EV/E7-00-apt.log" 2>&1 || bad "preparar ufw do laboratório"
root_cmd 'apt-get install -y /tmp/luma-theme.deb /tmp/luma-session.deb /tmp/luma-firewall.deb' >> "$EV/E7-00-apt.log" 2>&1 && ok "instalar luma-firewall" || bad "instalar luma-firewall"
setup_user ""
wait_desktop || bad "área de trabalho não ficou pronta"

# ---------- E7-01 firewall ----------
fw="$(root_cmd 'LANG=C ufw status verbose' 2>/dev/null)"; printf '%s\n' "$fw" > "$EV/E7-01-ufw-status.txt"
grep -q '^Status: active' <<<"$fw" && ok "ufw ativo após instalar luma-firewall" || bad "ufw inativo"
grep -q 'deny (incoming)' <<<"$fw" && ok "política padrão: entrada bloqueada" || bad "política de entrada ($fw)"
check "serviço de política não roda de novo" "$LAB" ssh 'test -e /var/lib/luma-firewall/aplicado'
u 'cd /tmp && setsid -f python3 -m http.server 8080 >/dev/null 2>&1'; sleep 3
# curl não faz parte da instalação base: consulta com python3 (falha1)
check "serviço local responde dentro da VM" u 'python3 -c "import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8080/\", timeout=3)"'
http_ok && bad "porta 8080 acessível de fora com firewall ativo" || ok "porta 8080 bloqueada de fora"
root_cmd 'ufw allow 8080/tcp' >/dev/null 2>&1
http_ok && ok "controle: com regra temporária a porta abre (bloqueio vinha do firewall)" || bad "controle: porta não abriu com a regra"
root_cmd 'ufw delete allow 8080/tcp' >/dev/null 2>&1
http_ok && bad "regra temporária não foi removida" || ok "regra temporária removida: porta volta a bloquear"
u 'pkill -f "http.server 8080"' || true
reboot_vm; wait_desktop || bad "sessão após reinício"
st="$(root_cmd 'LANG=C ufw status' 2>/dev/null | head -n1)"
[ "$st" = "Status: active" ] && ok "firewall com regras ativas após reinício" || bad "firewall após reinício ('$st')"

# ---------- E7-02 usuário comum não modifica o sistema ----------
check "sem gravação em /etc"                      u '! touch /etc/luma-teste 2>/dev/null'
check "sem gravação em /usr"                      u '! touch /usr/luma-teste 2>/dev/null'
check "sudo negado para usuário comum"            u '! sudo -n true 2>/dev/null'
check "parar serviço do sistema negado (polkit)"  u '! systemctl stop NetworkManager 2>/dev/null && systemctl is-active --quiet NetworkManager'
check "desativar firewall negado"                 u '! ufw disable 2>/dev/null'
check "instalar pacote negado sem autenticação"   u '! pkcon -y -p install kpat >/dev/null 2>&1 && ! dpkg -s kpat >/dev/null 2>&1'

# ---------- E7-03 fontes assinadas ----------
tar -C "$REPOS" -czf - bom chave-errada adulterado confiavel.gpg | "$LAB" ssh 'cat > /tmp/repos.tgz'
root_cmd 'rm -rf /srv/luma-teste-repos && mkdir -p /srv/luma-teste-repos && tar -C /srv/luma-teste-repos -xzf /tmp/repos.tgz && install -m 644 /srv/luma-teste-repos/confiavel.gpg /usr/share/keyrings/luma-teste.gpg' >/dev/null 2>&1
apt_repo() { # $1 = variante; saída: log do update + resultado da instalação
	root_cmd "rm -f /var/lib/apt/lists/*luma-teste-repos*
echo 'deb [signed-by=/usr/share/keyrings/luma-teste.gpg] file:/srv/luma-teste-repos/$1 ./' > /etc/apt/sources.list.d/luma-teste.list
LANG=C apt-get update -o Dir::Etc::SourceList=/etc/apt/sources.list.d/luma-teste.list -o Dir::Etc::SourceParts=- 2>&1
echo \"UPDATE_RC=\$?\"
LANG=C apt-get install -y luma-teste-assinatura 2>&1; echo \"INSTALL_RC=\$?\"
dpkg -s luma-teste-assinatura >/dev/null 2>&1 && echo INSTALADO || echo NAO_INSTALADO
apt-get remove -y luma-teste-assinatura >/dev/null 2>&1; rm -f /etc/apt/sources.list.d/luma-teste.list"
}
out="$(apt_repo bom)"; printf '%s\n' "$out" > "$EV/E7-03-repo-bom.log"
grep -q '^INSTALADO' <<<"$out" && ok "controle: repositório com chave confiável instala" || bad "controle: repositório bom não instalou"
out="$(apt_repo chave-errada)"; printf '%s\n' "$out" > "$EV/E7-03-repo-chave-errada.log"
grep -q '^NAO_INSTALADO' <<<"$out" && grep -q -E 'NO_PUBKEY|not signed|is not signed|could not be verified' <<<"$out" \
	&& ok "chave não confiável rejeitada" || bad "chave não confiável (ver log)"
out="$(apt_repo adulterado)"; printf '%s\n' "$out" > "$EV/E7-03-repo-adulterado.log"
grep -q '^NAO_INSTALADO' <<<"$out" && grep -q -i -E 'hash sum mismatch|unexpected size|Hashes' <<<"$out" \
	&& ok "índice adulterado rejeitado" || bad "índice adulterado (ver log)"
check "apt-secure: nenhuma fonte com trusted=yes/allow-insecure" "$LAB" ssh '! grep -r -E "trusted=yes|allow-insecure|AllowUnauthenticated" /etc/apt/ 2>/dev/null'
root_cmd 'rm -f /usr/share/keyrings/luma-teste.gpg; rm -rf /srv/luma-teste-repos; rm -f /var/lib/apt/lists/*luma-teste-repos*' >/dev/null 2>&1

# ---------- E7-04 recuperação após falha controlada ----------
# Energia cortada com um pacote em "half-configured" (estado real do dpkg, confirmado antes do corte).
# Tentativas por tempo (reinstalar pacotes grandes) não eram determinísticas: falha1/falha2/falha3.
rp="$("$HERE/../fixtures/make-recovery-pkg.sh" "$LAB_DIR/fixtures")"
"$LAB" ssh 'cat > /tmp/luma-teste-recuperacao.deb' < "$rp"
printf '%s\n' "LANG=C nohup dpkg -i /tmp/luma-teste-recuperacao.deb > /var/tmp/recuperacao.log 2>&1 &" > "$T/bg.sh"
as_root "$T/bg.sh" >/dev/null 2>&1
st=""
for _ in $(seq 1 60); do
	st="$("$LAB" ssh "dpkg-query -W -f='\${Status}' luma-teste-recuperacao 2>/dev/null")"
	[ "$st" = "install ok half-configured" ] && break; sleep 1
done
[ "$st" = "install ok half-configured" ] && ok "pacote em configuração (half-configured) antes do corte" || bad "estado antes do corte: '$st'"
"$LAB" kill >/dev/null && ok "energia cortada durante a configuração do pacote" || bad "corte de energia"
boot_vm && ok "sistema volta a iniciar após o corte" || bad "sistema não iniciou após o corte"
audit="$(root_cmd 'dpkg --audit' 2>&1)"; printf '%s\n' "$audit" > "$EV/E7-04-dpkg-audit-antes.txt"
grep -q luma-teste-recuperacao <<<"$audit" && ok "falha induzida: dpkg --audit aponta o pacote inconsistente" || bad "falha não induzida (dpkg --audit: '$audit')"
root_cmd "dpkg --configure -a && apt-get -f install -y" > "$EV/E7-04-recuperacao.log" 2>&1 && ok "procedimento de recuperação executado (docs/usuario/recuperacao.md)" || bad "recuperação falhou (ver log)"
check_eq "pacote configurado após recuperação" "install ok installed" "dpkg-query -W -f='\${Status}' luma-teste-recuperacao"
check "dpkg --audit limpo após recuperação" "$LAB" ssh 'test -z "$(dpkg --audit 2>&1)"'
ck="$(root_cmd 'apt-get check 2>&1; echo RC=$?' 2>&1)"; printf '%s\n' "$ck" > "$EV/E7-04-apt-check.txt"
grep -q '^RC=0$' <<<"$ck" && ok "apt-get check sem erros (root)" || bad "apt-get check (ver E7-04-apt-check.txt)"
wait_desktop && ok "sessão gráfica funcional após recuperação" || bad "sessão gráfica após recuperação"
root_cmd 'apt-get purge -y luma-teste-recuperacao' >/dev/null 2>&1
shot E7-04-apos-recuperacao 1

# ---------- E7-05 cobertura real de confinamento (registro, não promessa) ----------
aa="$(root_cmd 'aa-status 2>/dev/null' 2>&1)"; printf '%s\n' "$aa" > "$EV/E7-05-aa-status.txt"
n="$(grep -m1 -oE '^[0-9]+ profiles are in enforce mode' <<<"$aa" | cut -d' ' -f1)"
[ -n "$n" ] && ok "AppArmor ativo: $n perfis em modo enforce" || bad "AppArmor sem perfis em enforce"
echo "info: apps Flatpak instalados: $(u 'flatpak list --app --columns=application 2>/dev/null | wc -l')"
echo "info: apps nativos (APT) NÃO são confinados por padrão; ver docs/security/modelo-de-ameacas.md"

echo "falhas: $fails"
exit $((fails > 0))
