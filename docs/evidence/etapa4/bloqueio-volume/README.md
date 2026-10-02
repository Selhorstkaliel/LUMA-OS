# E4-06: volume "não persistia" após reinício — RESOLVIDO (artefato do laboratório)

Status: **resolvido em 2026-10-01**. Não é defeito do produto no uso normal (um usuário na sessão gráfica).

## Causa raiz (confirmada com controle)
A conta `luma` do laboratório (usada pelo SSH dos testes) é membro do grupo `audio` (padrão do instalador
Debian para o primeiro usuário). A cada reinício, a primeira conexão SSH dos testes inicia o gerenciador de
usuário de `luma` e, com ele, um segundo WirePlumber. Pelo grupo `audio` ele abre a placa mesmo sem estar no
assento e aplica o volume da própria conta (padrão 40 %) no **mixer de hardware compartilhado**. O WirePlumber
do usuário em teste, que já tinha restaurado 63 %, vê a mudança externa (`mixer changed`) e a grava como novo valor.

| Cenário | Definido | Após reinício |
|---|---|---|
| `luma` no grupo `audio` (controle) | 63 % | 40 % |
| `luma` fora do grupo `audio` | 63 % | 63 % |
| `luma` fora do grupo `audio` | 27 % | 27 % |

Evidência: `investigacao-8.log` (processos que abrem `/dev/snd/controlC0`: wireplumber de `teste` e, 1,2 s depois,
de `luma`), `investigacao-9.log` (tabela acima), `log-A-sessao-funciona.txt` × `log-B-boot-falha.txt`
(`Set hardware volume: 41287` seguido de `mixer changed` externo até 26291).

## Hipóteses descartadas com evidência
1. Porta ativa diferente após o boot — mesma porta `analog-output-lineout`.
2. Estado não gravado antes do desligamento — arquivo correto antes de qualquer login (`investigacao-3.log`).
3. Endereço PCI da placa — igual.
4. API Pulse × wpctl — ambas gravam o mesmo valor.
5. WirePlumber não restaura — restaura ao reiniciar o serviço e na partida a frio da pilha (`investigacao-3/6`).
6. Áudio da tela de login (usuário `sddm`) — não há processos de áudio do `sddm`; mascará-los não mudou nada (`investigacao-5.log`).
7. Estado do mixer de hardware no boot (`alsactl restore`, `asound.state` antigo) — três variações mantêm o valor (`investigacao-7.log`).

## Correções
- Laboratório: `scripts/lab/guest/setup-test-user.sh` remove `luma` do grupo `audio`.
- Produto (requisito para a etapa 9): o instalador **não** deve colocar usuários no grupo `audio`; o acesso ao som
  é dado por sessão pelo logind. Com o grupo, contas fora da tela alcançam a placa (inclusive o microfone) e
  usuários que compartilham o PC sobrescrevem o volume uns dos outros.

## Observado e não tratado
`/var/lib/alsa/asound.state` não é atualizado no desligamento (data da instalação). Não afetou a persistência
do volume do usuário nos testes; fica registrado.
