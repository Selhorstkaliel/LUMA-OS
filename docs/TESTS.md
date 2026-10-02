# Matriz de testes

Status: PASSOU, FALHOU, NÃO EXECUTADO (com motivo). Logs/capturas em `docs/evidence/<etapa>/` a partir da etapa 1.

## Etapa 0 — Escopo e ambiente

| ID | Requisito | Comando/procedimento | Ambiente | Esperado | Observado | Status | Evidência |
|---|---|---|---|---|---|---|---|
| E0-01 | Inventário de CPU/RAM/GPU/disco | `Get-CimInstance Win32_Processor/ComputerSystem/OperatingSystem/VideoController`, `Get-PSDrive` | Win11 Pro 26200, usuário comum | Valores coletados | Coletados | PASSOU | env/host-inventory.md |
| E0-02 | Capacidade de virtualização | `Win32_ComputerSystem.HypervisorPresent`, `Get-Service vmms,vmcompute`, `Get-Module -ListAvailable Hyper-V` | idem | Saber se é possível criar VM | Hypervisor ativo; nenhum gerenciador de VM instalado | PASSOU (achado: bloqueio para etapa 1) | env/host-inventory.md |
| E0-03 | Ferramentas | `Get-Command` para git, wsl, VBoxManage, qemu, docker, python, shellcheck… | idem | Lista presente/ausente | git, ShellCheck, hypervisor ausentes | PASSOU | env/host-inventory.md |
| E0-04 | Versões da base verificadas em fonte oficial | `deb.debian.org/debian/dists/stable/Release`; `qa.debian.org/madison.php` | rede do host | Codename e versões fixados | trixie 13.7; Plasma 6.3.6 etc. | PASSOU | decisions/0001 |
| E0-05 | Referências visuais | Busca em docs/design/references, Downloads, Desktop, Pictures | idem | Mockups presentes | Ausentes | FALHOU (registrado; bloqueia só aprovação visual da etapa 2) | design/references/README.md |
| E0-06 | Nada instalado no host | Revisão das ações da sessão | — | Sem instalação | Somente leitura + criação de docs no repositório | PASSOU | este arquivo |
| E0-07 | Estado de features opcionais e Secure Boot do host | `Get-WindowsOptionalFeature`, `Confirm-SecureBootUEFI` | usuário comum | Estado lido | Acesso negado (exige admin) | NÃO EXECUTADO — informativo, não obrigatório | — |

## Etapa 1 — Laboratório

Ambiente: Windows 11 Pro 26200 → WSL2 (kernel 6.6.87.2) Debian 13 → QEMU 10.0.13/KVM + OVMF 4M Secure Boot (chaves MS). VM `lab-desktop`: 4 vCPU, 3 GiB, 64 GiB qcow2. Hóspede: Debian 13.7, kernel 6.12.111, plasma-workspace 4:6.3.6-2, kwin-wayland 4:6.3.6-1. Data: 2026-09-30.

| ID | Requisito | Comando/procedimento | Esperado | Observado | Status | Evidência |
|---|---|---|---|---|---|---|
| E1-01 | Repositório versionado, sem segredos/artefatos | `git init`; `.gitignore` (iso, qcow2, fd, .lab, chaves); `scripts/ci/lint.sh` procura chaves privadas e hashes crypt | Repo criado; nada sensível rastreável | Repo criado; lint sem achados. **Nenhum commit feito** (aguarda autorização) | PASSOU | evidence/etapa1/E1-07-lint.log |
| E1-02 | VM UEFI inicia Debian trixie + Plasma | `scripts/lab/tests/test-vm.sh` (boot, os-release, `/sys/firmware/efi`, efivar SecureBoot=1, dpkg plasma-workspace 4:6.x, sessão Wayland, SDDM ativo, `systemctl --failed` vazio, locale/teclado) | Todos verdadeiros | 11/11 | PASSOU | E1-02-05-test-vm.log, E1-02-sddm.png |
| E1-03 | Acesso de desenvolvimento | SSH por chave ed25519 (porta 2222 local); senha recusada; `sudo -n` negado | Chave aceita; senha e sudo sem senha recusados | Conforme esperado | PASSOU | E1-02-05-test-vm.log |
| E1-04 | Snapshot restaura | criar `~/marcador-snapshot`, desligar, `snapshot-restore base-limpa`, iniciar | Marcador ausente, SDDM ativo | Conforme esperado | PASSOU | E1-02-05-test-vm.log |
| E1-05 | Preparação idempotente | `fetch-iso`, `build-iso`, `create`, `install`, `snapshot-save` executados 2× | 2ª execução não baixa/reconstrói/reinstala/duplica | Conforme esperado | PASSOU | fetch-iso-idempotente.log, E1-05-build-iso.log, E1-02-05-test-vm.log |
| E1-06 | Erro de dependência | `scripts/lab/tests/test-deps.sh` (qemu, OVMF, xorriso ausentes; comando inválido) | exit 2 com mensagem de instalação; 64 para uso | Conforme esperado | PASSOU | E1-06-dependencias.log |
| E1-07 | Verificações leves (CI) | `scripts/ci/lint.sh` (bash -n + ShellCheck + busca de segredos); workflow `.github/workflows/lint.yml` | Sem achados | Local: OK (6 scripts). Remoto: sem repositório remoto autorizado | PASSOU (local) / NÃO EXECUTADO (remoto) | E1-07-lint.log |
| E1-08 | Integridade da mídia base | `fetch-iso`: chave Debian CD com impressão digital fixada, `SHA256SUMS.sign` VALIDSIG, `sha256sum -c` | Assinatura e hash válidos | Conforme esperado | PASSOU | fetch-iso-idempotente.log |

Falhas encontradas e corrigidas (logs `falha*`): (1) instalador no console serial ignorava locale pt_BR e ficava na pergunta de idioma → console só na tela; (2) corrida entre `run &` e o pidfile em `wait-ssh` → tolerância de 30 s; (3) `plasmashell --version` aborta sem display → versão via `dpkg-query` (o requisito não mudou, só o método de verificação estava errado).

## Etapa 2 — Identidade e protótipo nativo

Ambiente: igual à etapa 1; pacote `luma-theme` 0.1.2 (`scripts/build/build-debs.sh`); conta `teste` com login automático (somente laboratório, `scripts/lab/guest/setup-test-user.sh`). Teste: `scripts/lab/tests/test-theme.sh` (VM restaurada de `base-limpa`). Data: 2026-09-30.

| ID | Requisito | Procedimento | Observado | Status | Evidência (docs/evidence/etapa2) |
|---|---|---|---|---|---|
| E2-01 | Pacote constrói limpo, contraste AA | `build-debs.sh` (dpkg-buildpackage + lintian); `theme/tests/test_theme.py` (11 testes: WCAG ≥ 4,5:1 texto, ≥ 3:1 foco, coerência LnF) | Sem erro/aviso lintian; 11/11. A 1ª proposta de cores reprovou 19 combinações e foi corrigida | PASSOU | E2-01-build.log |
| E2-02 | Instalar em conta de teste | `apt-get install ./luma-theme.deb`; LnF e esquemas listados | Conforme esperado | PASSOU | E2-02-apt-install.log, E2-02-antes-breeze.png |
| E2-03 | Tema claro + layout (painel superior, dock flutuante, lançador, wallpaper) | `luma-appearance claro --reset-layout`; kdeglobals, appletsrc, plasmashellrc | ColorScheme, ícones, 2 painéis, dock `floating=1` `panelLengthMode=1`, favoritos, wallpaper | PASSOU | E2-03-*.png/txt |
| E2-04 | Abrir apps reais | Dolphin, Konsole, Configurações | 3/3 em execução | PASSOU | E2-04-apps-claro.png |
| E2-05 | Alternar claro/escuro | `luma-appearance escuro`; uso inválido → 64 | Esquema, ícones e layout corretos | PASSOU | E2-05-apps-escuro.png |
| E2-06 | 1366×768 e 1920×1080 | VM reiniciada em 1366×768 nativo (EDID virtio sem 1366×768); depois 1920×1080 | Modos ativos; tema escuro persistiu após reinício; sem cortes | PASSOU | E2-06-*.png, E2-06-kdeglobals-apos-reinicio.txt |
| E2-07 | Escala | `kscreen-doctor ... scale.1.5` | Ativa; sem cortes | PASSOU | E2-07-claro-escala150.png |
| E2-08 | Teclado | QMP: Meta → digitar "konsole" → Enter; Alt+Tab | Lançador abre, busca, Konsole abre; foco visível | PASSOU | E2-08-*.png |
| E2-09 | Remover | `apt-get remove luma-theme`; relogin | Arquivos removidos; sessão inicia e plasmashell estável | PASSOU | E2-09-*.png/log |
| E2-10 | Conformidade com mockups aprovados | Comparação visual | Mockups ausentes | NÃO EXECUTADO | design/references/README.md |

Falhas encontradas e corrigidas (logs `falha1..4`): (1) `plasma-apply-lookandfeel` do Plasma 6.3 não aplica esquema de cores nem ícones — reproduzido também com Breeze Dark oficial → `luma-appearance` aplica e verifica explicitamente; (2) `powerdown` por ACPI abre diálogo de logout com sessão aberta e o teste seguiu numa VM suja → desligamento via SSH primeiro e restauração/desligamento tornados fatais no teste; (3) ícones `breeze` (padrão) removem a chave → leitura com `--default`; (4) valores iguais aos padrões do LnF ficam em `~/.config/kdedefaults`, visível só com o `XDG_CONFIG_DIRS` da sessão → ambiente de teste importa essa variável. Wallpaper passou a ser definido no próprio layout (corrida com `--resetLayout`).

Observação visual: `plasma-welcome` e o avatar do Kickoff ainda exibem marca Debian (tratado na etapa 3/8).

## Etapa 3 — Sessão de desktop

Ambiente: igual à etapa 1; pacotes `luma-theme` e `luma-session` 0.2.0; usuário **novo** `novo` criado após a instalação, com senha aleatória digitável guardada só em `/srv/luma-lab/secrets` e login automático (somente laboratório). Entrada real via QMP (teclado e ponteiro absoluto); estado lido do KWin (script via D-Bus → journal, `luma-lab-windows`) e do logind. Teste: `scripts/lab/tests/test-session.sh`. Regressão da etapa 2 após refatoração para `tests/lib.sh`: 31/31. Data: 2026-09-30.

| ID | Requisito | Procedimento | Observado | Status | Evidência (docs/evidence/etapa3) |
|---|---|---|---|---|---|
| E3-01 | Usuário novo recebe padrões | `/etc/xdg/kdeglobals` (`LookAndFeelPackage=org.luma.desktop`) precede `desktop-base`; 1º login sem comandos | LnF, LumaLight, 2 painéis, favoritos, wallpaper e bloqueio Luma | PASSOU | E3-01-usuario-novo.png |
| E3-02 | Mover, maximizar, minimizar, fechar | Arrastar título; duplo clique; botão minimizar; botão X; Alt+F4 | Δ=199,119 (esperado ~200,120); estados confirmados no KWin | PASSOU | E3-02-*.png |
| E3-03 | Alt+Tab | Restaura minimizada; alterna Dolphin→Konsole | Janela ativa correta | PASSOU | E3-02-duas-janelas.png |
| E3-04 | Notificações | `org.freedesktop.Notifications.Notify` | ID 1; exibida no canto | PASSOU | E3-03-notificacao.png |
| E3-05 | Pesquisa | Alt+Espaço → "dolphin" → Enter | Dolphin aberto | PASSOU | E3-04-krunner.png |
| E3-06 | Bloqueio exige autenticação | Meta+L; senha errada; senha correta (`LockedHint`) | yes → yes → no | PASSOU | E3-05-*.png |
| E3-07 | Persistência | Tema escuro → logout (novo PID do plasmashell) → reinício | LumaDark, LnF escuro e layout mantidos | PASSOU | E3-06-*.png |
| E3-08 | Remoção limpa | `apt purge luma-session` | `/etc/xdg` limpo; tema e escolha do usuário mantidos | PASSOU | E3-07-apt-purge.log |

Falha encontrada e corrigida: o 1º login de um usuário novo ainda exibia o splash quando as verificações rodaram (`falha1-*`); o teste passou a esperar o fim do `ksplashqml` e a gravação do layout, em vez de um tempo fixo.

Observação visual: avatar padrão e texto do `plasma-welcome` exibem Debian (vêm de `desktop-base`/`os-release`); identidade de distribuição fica para a etapa 8.

## Etapa 4 — Integrações reais (central de controle = bandeja do Plasma, decisão 0003)

Ambiente: igual à etapa 1; pacotes 0.2.0; NetworkManager 1.52.1, PipeWire 1.4.2 / WirePlumber 0.5.8, power-profiles-daemon; placa de som virtual intel-hda, rede virtio. Falha de rede via QMP `set_link`; ausência de dispositivo com `VM_AUDIO=0` / `VM_NET=0` (`-nic none`); verificação sem rede pelo agente QEMU (`lab.sh ga`). Teste: `scripts/lab/tests/test-integrations.sh`. Data: 2026-09-30.

| ID | Requisito | Observado | Status | Evidência (docs/evidence/etapa4) |
|---|---|---|---|---|
| E4-01 | Alterar volume real | Teclas volume +/−/mudo e rolagem no ícone alteram o sink PipeWire (0,40→0,45→0,35→0,45) | PASSOU | E4-01-popup-volume.png |
| E4-02 | Rede: caminho feliz | Conectividade `full` | PASSOU | E4-02-popup-rede.png |
| E4-03 | Rede: falha | Cabo desligado → `unavailable`, ícone de desconectado, plasmashell estável; religado → volta sozinha | PASSOU | E4-03-sem-cabo.png |
| E4-04 | Rede: acesso negado | Sessão SSH remota: `network-control request failed: not authorized`; sessão local ativa desconecta/reconecta | PASSOU | E4-04-*.png |
| E4-05 | Energia | Perfil `power-saver` pela sessão; sem bateria → UPower só com DisplayDevice | PASSOU | E4-05-popup-energia.png |
| E4-06 | Persistência após reinício | Volume 0,63, perfil de energia e rede mantidos após reinício | PASSOU | final/E4-test-integrations.log; causa do bloqueio anterior em bloqueio-volume/README.md |
| E4-07 | Ausência de placa de som | Applet: "Nenhum dispositivo de entrada ou saída encontrado"; teclas não derrubam o plasmashell | PASSOU | E4-06-sem-placa-de-som.png |
| E4-08 | Ausência de placa de rede | Sessão ativa; NetworkManager sem ethernet | PASSOU | E4-07-sem-placa-de-rede.png |
| E4-09 | Wi-Fi, Bluetooth, brilho de painel, bateria real | Sem dispositivo na VM | NÃO EXECUTADO (hardware) | — |

Execução final (2026-10-01, pacotes 0.6.1, evidências em `docs/evidence/etapa4/final/`): **25/25, 0 falhas**; capturas conferidas (popups de volume, rede e energia abertos pelos ícones da nova barra superior).

Bloqueio E4-06 resolvido: era defeito do laboratório, não do produto. A conta `luma` (SSH dos testes) estava no grupo `audio`; o WirePlumber dela acessava a placa fora do assento e gravava o próprio volume (0,40) no mixer de hardware. Controle: conta no grupo → 0,40; fora do grupo → 0,63 e 0,27 persistem. Correção em `scripts/lab/guest/setup-test-user.sh`; requisito de produto para a etapa 9: o instalador não coloca usuários no grupo `audio`.

Falhas do laboratório corrigidas (logs `falha1..3`): agente QEMU guardava respostas de pedidos abandonados → cliente `qga.py` com `guest-sync`; ordem dos dispositivos alterada mudou o nome da interface → ordem original restaurada e novos dispositivos no fim; QEMU cria NIC padrão sem `-netdev` → `-nic none`; `status | grep -q` com `pipefail` gerava falso negativo; `connectivity check` exige autorização → leitura de `CONNECTIVITY`.

## Etapa 5 — Aplicativos Linux (decisão 0004)

Ambiente: igual à etapa 1; pacotes 0.3.0 (`luma-session` recomenda Discover, backend Flatpak e portal KDE); usuário `novo` administrador (grupo sudo) com senha aleatória digitável; PackageKit 1.3.1, Discover 6.3.6. Teste: `scripts/lab/tests/test-apps.sh`. Data: 2026-09-30.

| ID | Requisito | Observado | Status | Evidência (docs/evidence/etapa5) |
|---|---|---|---|---|
| E5-01 | Acesso negado | `pkcon install` por sessão SSH remota negado; pacote não instalado | PASSOU | E5-01-negado.log |
| E5-02 | Instalar pela loja | Sessão local → diálogo polkit pede senha do administrador → `kpat` instalado | PASSOU | E5-02-polkit.png, E5-03-instalado.png |
| E5-03 | Abrir | `kpat` aberto pelo KRunner; Discover abre | PASSOU | E5-04/05-*.png |
| E5-04 | Atualizar | Atualização real do Debian: flatpak `1.16.6-1~deb13u2` → `~deb13u3` (trixie-security) | PASSOU | E5-06-atualizado.png |
| E5-05 | Remover | `kpat` removido após instalado | PASSOU | — |
| E5-06 | Abrir/salvar documento com espaço e acento | `Relatório de teste.txt` aberto no Kate pela associação; salvo; "salvar como" `copia final` | PASSOU | E5-07-conteudo-salvo.txt, E5-08-salvar-como.png |
| E5-07 | Associações | text/plain→Kate, PDF→Okular, PNG→Gwenview, pasta→Dolphin (com o ambiente real da sessão) | PASSOU | E5-07-kde-mimeapps.txt |
| E5-08 | Permissão de arquivos | Home 700; outro usuário não lê o documento | PASSOU | — |
| E5-09 | Flatpak/portais | flatpak, backend do Discover, `kde.portal`, `xdg-desktop-portal` ativo; nenhum remoto pré-configurado | PASSOU | — |

Falhas do teste corrigidas (logs `falha1..3`): `pkcon -y` é `--noninteractive` e proíbe o polkit de perguntar; o ambiente SSH sem `XDG_CURRENT_DESKTOP`/`XDG_MENU_PREFIX` fazia as associações parecerem erradas (PDF→GIMP) e abria "Escolher aplicativo" — com o ambiente completo da sessão as associações do Debian/KDE estão corretas e o Luma **não** precisa de `mimeapps.list` próprio; a verificação de "salvar" lia só a 1ª linha — o conteúdo salvo foi confirmado diretamente no disco (E5-07-conteudo-salvo.txt) e a asserção corrigida roda na regressão final.

## Etapa 7 — Segurança e atualização (docs/security/modelo-de-ameacas.md)

Ambiente: igual à etapa 1; pacotes 0.4.0 (novo `luma-firewall`: ufw 0.36.2, política aplicada uma vez por serviço systemd); repositórios de teste gerados por `scripts/lab/fixtures/make-test-repo.sh` e pacote de falha por `make-recovery-pkg.sh` (somente laboratório, chaves descartáveis). Teste: `scripts/lab/tests/test-security.sh`. Data: 2026-09-30.

| ID | Requisito | Observado | Status | Evidência (docs/evidence/etapa7) |
|---|---|---|---|---|
| E7-01 | Firewall de entrada | ufw ativo, `deny (incoming)`; porta 8080 bloqueada de fora; **controle**: abre com regra temporária e volta a bloquear sem ela; ativo após reinício; serviço não reaplica | PASSOU | E7-01-ufw-status.txt |
| E7-02 | Usuário comum não modifica o sistema | Sem escrita em /etc e /usr; sudo, parar serviço, desativar firewall e instalar pacote negados | PASSOU | E7-test-security.log |
| E7-03 | Assinatura inválida rejeitada | **Controle** (chave confiável) instala; chave não confiável e índice adulterado após assinatura rejeitados; nenhuma fonte `trusted=yes` | PASSOU | E7-03-repo-*.log |
| E7-04 | Recuperação após falha controlada | Pacote em `half-configured` confirmado → energia cortada → sistema inicia, `dpkg --audit` acusa o pacote → procedimento de `docs/usuario/recuperacao.md` → configurado, audit limpo, `apt-get check` ok, sessão gráfica ok | PASSOU | E7-04-*.txt/log/png |
| E7-05 | Cobertura real de confinamento | AppArmor com 17 perfis em enforce; 0 apps Flatpak; apps nativos não confinados (registrado como limite) | PASSOU (registro) | E7-05-aa-status.txt |

Falhas corrigidas (logs `falha1..3`): `curl` ausente na base → consulta com python3; `apt-get check` exige root; corte de energia por tempo não induzia falha em 3 tentativas (dpkg terminava antes; saída do apt com buffer) → pacote-fixture que bloqueia na 1ª configuração, estado confirmado antes do corte. Na execução final, "preparar ufw do laboratório" falhou por eu ter editado `lab.sh` durante o teste (erro de sintaxe na leitura incremental do bash); as regras foram aplicadas (E7-01-ufw-status.txt) e todas as verificações de segurança passaram. Execução limpa repetida em 2026-10-01 com pacotes 0.6.1: **29/29, 0 falhas** (`docs/evidence/etapa7/final/E7-test-security.log`).

Não coberto: interrupção durante o *desempacotamento* (só a configuração foi induzida de forma determinística); atualização automática de segurança (política não definida).

## Etapa 8 — Imagem live (decisão 0005)

Receita: `live/` (live-build 1:20250505+deb13u1); build: `scripts/build/build-iso.sh` (diretório de trabalho novo a cada build; saídas ISO, `.sha256`, `.packages`, `.manifest`, `.build.log` em `/srv/luma-lab/iso-out`). Teste de boot: `scripts/lab/tests/test-iso.sh` (VM `lab-live` com disco vazio, OVMF com Secure Boot e chaves Microsoft; verificação pelo agente QEMU).

| ID | Requisito | Observado | Status | Evidência (docs/evidence/etapa8) |
|---|---|---|---|---|
| E8-01 | Build em ambiente limpo | 3 builds em diretório novo: 0.4.0 (33 min), 0.4.1 (84 min), 0.6.1 (39 min; 2,91 GB; 2222 pacotes) | PASSOU | E8-01-build-{1,2,3}.log |
| E8-02 | Boot UEFI até o desktop | ISO 0.6.1 inicia sozinha (menu com 10 s), **Secure Boot ativo**, sessão Plasma do usuário live | PASSOU | E8-test-iso.log, E8-02-desktop-live.png |
| E8-03 | Arquivos e padrões Luma presentes | 4 pacotes Luma 0.6.1, LookAndFeel e esquema Luma, painel superior e dock, firewall ativo, pt_BR/teclado br, Calamares presente | PASSOU | E8-test-iso.log |
| E8-04 | Apps abrem | Dolphin e Konsole | PASSOU | E8-03-apps-live.png |
| E8-05 | Repetir build e explicar diferenças | Builds 1×2 (mesma lista de pacotes): só as 3 versões `luma-*` mudam. Builds 2×3: +13 pacotes do redesenho (Inter, Papirus, PySide6, `luma-ajustes`), nenhum removido | PASSOU | E8-05-diferenca-manifestos.txt |

Não alegado: reprodutibilidade bit a bit (os SHA-256 das ISOs diferem; não houve dois builds da mesma receita e versão). Falhas corrigidas (`falha1`, `falha2`): host sem memória paginou a VM do WSL (ISO lida com `cache=none`, VM live com 2,5 GiB, WSL com 4,6 GB); menu de boot do live-build sem tempo limite (`set timeout=10`); tarefa de build encerrada aos 30 min e build "desacoplado" morto com a distro (o build passou a ser mantido por um `wsl.exe` iniciado com `Start-Process`).

Pendente fora desta etapa: instalador (etapa 9) não testado; marca "Debian" no menu de boot e na tela de boas-vindas.

## Etapa 2b — Redesenho conforme os mockups aprovados (pacotes 0.6.1)

Referências: `docs/design/references/luma-claro.png` e `luma-escuro.png` (recebidas em 2026-09-30); especificação em `docs/design/luma-visual-spec.md`. Ambiente: VM `lab-desktop` com 2,5–2,8 GiB. Data: 2026-09-30/10-01.

| ID | Requisito | Procedimento | Observado | Status | Evidência |
|---|---|---|---|---|---|
| E2b-01 | Cores dos mockups com contraste AA; decoração, plasmoide e LnF coerentes | `python3 theme/tests/test_theme.py` | 16/16 | PASSOU | saída do build (`dh_auto_test`) |
| E2b-02 | Lógica do app Ajustes (comandos, cor de destaque legível) | `python3 apps/ajustes/tests/test_core.py` | 11/11 | PASSOU | idem |
| E2b-03 | Pacotes constroem limpos | `scripts/build/build-debs.sh` (4 pacotes, lintian) | sem erro/aviso | PASSOU | `/srv/luma-lab/debs/*_0.6.1_all.deb` |
| E2b-04 | Usuário novo recebe o visual novo sem comandos | `test-session.sh`: LnF, LumaLight, fonte Inter, 2 painéis, favoritos, wallpaper, botões `XIA` à esquerda | conforme esperado | PASSOU | evidence/etapa2b/sessao/ |
| E2b-05 | Janelas com a decoração Luma por mouse/teclado | arrastar título, duplo clique, botão amarelo (minimizar) e vermelho (fechar) à esquerda, Alt+Tab, Alt+F4 | 35/35 no teste de sessão | PASSOU | evidence/etapa2b/sessao/test-session.log |
| E2b-06 | Central de Controle funcional | clique em "Não Perturbe" → servidor `Inhibited=true`; clique no slider → volume 0,40 → 0,81; Wi-Fi/Bluetooth "Indisponível" sem hardware | conforme esperado (sonda manual, ainda sem teste automatizado no repositório) | PASSOU (manual) | STATUS "Redesenho" |
| E2b-07 | Ajustes > Aparência | cartão "Escuro" → `ColorScheme=LumaDark` e sistema escuro | conforme esperado (sonda manual) | PASSOU (manual) | idem |
| E2b-08 | Cor de destaque pelo app | clique na cor | comando funciona; fluxo por clique com a correção de persistência **não reverificado** | NÃO EXECUTADO | — |
| E2b-09 | `test-theme.sh` com 0.6.1 | regressão da etapa 2 | última execução (0.5.0): 33 passaram; falhas eram fonte (movida para `luma-session`) e tecla repetida | NÃO EXECUTADO com 0.6.1 | evidence/etapa2b/test-theme.log |
| E2b-10 | Comparação visual com os mockups | capturas lado a lado | próximo no modo claro e escuro; diferenças listadas em STATUS | PARCIAL | evidence/etapa2b/sessao/*.png |

Falhas corrigidas neste bloco: `TitleAlignment=AlignLeft` é lido como "direita" (valor correto `Left`); sombra da decoração com emendas (gradientes passaram a ser contínuos); `plasma-apply-lookandfeel` não troca o estilo do Plasma nem a decoração (aplicados por `luma-appearance`, com reinício do plasmashell só quando o estilo muda); ordem dos botões não vai para `kdedefaults` (padrão em `/etc/xdg/kwinrc`); Plasma não guarda a cor de destaque (`[Luma] AccentColor`); `__pycache__` entrava no pacote (testes com `python3 -B`); teste de sessão clicava nos botões no lado direito.

## Etapa 9 — Instalação e recuperação (decisão 0006)

Ambiente: VM `lab-install` (QEMU/KVM, OVMF com Secure Boot e chaves Microsoft, 4 vCPU, 2,75 GiB, disco virtual qcow2 de 32 GiB criado vazio a cada execução; nenhum disco físico). ISO `luma-0.7.2-amd64.iso` (SHA-256 `74697ee6…5369`, 2240 pacotes). Instalador dirigido por mouse e teclado via QMP; estado conferido pelo agente QEMU e por leitura de pixels da tela. Testes: `scripts/lab/tests/test-install.sh` (normal) e `ENCRYPT=1` (disco cifrado). Data: 2026-10-01.

Resultado final: normal **66/66**, disco cifrado **42/42**, 0 falhas (`docs/evidence/etapa9/final/E9-test-install.log`, `final-luks/E9-test-install-luks.log`).

| ID | Requisito | Observado | Status | Evidência (docs/evidence/etapa9) |
|---|---|---|---|---|
| E9-01 | Instalador integrado na sessão live | Marca Luma 0.7.2, pt_BR, fuso America/Sao_Paulo sem GeoIP, Secure Boot ativo, atalho "Instalar o Luma" no lugar certo nas 3 inicializações da ISO, sessão live sem bloqueio automático | PASSOU | final/e9-01-live.png |
| E9-02 | Cancelamento | Até o resumo → Cancelar → Sim: instalador encerra, disco continua sem partições | PASSOU | final/e9-02-cancelar-*.png |
| E9-03 | Falha: energia cortada no meio da cópia | VM desligada à força com `rsync` em andamento; o disco pela metade não inicia sozinho | PASSOU | final/e9-03-*.png |
| E9-04 | Instalar em disco virtual, sem internet | Reinstalação sobre o disco da E9-03 ("Formatar o disco"), cabo de rede desligado; instalador relata sucesso; a tela não bloqueou | PASSOU | final/e9-04-*.png, e9-04-calamares-session.log |
| E9-05 | Retirar a ISO e reiniciar | Inicia pelo disco com Secure Boot ativo; usuário administrador fora do grupo `audio`; root bloqueado; sem login automático; pt_BR, teclado br, fuso de São Paulo; pacotes live, instalador e seus arquivos removidos; log do instalador não fica no sistema; nenhuma fonte APT `trusted=yes`; firewall ativo; nenhum serviço com falha; caminho de boot reserva `EFI/BOOT` completo | PASSOU | final/e9-05-sistema-instalado.txt |
| E9-06 | Login | Login pela tela com a senha escolhida; aparência Luma; áudio pela sessão | PASSOU | final/e9-06-desktop.png |
| E9-07 | Atualização | `apt-get update` sem erros nem avisos; `dist-upgrade` concluído (0 pacotes pendentes no dia); pacote `hello` instalado do repositório assinado; base íntegra | PASSOU | final/e9-07-*.log |
| E9-08 | "recovery mode" do GRUB | Entra em `rescue.target`, **não** dá shell (root bloqueado: "a conta root está travada"); Enter segue para a tela de login | PASSOU (comportamento registrado; não é caminho de recuperação) | final/e9-08-*.png |
| E9-09 | Recuperação pela ISO | ISO inicia com sistema no disco; procedimento de `docs/usuario/recuperacao.md` por chroot redefine a senha e confere os pacotes; o disco volta a iniciar (pelo caminho reserva `EFI/BOOT`); senha antiga recusada, nova aceita; Secure Boot ativo | PASSOU | final/e9-09-resgate.log, e9-09-desktop-apos-resgate.png |
| E9-10 | Criptografia de disco | Instalação sem internet com "Criptografar sistema"; senha do disco pedida no boot; raiz e swap em volumes LUKS, nenhuma partição ext4/swap em claro; demais verificações da E9-05 a E9-07 | PASSOU | final-luks/ |

Tempo de instalação medido na VM: 10 a 26 min sem cifra e 17 a 26 min com cifra (varia com a carga do host).

### Defeitos encontrados e corrigidos (produto)
| Defeito | Correção | Versão |
|---|---|---|
| Fuso padrão New York e formatos en_US | `locale.conf` do Luma | 0.7.0 |
| Usuário criado no grupo `audio` | `users.conf` do Luma | 0.7.0 |
| Atalho do Debian criava pastas `Área`, `de`, `trabalho` | script de atalho próprio | 0.7.0 |
| Sessão live bloqueava a tela (e podia suspender) durante a instalação | pacote `luma-live` | 0.7.0 |
| ISO sem GRUB/shim assinados: instalação dependia da internet para ter boot | pacotes na imagem | 0.7.0 |
| Disco não iniciava se a entrada de boot da NVRAM se perdesse (`EFI/BOOT` só com o shim) | passo `luma-efi-fallback` | 0.7.0 |
| `hwclock` ausente (erro silencioso) | `util-linux-extra` na imagem | 0.7.0 |
| Calamares continuava instalado no sistema final | `packages.conf` do Luma | 0.7.0 |
| `/etc/calamares` (marca, `locale.conf`) sobrava no sistema instalado | passo `luma-cleanup` | 0.7.1 |
| Atalho do instalador ausente em 1 de 3 inicializações (ordem de início; causa provável) | script chama `xdg-user-dirs-update` antes | 0.7.2 |

### Execuções que não foram aprovadas (histórico completo nas pastas)
- `execucao1-0.7.0/`: 3 falhas (2 de verificação, 1 de produto: restos do instalador).
- `execucao2-0.7.1/`: interrompida pelo limite de tempo da tarefa; 1 falha de produto (atalho).
- `execucao3-0.7.2/`: 2 falhas — teclado virtual perdeu/repetiu teclas sob carga do host (defeito do laboratório, confirmado por experimento) e **o Calamares fechou com Segmentation fault** na página de partições.
- `execucao4-0.7.2/`: 65/66; a falha era um limiar errado na verificação da E9-08.

### Riscos e limites conhecidos
- **Fechamento do Calamares (segfault)**: 1 ocorrência no dia, antes de qualquer escrita em disco; não reproduzido em 6 tentativas dirigidas (3 sob carga) nem nas execuções finais. Causa desconhecida, sem coredump. Componente do Debian, não alterado pelo Luma.
- Não testado: dual boot ("instalar lado a lado", "substituir partição"), particionamento manual, hardware real, BIOS legado (fora do escopo), recuperação pela ISO com disco cifrado, senha de disco errada no boot, instalação com menos de 2,75 GiB de RAM.
- O usuário digitado no teste é sempre "Ana Teste" → login `anat`; nomes com acentos não foram testados.
- Identidade Debian ainda aparece no menu do GRUB, na tela de login e no nome da partição mostrado pelo instalador.

## Etapa 6 — Aplicativos Windows (decisão 0007)

Critérios registrados em 2026-10-01, **antes da implementação**. Decisões do usuário: só o Wine do Debian (sem Bottles); `i386` habilitado, com medição do aumento da ISO; três aplicativos da camada 2 abaixo. Instaladores baixados só dos sites oficiais, com versão e SHA-256 registrados. Coluna "Status" preenchida só depois da execução; falha é registrada como falha.

### Camada 1 — melhor esforço (sem garantia de que o programa funciona)
| ID | Critério | Como será verificado | Status |
|---|---|---|---|
| E6-01 | Pacote instala e remove sem resíduos | Instalar e remover `luma-windows` na VM; nenhum arquivo do pacote sobra em `/usr`, `/etc`; a associação de `.exe` some | PENDENTE |
| E6-02 | Duplo clique em `.exe` abre pela camada de compatibilidade | Duplo clique real no Dolphin num `.exe`; a janela do programa aparece | PENDENTE |
| E6-03 | Duplo clique em `.msi` abre pela camada de compatibilidade | Duplo clique real no Dolphin num `.msi`; a janela do instalador aparece | PENDENTE |
| E6-04 | `.exe` inválido mostra erro legível, sem travar a sessão | Arquivo de texto renomeado para `.exe`: mensagem em português; plasmashell continua de pé | PENDENTE |
| E6-05 | Nada roda como root | Processos do Wine pertencem ao usuário; chamada como root é recusada; nenhum binário setuid no pacote | PENDENTE |
| E6-06 | Aviso de segurança exibido | No primeiro uso aparece o aviso (não é barreira de segurança; pode não funcionar); "Cancelar" não abre o programa | PENDENTE |
| E6-07 | Programas de 32 bits abrem | `wine32:i386` presente; um `.exe` de 32 bits abre | PENDENTE |
| E6-08 | Aumento da ISO medido | Tamanho e número de pacotes da ISO com Wine + `i386` contra a 0.7.2 (2 937 483 264 bytes, 2240 pacotes) | PENDENTE |

### Camada 2 — três aplicativos testados
Para cada um: instalar, abrir, função principal, desinstalar. Só o que passar pode ser descrito como "funciona na Luma".

| ID | Aplicativo | Função principal | Status |
|---|---|---|---|
| E6-11 | Notepad++ 8.7, x64, instalador `.exe` | Criar, salvar e reabrir um texto | PENDENTE |
| E6-12 | 7-Zip 24.09, x64, instalador `.msi` | Compactar e extrair uma pasta | PENDENTE |
| E6-13 | IrfanView 4.67, 32 bits, instalador `.exe` | Abrir uma imagem e converter para outro formato | PENDENTE |

Fora do critério: jogos e aplicativos que dependem de GPU, anti-cheat, drivers, aplicativos da Microsoft Store.

Situação em 2026-10-01: etapa suspensa antes dos testes (usuário pediu arquivar o projeto no pendrive); todos os critérios continuam PENDENTES. IrfanView 4.67 não existe mais no servidor oficial (`irfanview.info/files/` só entrega 4.75 e 4.76); escolhida a 4.75, a mais próxima.

| Instalador | Origem | SHA-256 |
|---|---|---|
| `npp.8.7.Installer.x64.exe` (6 637 056 bytes) | github.com/notepad-plus-plus/notepad-plus-plus, release v8.7 | `23d8e9bde3d08df26626af9978a09f8837d7162fd1accf563248d0eef89006fe` (confere com `npp.8.7.checksums.sha256` da release) |
| `7z2409-x64.msi` (1 987 584 bytes) | www.7-zip.org/a/ | `ec6af1ea0367d16dde6639a89a080a524cebc4d4bedfe00ed0cac4b865a918d8` (o site não publica checksum) |
| `iview475_setup.exe` (3 607 168 bytes) | www.irfanview.info/files/ | `e5dc5357bdda7410feb1893fa24a5c14b2ee1c003e4eaf35c24d2cbcc077eb24` (checksum da 4.75 não está mais publicado; a 4.76 confere com o publicado) |
