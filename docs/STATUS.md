# Estado do projeto

Atualizado: 2026-10-01.

| Etapa | Estado |
|---|---|
| 0 — Escopo e ambiente | APROVADA (ressalvas: mockups ausentes; Secure Boot do host não lido) |
| 1 — Laboratório | **APROVADA** — QEMU/KVM + OVMF Secure Boot no WSL2; 8 critérios PASSOU (CI remoto não executado: sem remoto) |
| 2 — Identidade e protótipo nativo | **EM ANDAMENTO (redesenho)** — mockups recebidos em 2026-09-30; redesenho 0.6.1 implementado (ver "Redesenho"); regressão na VM pendente |
| 3 — Sessão de desktop | **APROVADA** — E3-01..08 PASSOU (34/34); `luma-session` 0.2.0 |
| 4 — Integrações reais | **APROVADA (na VM)** — 25/25 com 0.6.1; bloqueio do volume era do laboratório (conta SSH no grupo `audio`), resolvido. Wi-Fi/Bluetooth/brilho/bateria: NÃO EXECUTADOS, dependem de hardware (etapa 10) |
| 5 — Aplicativos Linux | **APROVADA** — E5-01..09 PASSOU; Flathub pendente de decisão (0004) |
| 7 — Segurança e atualização | **APROVADA** — E7-01..05 PASSOU; `luma-firewall`; execução limpa 29/29 com 0.6.1 (`docs/evidence/etapa7/final/`) |
| 8 — Imagem live | **APROVADA** — ISO 0.6.1 (visual dos mockups): boot com Secure Boot, 19/19; repetido na ISO 0.7.2: 20/20 (`docs/evidence/etapa8/iso-0.7.2/`); diferenças entre builds explicadas; sem alegação de reprodutibilidade bit a bit |
| 9 — Instalação e recuperação | **APROVADA (na VM)** — ISO 0.7.2: normal 66/66 e disco cifrado 42/42; instalação sem internet, boot sem ISO com Secure Boot, login, atualização, recuperação pela ISO. Risco aberto: 1 fechamento do Calamares não reproduzido. Não testado: dual boot, particionamento manual, hardware real (ver TESTS.md). Não usar o instalador fora de VM por enquanto |
| 6 — Aplicativos Windows | NÃO INICIADA — escopo redefinido em duas camadas (decisão 0007). Camada 1 (melhor esforço) pode começar; camada 2 BLOQUEADA: três apps Windows não definidos |
| demais | NÃO INICIADA |

## Como operar o laboratório
Dentro do WSL (`wsl -d Debian -u root`), no repositório em `/mnt/c/Users/kali/Estudo-e-Projetos/LUMA-OS`:
- `scripts/lab/lab.sh install` (uma vez) → VM `lab-desktop` + snapshot `base-limpa`.
- `scripts/build/build-debs.sh` → `.deb` em `/srv/luma-lab/debs`.
- Testes: `scripts/lab/tests/test-vm.sh` (etapa 1), `test-theme.sh` (etapa 2), `test-session.sh` (etapa 3), `python3 theme/tests/test_theme.py`, `scripts/ci/lint.sh`.
- A VM só vive enquanto a sessão `wsl.exe` que a iniciou estiver aberta.

## Limitações/riscos
- RAM do host (7,7 GiB): WSL limitado a 4,6 GB, VM com 2,5–2,8 GiB; uma VM por vez. Com Edge/Discord/VS Code abertos sobram < 0,5 GiB e o WSL já travou uma vez (etapa 8, falha1).
- Sem aceleração 3D na VM: efeitos/FPS não medidos.
- Plasma 6.3: `plasma-apply-lookandfeel` não aplica esquema de cores/ícones (também com Breeze Dark) → contornado por `luma-appearance`.
- Nenhum commit git feito; aguardando autorização do usuário.
- Teclado virtual do laboratório (QMP) perde ou repete teclas com o host carregado: não rodar testes de tela logo após uma build; `test-install.sh` confere o indicador do instalador e redigita.
- Tarefas em segundo plano têm limite de 2 h: build da ISO (~45 min) e teste de instalação (~55 min; `ENCRYPT=1` ~45 min) em tarefas separadas, com `scripts/lab/tests/run-logged.sh LOG TESTE [VAR=valor]`.

## Redesenho conforme mockups (versão 0.6.1)
Referências em `docs/design/references/`; especificação em `docs/design/luma-visual-spec.md`.

| Parte | Estado | Evidência |
|---|---|---|
| Cores medidas nos mockups, contraste AA | feito; 16 testes de tema passam | `theme/tests/test_theme.py` |
| Wallpaper "Luma Ondas" (arte original) | feito | `theme/wallpapers/Luma/src/` |
| Decoração Aurorae: botões vermelho/amarelo/verde à esquerda, título à esquerda | feito; visto na VM | `docs/evidence/etapa2b/` |
| Fonte Inter, ícones Papirus | feito; visto na VM | idem |
| Barra superior com logotipo e menu do app; dock com lixeira | feito; visto na VM | idem |
| Central de Controle (`org.luma.controlcenter`) | feito; Não Perturbe e volume testados de verdade na VM (0,40 → 0,81) | sondas da sessão de 2026-09-30 |
| App Ajustes > Aparência (`luma-ajustes`) | feito; cartão "Escuro" troca o sistema; 11 testes da lógica passam | `apps/ajustes/tests/test_core.py` |
| Regressão na VM com 0.6.1 | sessão: **35/35**; `test-theme.sh` ainda não repetido com 0.6.1 | `docs/evidence/etapa2b/sessao/` |
| ISO com o novo visual | feito: `luma-0.6.1-amd64.iso`, boot testado 19/19 | `docs/evidence/etapa8/` |

Diferenças conhecidas em relação aos mockups: ícones de terceiros não copiados (Papirus no lugar); cantos inferiores das janelas retos; sombra da decoração com leve faixa na borda direita; lançador é o Kickoff em grade (não o painel compacto do mockup); cor de destaque no app ainda não verificada por clique.

## Próximo passo
- Etapa 10 (hardware e desempenho): depende de máquina física do usuário para Wi-Fi, Bluetooth, brilho, bateria, suspensão, USB e monitores. Na VM só dá para medir tempo de boot e memória contra a base Debian.
- Pendências da etapa 9: decidir sobre shell de root no "recovery mode" (decisão 0006, em aberto); testar dual boot antes de qualquer uso em PC com Windows; trocar a identidade Debian do GRUB, da tela de login e da tela de bloqueio.
- Pendências do redesenho: `test-theme.sh` com 0.6.1; cor de destaque por clique; teste automatizado da Central de Controle.
- Builds longos: tarefa em segundo plano com limite explícito de 2 h (o padrão é 30 min).
- Decisão pendente do usuário: pré-configurar ou não o Flathub (decisão 0004). Agora também condiciona a etapa 6: o Bottles não existe no Debian trixie, só no Flathub (decisão 0007).
- Etapa 6: usuário precisa definir os três apps Windows e versões; decidir origem do Bottles e habilitação de `i386`.
