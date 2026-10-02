# Etapa 9 — exploração manual (ISO 0.6.1 com a configuração aplicada à mão), 2026-10-01

Capturas dos defeitos encontrados antes das correções da 0.7.x:

| Arquivo | O que mostra |
|---|---|
| padrao-debian-fuso-new-york.png | Configuração padrão do Debian: fuso New York e formatos en_US num sistema pt_BR |
| sessao-live-bloqueada-durante-instalacao.png | Sessão live bloqueou a tela no meio da instalação e pediu senha |
| recovery-mode-root-travado.png | "recovery mode" do GRUB com root bloqueado: sem shell |
| sem-entrada-nvram-disco-nao-inicia.png | Sem a entrada de boot na NVRAM o disco instalado não iniciava (EFI/BOOT incompleto) |
| boot-pelo-caminho-reserva-apos-correcao.png | Depois de `grub-install --force-extra-removable` o mesmo disco inicia |
| particoes-disco-com-restos.png | Página de partições quando o disco já tem partições (instalação interrompida) |

Outros achados sem captura: o usuário criado entrava no grupo `audio`; o atalho do Debian criava as pastas `Área`, `de`, `trabalho`; a ISO não trazia GRUB/shim assinados (o instalador baixava da rede); `hwclock` ausente.
