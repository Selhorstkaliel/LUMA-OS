# 0007 — Compatibilidade com aplicativos Windows

Status: aceita pelo usuário para a etapa 6, 2026-10-01.

Decisões do usuário (2026-10-01): **só o Wine do Debian, sem Bottles**; **`i386` habilitado**, medindo o aumento da ISO; aplicativos da camada 2: Notepad++ 8.7 x64 (`.exe`), 7-Zip 24.09 x64 (`.msi`), IrfanView 4.67 32 bits (`.exe`) — a 4.67 não existe mais no servidor oficial, usada a 4.75. As "pendências" abaixo ficam resolvidas por estas decisões.

## Contexto
O plano original limita a etapa 6 a três aplicativos Windows definidos e proíbe prometer execução universal. O usuário pediu que o sistema tente abrir qualquer aplicativo Windows, mantendo a garantia só para o que for testado.

## Decisão
A etapa 6 passa a ter duas camadas:

1. **Melhor esforço (sem garantia).** A Luma entrega a camada de compatibilidade já instalada e configurada, e o duplo clique num `.exe` ou `.msi` abre o programa por ela. Nada é prometido sobre o resultado.
2. **Três aplicativos testados.** Para cada aplicativo e versão escolhidos pelo usuário: instalação, abertura, função principal e desinstalação, com evidência em `docs/TESTS.md`. Só estes podem ser descritos como "funcionam na Luma".

A execução universal continua fora do MVP: a documentação do usuário diz "pode funcionar" para a camada 1 e lista por nome o que foi testado na camada 2.

## Fatos verificados (Debian trixie, 2026-10-01, `apt-cache policy`)
- `wine` e `wine64` 10.0~repack-6 estão em `trixie/main`.
- `wine32` não tem candidato sem a arquitetura `i386` habilitada; sem ela, programas e instaladores de 32 bits não abrem.
- `winetricks` não tem candidato em `main` (está em `contrib`).
- **`bottles` não existe no Debian trixie.** O projeto distribui só por Flatpak (Flathub).

## Pendências que a etapa precisa resolver antes de implementar
- **Origem do Bottles:** exige o Flathub, que hoje não é pré-configurado (decisão 0004, pendente do usuário). Alternativas: entregar só o Wine do Debian com a associação de `.exe`, ou pré-configurar o Flathub só para o Bottles.
- **`i386`:** habilitar multiarch na imagem aumenta a ISO e a superfície de atualização; decidir e medir.
- **Aviso de segurança no primeiro uso:** Wine/Bottles não são barreira de segurança; um prefixo separado não isola do `$HOME` (`docs/security/modelo-de-ameacas.md`). O programa roda sem root.

## Critérios de aceite
| Camada | Critério |
|---|---|
| 1 | Pacote(s) instalam e removem sem resíduos; duplo clique em `.exe` e `.msi` no Dolphin abre pela camada de compatibilidade; `.exe` inválido mostra erro legível, sem travar a sessão; nada roda como root; aviso de segurança exibido. |
| 2 | Para cada um dos três aplicativos: instalar, abrir, executar a função principal, desinstalar. Falhas registradas como falhas, não contornadas em silêncio. |

## Limites
- Jogos e aplicativos que dependem de GPU não são validáveis no laboratório (VM sem aceleração 3D); ficam para hardware real (etapa 10) ou fora do escopo.
- Não funcionam e não serão tratados: anti-cheat em kernel, drivers do Windows, aplicativos da Microsoft Store (UWP).
