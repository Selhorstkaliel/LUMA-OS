# 0006 — Instalador (Calamares)

Status: aceita (etapa 9), 2026-10-01. Pontos em aberto no fim.

## Decisão
- Instalador existente: Calamares 3.3.14 do Debian com os módulos auxiliares do `calamares-settings-debian` 13.0.13 (mesma sequência das imagens live oficiais do Debian). Nenhum código próprio de particionamento, cópia ou bootloader.
- Configuração Luma em `live/config/includes.chroot/etc/calamares/` (sobrepõe os arquivos do pacote Debian só na imagem live):
  - marca `luma` (nome, logotipo, cores); `bootloaderEntryName` continua `Debian` porque o shim/GRUB assinados procuram a configuração em `EFI/debian` — trocar quebraria o Secure Boot;
  - `users.conf` sem o grupo `audio` (requisito herdado da etapa 4); root sem senha (bloqueado), administração por `sudo`; sem senha padrão;
  - `locale.conf`: fuso inicial America/Sao_Paulo e sem GeoIP (o instalador não consulta a rede; o padrão era New York com formatos en_US);
  - `packages.conf`: remove do sistema instalado os pacotes live, o `luma-live` e o próprio Calamares.
- Pacote `luma-live` (só na imagem; removido na instalação):
  - componente do live-config que desliga bloqueio automático de tela e suspensão **na sessão live** (a sessão bloqueava no meio da instalação pedindo uma senha que o usuário não conhece);
  - passo `luma-efi-fallback` depois do bootloader: `grub-install --force-extra-removable` e a opção debconf correspondente. O Calamares copiava só o shim para `EFI/BOOT`; sem o GRUB ao lado o disco não iniciava quando a entrada de boot da NVRAM se perdia (reproduzido na VM).
  - passo `luma-cleanup` no fim: apaga `/etc/calamares` do sistema instalado (a marca e o `locale.conf` não pertencem a pacote nenhum e sobravam depois da remoção do instalador).
- Pacotes de boot na imagem (`grub-efi`, `grub-efi-amd64-signed`, `shim-signed`, `efibootmgr`, `cryptsetup-initramfs`): o auxiliar do Debian roda `apt-get install grub-efi` no destino; sem eles na imagem a instalação dependia de internet para ter bootloader. `util-linux-extra` para o `hwclock`.
- Atalho "Instalar o Luma" e script de atalho próprios: o script do Debian usa o caminho sem aspas e, em pt_BR, criava as pastas `Área`, `de` e `trabalho`. O script chama `xdg-user-dirs-update` antes de localizar a área de trabalho, porque os dois iniciam na mesma fase do login.

## Recuperação
- O "recovery mode" do GRUB não dá shell: com root bloqueado o `sulogin` recusa ("a conta root está travada") e Enter segue para o login normal. Comportamento mantido (não há acesso de root sem senha pela tela).
- Caminho oficial de recuperação: iniciar pela ISO/pendrive do Luma e consertar por chroot (`docs/usuario/recuperacao.md`), testado com redefinição de senha.

## Limites
- O log do Calamares (`/root/.cache/calamares/session.log`, só na sessão live, em RAM) registra o hash da senha da conta criada. O teste confere que ele não é copiado para o sistema instalado e mascara o hash nas evidências.
- Instalação com disco cifrado: a senha do disco é pedida uma vez, pelo GRUB, no boot (versão do LUKS não verificada). A cópia levou cerca do dobro do tempo na VM.
- Somente UEFI x86_64 (decisão 0005). Dual boot ("instalar lado a lado", "substituir partição") e particionamento manual existem no Calamares mas **não foram testados**.
- `sources.list` do sistema instalado é o gerado pelo auxiliar do Debian (main + non-free-firmware, com backports habilitado).
- Tela de login (SDDM), tela de bloqueio (avatar) e menu do GRUB ainda mostram a identidade Debian.

## Em aberto (decisão do usuário)
- Dar shell de root sem senha no "recovery mode" (como o Ubuntu faz) facilitaria a recuperação, mas qualquer pessoa com acesso ao teclado na hora do boot viraria root. Padrão atual: não.
