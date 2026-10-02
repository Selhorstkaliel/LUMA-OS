# Luma — modelo de ameaças (MVP)

Versão 2026-10-01. Cada controle aponta para o teste que o demonstra em `docs/TESTS.md`. O que não tem teste não é prometido.

## Ativos
1. Documentos e credenciais do usuário (`/home/<usuário>`).
2. Integridade do sistema (`/usr`, `/etc`, carregador de boot, pacotes).
3. Disponibilidade da sessão (conseguir entrar, atualizar e recuperar).

## Adversários considerados
| Adversário | Exemplo | Fora do escopo |
|---|---|---|
| Rede local ou pública | Varredura de portas, serviço exposto | Ataque a Wi-Fi físico (sem hardware testado) |
| Fonte de software comprometida | Espelho adulterado, repositório com chave errada | Comprometimento da própria chave do Debian |
| Outro usuário local sem privilégio | Ler arquivos de outra conta, mudar o sistema | Usuário com acesso físico e disco sem criptografia |
| Aplicativo malicioso instalado pelo usuário | App nativo lendo `$HOME` | **Não mitigado para apps nativos** (ver abaixo) |
| Falha de energia/atualização interrompida | Corte durante o `dpkg` | Falha de hardware do disco |

## Controles verificados
| Controle | Mecanismo (existente, sem código próprio de segurança) | Evidência |
|---|---|---|
| Entrada de rede bloqueada por padrão | `luma-firewall` ativa ufw (deny incoming) uma vez; admin pode mudar | E7-01 |
| Ações de sistema exigem administrador | polkit do Debian; sessões remotas/inativas não autorizadas | E4-04, E5-01/02, E7-02 |
| Usuário comum não altera o sistema | Permissões Unix, sudo restrito ao grupo `sudo` | E7-02, E1-03 |
| Isolamento entre contas | Home com modo 700 | E5-08 |
| Pacotes assinados | apt-secure: chave não confiável e índice adulterado rejeitados | E7-03 |
| Tela bloqueada exige senha | kscreenlocker | E3-06 |
| Boot com Secure Boot (ISO e sistema instalado) | shim/grub/kernel assinados pelo Debian; entrada de boot continua `Debian` | E1-02, E8, E9-05 |
| Recuperação de atualização interrompida | `dpkg --configure -a`, `apt-get -f install` | E7-04 |
| Sem senha padrão | Instalador exige senha do usuário; root bloqueado; sem login automático | E9-05 |
| Sem acesso de root pela tela sem senha | "recovery mode" do GRUB recusa (root bloqueado) | E9-08 |
| Dados em repouso (opcional) | Disco cifrado com LUKS pelo instalador: raiz e swap cifradas, senha pedida no boot | E9-10 |
| Usuário novo fora do grupo `audio` | Configuração do instalador | E9-05 |

## Limites conhecidos (sem promessas)
- **Apps nativos (APT) não são confinados.** Um app instalado pelo usuário roda com as permissões do usuário e lê o `$HOME`. O AppArmor do Debian confina apenas os programas com perfil (lista real em E7-05).
- **Flatpak** oferece sandbox declarativo por app; o nível depende das permissões que cada app pede. Nenhum remoto é pré-configurado (decisão 0004).
- **Wine/Bottles não são barreira de segurança** (etapa 6). Um prefixo separado não isola do `$HOME`.
- **Sem equivalência a iOS**: não há assinatura obrigatória de apps, revisão de loja nem isolamento universal.
- Contas no grupo `audio` acessam a placa de som e o microfone mesmo fora da sessão ativa (constatado na etapa 4). O instalador do Luma não usa esse grupo (E9-05); o acesso vem da sessão do logind. O usuário da **sessão live** continua nesse grupo (padrão do live-config).
- Sem criptografia de disco (padrão do instalador), quem tem acesso físico lê e altera tudo: iniciar por um pendrive basta para trocar senhas (é o próprio procedimento de recuperação, E9-09). A criptografia é opcional e precisa ser marcada na instalação.
- Com disco cifrado, a partição EFI (carregador de boot) continua em claro; a recuperação pelo pendrive com disco cifrado não foi testada.
- O menu do GRUB não tem senha (padrão do Debian); o efeito de editar os parâmetros de boot pelo teclado não foi testado.
- Recuperação de sistema não substitui backup de dados pessoais.
