# 0004 — Loja de aplicativos e fontes de software

Status: aceita para o MVP (etapa 5), 2026-09-30. **Flathub: decisão pendente do usuário.**

## Decisão
- Loja: **Discover** (plasma-discover 6.3.6) com PackageKit sobre o APT do Debian trixie (repositórios assinados; `apt-secure`). Sem catálogo próprio.
- Instalar, atualizar e remover exigem autenticação de administrador pelo polkit (política padrão do Debian); sessões remotas ou inativas não são autorizadas.
- Suporte a Flatpak instalado (`flatpak`, `plasma-discover-backend-flatpak`) e portais (`xdg-desktop-portal-kde`), recomendados por `luma-session`.
- **Nenhum remoto Flatpak pré-configurado.** Adicionar o Flathub coloca uma fonte de terceiros (com apps de verificação variável e permissões declaradas pelo próprio app) ao lado do Debian; é decisão de produto e de segurança, registrada como pendente. Enquanto isso, o usuário pode adicioná-lo pelo Discover.

## Consequências
- Atualizações de segurança chegam pelo `trixie-security` via Discover/PackageKit.
- Revisar na etapa 7 (fontes/assinaturas) e quando o usuário decidir sobre o Flathub.
