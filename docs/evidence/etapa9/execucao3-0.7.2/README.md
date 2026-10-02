# Execução 3 (ISO 0.7.2), 2026-10-01 16:28–16:41: duas falhas, nenhuma aprovada

Rodada logo após a construção da ISO, com o host ainda carregado.

1. `normal/`: "instalador não reabriu". Causa: defeito do laboratório. O teclado virtual (QMP) repetiu teclas e a 2ª senha saiu maior que a 1ª (`normal/e9-02-cancelar-resumo.png`: "As senhas não estão iguais"); o instalador ficou na página de usuários e o roteiro seguiu às cegas.
2. `luks/`: "instalação não iniciou". O Calamares fechou com **Segmentation fault** na página de partições (`luks/e9-luks-04-particoes.png`, 16:39:29), antes de qualquer escrita no disco.

## Experimento de reprodução (mesma ISO)
- `experimento-sem-carga.log`: 3 passagens completas pela página de partições com criptografia, sem carga: nenhuma falha.
- `experimento-com-carga.log`: as mesmas ações com 6 processos lendo a ISO em paralelo (carga média ~7): nenhum fechamento do instalador, mas o teclado virtual perdeu uma tecla (`experimento-carga-senha-com-tecla-perdida.png`: 14 e 13 caracteres) e os cliques seguintes falharam.

## Conclusões
- Tecla perdida/repetida sob carga: **confirmado** como defeito do laboratório. Correção: o teste confere o indicador verde/vermelho do instalador e redigita.
- Fechamento do Calamares: **não reproduzido** em 6 tentativas; 1 ocorrência em ~13 passagens pela página de partições no dia. Causa desconhecida; componente do Debian/upstream (Calamares 3.3.14), não alterado pelo Luma. Sem coredump (a VM foi descartada pelo teste). Fica como risco conhecido da etapa 9.
