# 0005 — Receita da ISO live

Status: aceita (etapa 8), 2026-09-30.

## Decisão
- live-build 1:20250505+deb13u1 em Debian trixie (WSL do laboratório), receita versionada em `live/`; build sempre em diretório novo por `scripts/build/build-iso.sh`, com cache de pacotes separado.
- ISO híbrida, somente UEFI (`--bootloaders grub-efi`), `--uefi-secure-boot enable` (shim e GRUB assinados pelo Debian). Suporte a Secure Boot só será afirmado depois do boot com Secure Boot ativo na VM (OVMF com chaves Microsoft).
- Áreas `main contrib non-free-firmware` e firmware do live-build (`--firmware-chroot/--firmware-binary`), como as ISOs live oficiais do Debian, para funcionar em hardware real.
- Pacotes: `task-kde-desktop`, tarefas pt-BR, Calamares e os pacotes Luma locais (`luma-theme`, `luma-session`, `luma-firewall`, `luma-ajustes`, `luma-live`). Desde a 0.7.0 também os pacotes de boot e a configuração do instalador (decisão 0006).
- `qemu-guest-agent` e `spice-vdagent` incluídos: só ativam com canal virtio/SPICE (VMs) e permitem verificar a ISO exata que será distribuída, sem imagem "de teste" diferente. Um host de VM já controla o convidado; o agente não cria acesso novo em hardware real.
- Sessão live: usuário `luma` do live-config com login automático; nada persiste. O sistema instalado usa a senha escolhida no instalador (não há senha padrão permanente).
- Menu de boot: modelos do GRUB do live-build copiados para `live/config/bootloaders/grub-pc/` com uma única mudança, `set timeout=10` (o padrão aguarda Enter para sempre, o que impede boot sem interação).
- Identidade: `os-release` continua Debian (a ISO é uma derivada sem rebranding do sistema base no MVP).

## Evidências e reprodutibilidade
Cada build gera `luma-<versão>-amd64.iso`, `.sha256`, `.packages` (manifesto), `.manifest` e `.build.log`. Dois builds são comparados pelo manifesto; não se alega reprodutibilidade bit a bit.
