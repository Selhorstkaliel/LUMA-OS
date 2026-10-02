# Execução 2 (ISO 0.7.1): interrompida, 1 falha

- Interrompida durante a instalação completa pelo limite de 2 h da tarefa que também construía a ISO (não é falha do produto).
- "atalho Instalar o Luma na área de trabalho": falha real e intermitente (não ocorreu na execução 1 nem numa inicialização de conferência com a mesma ISO). Causa provável: o script do atalho e o `xdg-user-dirs-update` iniciam na mesma fase do login; quando o atalho roda primeiro, vai para `~/Desktop`. A pasta de destino não foi capturada na inicialização que falhou, por isso a causa fica como provável. Corrigido na 0.7.2 (o script cria as pastas antes) e conferido em todas as inicializações da ISO no teste.
