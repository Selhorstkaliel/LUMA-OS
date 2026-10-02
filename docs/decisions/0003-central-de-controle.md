# 0003 — Central de controle no MVP

Status: aceita (etapa 4), 2026-09-30.

## Contexto
O plano pede uma central de controle para rede, áudio e energia, preferindo widgets existentes a extensões próprias. Os mockups não estão disponíveis.

## Verificado na VM (Plasma 6.3.6, trixie)
Bandeja do sistema já inclui `org.kde.plasma.networkmanagement` (NetworkManager 1.52), `org.kde.plasma.volume` (PipeWire 1.4/WirePlumber), `org.kde.plasma.brightness` e `org.kde.plasma.battery` (PowerDevil, power-profiles-daemon), `org.kde.plasma.bluetooth` e `org.kde.plasma.notifications`; atalhos de volume já associados. Cada applet leva ao módulo correspondente das Configurações do sistema.

## Decisão
A central de controle do MVP é a bandeja do painel superior do layout Luma com esses applets. Nenhum plasmoide próprio, nenhuma chamada privilegiada nova: as ações passam por NetworkManager, PipeWire e power-profiles-daemon com as políticas polkit do Debian.

## Consequências
- Menos código para manter e nenhuma nova superfície de privilégio.
- Um painel unificado no estilo dos mockups (botões rápidos) fica para depois dos mockups, como plasmoide QML que só use as mesmas APIs.
