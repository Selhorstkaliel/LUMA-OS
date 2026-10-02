# Execução 1 (ISO 0.7.0): 3 falhas

- "fuso inicial… sem GeoIP": erro da verificação (casava com o comentário do arquivo). Verificação corrigida.
- "sem restos do instalador": `/etc/calamares/branding/luma` e `modules/locale.conf` ficaram no sistema instalado. Corrigido na 0.7.1 (passo `luma-cleanup`).
- "sistema não voltou ao login após o modo de recuperação": o sistema voltou (captura e9-08-apos-enter.png); o agente QEMU é que não responde depois dessa transição. Verificação refeita (estado conferido antes do Enter, tela depois).
