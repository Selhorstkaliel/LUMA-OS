# Luma para PC — especificação

Fonte completa (limites, contrato de tarefa, testes obrigatórios, prompts): [reference/Luma_Plano_e_Prompts.md](reference/Luma_Plano_e_Prompts.md). Este arquivo registra apenas o que foi fixado ou ajustado após a auditoria.

## Escopo
Distribuição Debian personalizada x86_64/UEFI com Plasma 6 Wayland e identidade visual Luma (dock flutuante, painel superior, central de controle, cantos arredondados, transparência moderada), pt-BR. Fora do MVP: kernel/compositor/pacotes próprios, fork do Plasma, apps iOS, execução universal de Windows (a etapa 6 entrega compatibilidade de melhor esforço, sem garantia — [decisions/0007](decisions/0007-compatibilidade-windows.md)), nuvem/contas/telemetria/IA/sincronização.

## Versões fixadas
Ver [decisions/0001](decisions/0001-base-debian-trixie-plasma.md): Debian 13 trixie (13.7 na auditoria), Plasma 6.3.6, Qt 6.8.2, kernel 6.12 LTS, live-build 20250505, Calamares 3.3.14.

## Laboratório (ajustado ao host real)
Host: i5-12450HX, **7,7 GiB RAM**, 92 GiB livres, Windows 11 Pro ([env/host-inventory.md](env/host-inventory.md)).

| Perfil | vCPU | RAM | Disco | Uso |
|---|---|---|---|---|
| `lab-desktop` | 4 | 3 GiB | 64 GiB qcow2 dinâmico | sessão Plasma, testes de etapas 2–7 e 10 |
| `lab-build` | 4 | 3 GiB | +40 GiB | live-build (pode ser a mesma VM com disco extra) |
| `lab-install` | 4 | 3 GiB | 32 GiB vazio, descartável | etapa 9 |

Só uma VM ligada por vez. Perfil de laboratório, não requisito mínimo do produto. Hypervisor: QEMU/KVM + OVMF dentro do WSL2 Debian ([decisions/0002](decisions/0002-hypervisor-laboratorio.md)); limite de memória do WSL = 5 GB. Operação: `scripts/lab/lab.sh`.

## Etapas
Estados e critérios de aprovação idênticos à tabela do plano original. Ajustes:

| Etapa | Ajuste / dependência concreta |
|---|---|
| 1 | Concluída com QEMU/KVM no WSL2 (sem admin). |
| 2 | Aprovação visual bloqueada até os mockups estarem em `design/references/`. Implementação técnica (Look-and-Feel package, esquema de cores, layout de painel via script Plasma) pode avançar. |
| 3–5 | Em VM. Wi-Fi/brilho físicos marcados como pendentes de hardware. |
| 6 | Duas camadas ([decisions/0007](decisions/0007-compatibilidade-windows.md)): (1) melhor esforço — Wine/Bottles prontos e duplo clique em `.exe`, sem garantia; (2) três apps e versões testados com evidência. Camada 2 **BLOQUEADA** até o usuário definir os três apps. Não bloqueia a alpha Linux. |
| 7 | Revisão integrada; controles verificáveis (polkit, ufw/nftables, apt-secure, snapshots). |
| 8 | Build em VM trixie limpa; boot UEFI da ISO em VM. |
| 9 | Apenas disco virtual vazio. |
| 10 | Hardware disponível = este notebook (Intel UHD + RTX 3050 híbrida) apenas via live USB, **sem instalar e sem alterar partições**; só com autorização específica. |
| 11 | Publicação exige autorização específica. |

## Metas de desempenho (a validar, perfil `lab-desktop`)
RAM ociosa 60 s após login ≤ base Plasma trixie + 15%; tempo até desktop ≤ base + 10%. 3 medições, mediana e variação, mesmo hypervisor e resolução.
