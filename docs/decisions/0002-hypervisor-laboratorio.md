# 0002 — Hypervisor do laboratório

Status: **aceita** (etapa 1), 2026-09-30. Substitui a proposta inicial de Hyper-V.

## Contexto
Windows 11 Pro já roda sobre o hypervisor (WSL2/Docker). O papel Hyper-V não está habilitado e a sessão de trabalho não tem administrador. RAM do host: 7,7 GiB.

Achado da etapa 1: o WSL2 expõe `/dev/kvm` (virtualização aninhada, padrão em Intel no Windows 11). Verificado com `ls -l /dev/kvm` na distro Debian do WSL.

## Decisão
**QEMU 10.0 + KVM + OVMF dentro de uma distro WSL2 Debian 13 (trixie)**, orquestrado por `scripts/lab/lab.sh`.

- UEFI com Secure Boot e chaves Microsoft (`OVMF_CODE_4M.secboot.fd` + `OVMF_VARS_4M.ms.fd`), como um PC comum.
- Snapshots internos qcow2 + cópia das variáveis UEFI por snapshot.
- Capturas de tela via QMP `screendump` (evidência sem GUI); VNC em 127.0.0.1 para inspeção manual.
- A mesma distro WSL serve para lint, remasterização de ISO e, na etapa 8, live-build.
- `~/.wslconfig`: `memory=5GB`, `swap=4GB`. Remover o arquivo restaura o padrão do WSL.

## Alternativas
- Hyper-V: exige admin + reinício; sem 3D; continua possível como segunda validação de boot UEFI em hypervisor diferente (recomendado na etapa 8/9).
- VirtualBox: mais lento e instável sobre o Hyper-V ativo.

## Consequências
- Perfil `lab-desktop` passa a 4 vCPU / **3 GiB** / 64 GiB (limite de memória do WSL).
- Virtualização aninhada adiciona sobrecarga: medições de desempenho só comparam base × Luma neste mesmo ambiente.
- Sem aceleração 3D (virtio-vga, KWin com renderização por software). Efeitos/FPS não são medidos em VM.
- VMs só rodam enquanto houver uma sessão `wsl.exe` ativa; processos em segundo plano morrem se a distro encerrar.
