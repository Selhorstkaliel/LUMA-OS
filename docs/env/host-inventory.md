# Inventário do host — etapa 0

Coletado em 2026-09-30 por inspeção somente leitura (PowerShell, usuário **sem** privilégio de administrador). Nada foi instalado.

## Hardware e sistema

| Item | Valor observado | Fonte |
|---|---|---|
| SO | Windows 11 Pro 10.0.26200, 64 bits | `Win32_OperatingSystem` |
| CPU | Intel Core i5-12450HX, 8 núcleos / 12 threads | `Win32_Processor` |
| RAM | 7,7 GiB total; 1,2 GiB livre no momento da coleta | `Win32_ComputerSystem`, `Win32_OperatingSystem` |
| GPU | NVIDIA GeForce RTX 3050 6GB Laptop (driver 32.0.16.1714) + Intel UHD (driver 32.0.101.7080), tela 1920×1080 | `Win32_VideoController` |
| Disco | C: 92,2 GiB livres (383,3 GiB usados) | `Get-PSDrive` |
| Hypervisor | `HypervisorPresent = True`; serviço `vmcompute` em execução (plataforma usada por WSL2/Docker). `VirtualizationFirmwareEnabled=False` é o valor esperado quando o Windows já roda sobre o hypervisor, não indica VT-x desligado | `Win32_ComputerSystem`, `Get-Service` |
| Hyper-V (VMs completas) | Módulo PowerShell `Hyper-V` ausente; serviço `vmms` ausente → papel Hyper-V **não habilitado** | `Get-Module -ListAvailable`, `Get-Service` |
| Estado de features opcionais / Secure Boot | **Não lido**: exige elevação (`Get-WindowsOptionalFeature`, `Confirm-SecureBootUEFI` → acesso negado) | — |

## Ferramentas

| Ferramenta | Estado |
|---|---|
| WSL | presente; única distro `docker-desktop` (parada). Sem distro Linux de trabalho |
| Docker | cliente 29.8.0; daemon parado |
| Python | 3.14.5 |
| OpenSSH cliente | presente |
| git, gh, ShellCheck, 7-Zip | **ausentes** |
| VirtualBox, QEMU, VMware | **ausentes** |

## Rede e base Debian

Acesso HTTPS a deb.debian.org e qa.debian.org funciona. `dists/stable/Release`: **Debian 13.7 "trixie"**, data 2026-09-12.

Versões em trixie consultadas em `https://qa.debian.org/madison.php?package=<p>&s=trixie,trixie-security,trixie-updates,trixie-backports`:

| Pacote | trixie | Observação |
|---|---|---|
| plasma-desktop / plasma-workspace / kwin-wayland | 4:6.3.6 | Plasma 6.3 |
| plasma-discover | 6.3.6-1 | loja existente |
| qt6-declarative-dev | 6.8.2+dfsg-7 | Qt 6.8 |
| sddm | 0.21.0+git20250502 | |
| linux-image-amd64 | 6.12.107-1; 6.12.111-1 (security) | backports 7.1 existe, não usar por padrão |
| pipewire | 1.4.2-1 | |
| network-manager | 1.52.1-1 | |
| flatpak | 1.16.6-1~deb13u3 (security) | |
| live-build | 1:20250505+deb13u1 | |
| calamares | 3.3.14-1 | instalador existente candidato |
| shim-signed | 1.51~1+deb13u1 | Secure Boot só vale para binários assinados pelo Debian |
| wine | 10.0~repack-6 | etapa 6 |

## Referências visuais

Os mockups Luma claro/escuro **não foram encontrados** (nem anexados nem em Downloads/Desktop/Pictures). `docs/design/references/` está vazio. Nenhuma aprovação visual é presumida.

## Conclusões operacionais

- **Pode ser executado agora no host:** documentação, scripts, validação sintática (após obter ShellCheck/Python), consultas a repositórios Debian.
- **Exige VM Linux UEFI:** boot, sessão Plasma/Wayland, tema, integrações, ISO, instalação, recuperação, medições.
- **Exige hardware físico:** Wi-Fi, Bluetooth, brilho, suspensão, GPU NVIDIA/Intel híbrida, múltiplos monitores (etapa 10).
- **Restrição principal:** 7,7 GiB de RAM. O perfil de 8 GiB do plano não cabe; perfil de laboratório ajustado para 4 GiB (ver LUMA_SPEC). Só uma VM gráfica por vez; fechar Docker Desktop e apps pesados durante testes.
- **WSL/contêiner** servem apenas para lint e build de pacotes/ISO, não comprovam boot.
