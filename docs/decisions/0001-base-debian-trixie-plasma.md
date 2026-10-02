# 0001 — Base: Debian 13 "trixie" + KDE Plasma 6.3 + live-build

Status: aceita (etapa 0), 2026-09-30.

## Contexto
O plano propõe Debian stable, Plasma 6/Wayland e live-build, condicionado à verificação das versões.

## Decisão
- Base: **Debian 13 (trixie)**, amd64, UEFI. Repositórios: `trixie`, `trixie-updates`, `trixie-security`. `trixie-backports` somente por decisão registrada e pacote a pacote.
- Desktop: Plasma 6.3.6 com KWin Wayland, SDDM 0.21, Qt 6.8.
- Serviços: NetworkManager 1.52, PipeWire 1.4, Flatpak 1.16 + xdg-desktop-portal-kde, Discover 6.3.
- Build: live-build 1:20250505+deb13u1, executado em VM/ambiente Debian trixie (não no Windows).
- Instalador candidato: Calamares 3.3.14 (a confirmar na etapa 9 contra debian-installer).

## Consequências
- Nenhuma mistura com Ubuntu/Debian testing/sid.
- Recursos exclusivos de Plasma ≥ 6.4 ficam fora do MVP.
- Secure Boot: shim/grub/kernel assinados pelo Debian funcionam, mas módulos ou kernel próprios quebram a cadeia; suporte na ISO Luma só será declarado após teste (etapa 8/9).
- Revisar a decisão se um ponto release de trixie remover algo necessário ou se Debian 14 virar stable durante o projeto.
