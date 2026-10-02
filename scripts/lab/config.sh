# shellcheck shell=bash disable=SC2034  # variáveis usadas por quem faz source
# Configuração do laboratório Luma. Todas as variáveis podem ser sobrescritas pelo ambiente.

# Diretório de dados (ISOs, discos, segredos). Fica no sistema de arquivos Linux do WSL, fora do repositório.
: "${LAB_DIR:=/srv/luma-lab}"

# Imagem base fixada (docs/decisions/0001)
: "${DEBIAN_VERSION:=13.7.0}"
: "${DEBIAN_ISO:=debian-${DEBIAN_VERSION}-amd64-netinst.iso}"
: "${DEBIAN_CD_URLS:=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd https://cdimage.debian.org/cdimage/archive/${DEBIAN_VERSION}/amd64/iso-cd}"
# Debian CD signing key (https://www.debian.org/CD/verify)
: "${DEBIAN_CD_KEY_FPR:=DF9B9C49EAA9298432589D76DA87E80D6294BE9B}"
: "${DEBIAN_CD_KEY_URL:=https://www.debian.org/CD/key-DA87E80D6294BE9B.txt}"

# Perfil lab-desktop (docs/LUMA_SPEC.md)
: "${VM_NAME:=lab-desktop}"
: "${VM_CPUS:=4}"
: "${VM_RAM_MB:=3072}"
: "${VM_DISK_SIZE:=64G}"
: "${VM_SSH_PORT:=2222}"
: "${VM_HTTP_PORT:=2280}"          # 127.0.0.1:2280 → porta 8080 da VM (teste de firewall)
: "${VM_VNC_DISPLAY:=0}"          # VNC em 127.0.0.1:5900+N
: "${VM_XRES:=1920}"
: "${VM_YRES:=1080}"
: "${VM_AUDIO:=1}"               # 0 = VM sem placa de som (teste de ausência de dispositivo)
: "${VM_NET:=1}"                 # 0 = VM sem placa de rede
: "${VM_SECUREBOOT:=1}"           # 1 = OVMF com Secure Boot e chaves Microsoft (como um PC comum)

# Binários (sobrescrevíveis para testar erro de dependência)
: "${QEMU:=qemu-system-x86_64}"
: "${QEMU_IMG:=qemu-img}"
: "${XORRISO:=xorriso}"
: "${OVMF_DIR:=/usr/share/OVMF}"

VM_DIR="$LAB_DIR/vms/$VM_NAME"
