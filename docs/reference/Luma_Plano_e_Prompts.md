# Luma para PC — plano e prompts de execução

Preparado em 29/09/2026. Este documento é uma especificação; nenhum sistema operacional foi implementado ou testado durante sua elaboração.

## Direção recomendada

Construir uma distribuição Linux personalizada para PC x86_64/UEFI, com KDE Plasma 6 e Wayland, aproveitando kernel, compositor, drivers, configurações e aplicativos existentes. Não desenvolver kernel, compositor, navegador ou gerenciador de pacotes próprios no MVP. Usar Qt/QML apenas nas extensões necessárias. Os mockups claro e escuro aprovados são referências visuais, não prova de funcionalidade.

Ponto de partida proposto: Debian stable com Plasma 6 e live-build, desde que a auditoria inicial confirme versões, suporte e integração disponíveis. Fixar a versão/codename e os componentes após verificar documentação oficial. Se houver incompatibilidade concreta, documentar uma alternativa antes de trocar a base. Não misturar repositórios de distribuições ou versões diferentes para forçar dependências.

Para poupar trabalho, o primeiro protótipo deve ser um tema/layout executável no próprio Plasma, em VM. Um protótipo web é opcional para validar interação e não substitui uma sessão de desktop real.

Escopo: desktop, arquivos, rede, áudio, configurações, apps Linux e compatibilidade Windows selecionada. Execução universal de apps Windows e iOS está fora do escopo. Segurança deve ser descrita por controles verificáveis; não prometer equivalência ao iOS. Wine não é uma barreira de segurança.

## Modelos e esforço

Recomendações de uso, não resultado de benchmark deste projeto. Se o nome não estiver no seletor da conta, não presumir acesso nem inventar um equivalente.

| Trabalho | Claude Code | Codex |
|---|---|---|
| Implementação cotidiana e testes focados | Sonnet 5.5, medium | GPT-6.1 Sol, medium |
| Arquitetura, permissões, boot, instalação, recuperação | Sonnet 5.5, high; Opus 5.5, high se a dificuldade justificar | GPT-6.1 Sol, high |
| Textos, documentação e pequenos ajustes já especificados | Sonnet 5.5, low | GPT-6 Luna, low, se disponível |
| Erro complexo após duas tentativas fundamentadas sem avanço | Opus 5.5, high, com reprodução mínima | GPT-6 Astra, high, se disponível, com reprodução mínima |

Não usar max/xhigh como padrão. Configurar modelo e esforço na ferramenta, não apenas no prompt. No Claude Code, usar o seletor /model e /effort medium ou high quando a versão instalada oferecer esses controles. No Codex, escolher modelo e esforço no seletor disponível. Não ativar modos extras ou agentes paralelos por padrão.

A documentação oficial consultada apresenta Sol como equilíbrio entre capacidade/custo e Luna como opção para tarefas focadas; a documentação Anthropic apresenta Sonnet como opção rápida e Opus para trabalho agêntico prolongado. A disponibilidade no seu plano precisa ser conferida. Custos de API não equivalem às franquias de assinaturas. Não há percentual de economia garantido.

## Etapas e critérios de aprovação

Cada etapa pode conter tarefas menores. Concluir somente a tarefa solicitada e seus testes; não tentar produzir o SO inteiro em uma sessão. Estados: NÃO INICIADA, EM ANDAMENTO, BLOQUEADA, APROVADA. Pendência de teste obrigatório impede APROVADA.

| Etapa | Entrega | Verificação que libera a próxima dependência |
|---|---|---|
| 0 — Escopo e ambiente | Inventário de host, CPU, RAM, disco livre, virtualização, GPU e ferramentas; arquitetura e versões; matriz de requisitos | Identificar o que pode ser executado e o que exige VM/hardware. Registrar exclusões e comandos reais. Não instalar nada no disco físico. |
| 1 — Laboratório | Repositório, scripts de preparação e VM Linux limpa com snapshot; CI para verificações leves | VM inicia; acesso de desenvolvimento funciona; snapshot restaura; preparação pode ser repetida sem duplicações. |
| 2 — Identidade e protótipo nativo | Tema claro/escuro, cores, ícones licenciados, wallpaper, dock, painel e lançador | Instalar/remover tema em conta de teste; abrir apps reais; alternar tema; verificar 1366×768 e 1920×1080, teclado e escala. Capturas e checklist. |
| 3 — Sessão de desktop | Pacotes Luma para aplicar layout e preferências, janelas, notificações, bloqueio e pesquisa | Login/logout/reboot preservam configurações; mover, minimizar, maximizar e fechar janelas; Alt+Tab; bloqueio exige autenticação; usuário novo recebe defaults. |
| 4 — Integrações reais | Central de controle para rede/áudio/energia e atalhos para configurações existentes | Alterar volume real, conectar rede, tratar falha e ausência de dispositivos; reiniciar sem perder preferências. Brilho e Wi-Fi físicos só aprovados no hardware correspondente. |
| 5 — Aplicativos Linux | Integração de loja existente, Flatpak/portais quando disponíveis, associações e arquivos | Instalar, abrir, atualizar e remover app; abrir/salvar documento; validar permissão de arquivos e caminhos com espaços. Não criar catálogo fictício. |
| 6 — Windows selecionado | Wine/Bottles conforme suporte verificado; Proton apenas se jogos entrarem no escopo | Escolher 3 aplicativos e versões; testar instalação, abertura, função principal e desinstalação. Registrar falhas. Um prefixo separado não comprova isolamento. Jogos/GPU exigem hardware adequado. |
| 7 — Segurança e atualização | Modelo de ameaças, permissões mínimas, políticas de elevação, firewall, fontes assinadas e recuperação | Usuário comum não modifica sistema; ação privilegiada nega acesso indevido; assinatura inválida rejeitada; atualizar e recuperar em VM. Registrar cobertura real de sandbox e exceções. |
| 8 — Imagem live | Receita de build versionada, ISO, manifesto, checksum e logs | Build em ambiente limpo; boot UEFI da ISO chega ao desktop; arquivos Luma presentes; apps abrem. Repetir build e explicar diferenças; não alegar reprodutibilidade bit a bit sem comprovação. |
| 9 — Instalação e recuperação | Instalador existente integrado, usuário, idioma/teclado, criptografia quando suportada, documentação | Instalar apenas em disco virtual vazio; retirar ISO e reiniciar; login, atualização e recuperação funcionam. Falhas e cancelamento testados com snapshots. |
| 10 — Hardware e desempenho | Matriz de máquinas/GPU, modo com efeitos reduzidos, relatório de medições | Testar áudio, rede, USB, monitores, suspensão e retomada em hardware disponível. Comparar com a base original no mesmo equipamento. |
| 11 — Alpha utilizável | Release candidata, instruções, limitações, licenças, política de atualização e canal de bugs | Fluxo completo ISO → instalação → login → rede → app → salvar → atualizar → reiniciar → recuperar. Sem falha bloqueadora conhecida. Publicação depende de autorização específica. |

Segurança, testes e empacotamento começam nas etapas anteriores; a etapa 7 é uma revisão integrada, não o primeiro momento de pensar em segurança. A etapa 6 pode ser adiada sem impedir uma alpha Linux. Se os três aplicativos prioritários não forem definidos, marcar essa compatibilidade como pendente.

### Medição de desempenho

Definir um perfil de VM, por exemplo 4 vCPU, 8 GiB de RAM e disco virtual de 64 GiB, condicionado aos recursos reais do host. Este é um perfil de laboratório, não requisito mínimo de produto. Registrar hipervisor, aceleração, resolução, versões e carga do host.

Medir base e Luma sob condições iguais: tempo até desktop utilizável, memória 60 segundos após login, CPU ociosa, disco utilizado e abertura de arquivos/configurações. Executar pelo menos 3 medições por cenário e registrar mediana e variação. Não comparar VM com hardware real. Proposta de meta inicial a validar: acréscimo de RAM ociosa até 15% e tempo de boot até 10% sobre a base equivalente. Se a meta falhar, investigar antes de remover recursos. Não afirmar 60 FPS se a taxa não foi medida. Nunca sacrificar atualizações, bloqueio ou verificação de assinaturas para ganhar desempenho.

### Segurança e instalação

O host pode ser Windows, mas os testes de boot/desktop precisam de VM Linux adequada. WSL ou contêiner isoladamente não comprovam boot, drivers ou instalação do SO. Não alterar partições, bootloader ou Secure Boot do host. Secure Boot do produto é uma entrega separada que requer cadeia de assinatura e teste; reaproveitar uma distribuição não comprova suporte na ISO customizada. LUKS deve ser testado no instalador e na recuperação quando incluído. Recuperação de sistema não equivale a backup de dados pessoais.

## Como usar os prompts

1. Abra o repositório no Claude Code OU no Codex com acesso a arquivos e terminal. Conversa sem terminal pode produzir orientação, mas não validar o sistema.
2. Anexe as duas imagens aprovadas e coloque-as em docs/design/references/ quando possível. Se ausentes, a IA deve registrar isso.
3. Cole o prefixo da ferramenta escolhida, seguido do prompt mestre abaixo, uma vez.
4. Execute inicialmente a etapa 0. Depois use o comando curto de continuação para uma etapa ou subtarefa.
5. Não mande Claude e Codex editar os mesmos arquivos simultaneamente. Ao trocar de ferramenta, use o estado documentado do projeto.

## Prefixo para Claude Code

```text
Você está trabalhando no Claude Code dentro do repositório Luma. Leia CLAUDE.md e as instruções existentes antes de editar. Preserve-as. Se CLAUDE.md não existir, crie um arquivo curto apontando para docs/LUMA_SPEC.md e docs/STATUS.md, sem duplicar a especificação. Execute alterações e testes pelas ferramentas disponíveis. Não use agentes paralelos por padrão. O modelo e o esforço são escolhidos por mim no aplicativo; não afirme que os alterou por este prompt. Se faltar capacidade de VM, registre o bloqueio concreto e conclua somente os trabalhos que puder verificar.
```

## Prefixo para Codex

```text
Você está trabalhando no Codex dentro do repositório Luma. Leia AGENTS.md e as instruções aplicáveis aos diretórios antes de editar. Preserve-as. Se AGENTS.md não existir, crie um arquivo curto apontando para docs/LUMA_SPEC.md e docs/STATUS.md, sem duplicar a especificação. Execute alterações e testes pelas ferramentas disponíveis. Não use agentes paralelos por padrão. O modelo e o esforço são escolhidos por mim no aplicativo; não afirme que os alterou por este prompt. Se faltar capacidade de VM, registre o bloqueio concreto e conclua somente os trabalhos que puder verificar.
```

## Prompt mestre — comum às duas ferramentas

```text
Atue como engenheiro de sistemas Linux responsável pelo projeto Luma para PC. Implemente incrementos pequenos, teste-os, corrija falhas e documente evidências. Não produza apenas sugestões quando houver ferramentas e ambiente para executar a tarefa.

OBJETIVO
Criar uma distribuição Linux personalizada x86_64/UEFI, utilizável e mantida, com visual inspirado nos mockups Luma claro/escuro: dock flutuante, painel superior, central de controle, janelas arredondadas, transparência moderada e navegação por teclado/mouse. Interface em pt-BR, com estrutura preparada para tradução. Priorizar estabilidade, legibilidade, acessibilidade e consumo de recursos.

LIMITES
- Não criar kernel, compositor, navegador, sistema de autenticação, criptografia ou gerenciador de pacotes próprios.
- Não prometer execução universal de Windows ou iOS, nem segurança equivalente ao iOS.
- Não apresentar páginas web, imagens ou dados simulados como sistema operacional real.
- Não copiar ativos proprietários; usar ícones/fontes licenciados e registrar atribuições.
- Não implementar nuvem, contas online, telemetria, IA integrada ou sincronização no MVP.

BASE TÉCNICA
Ponto de partida: Debian stable, KDE Plasma 6, Wayland/KWin, Qt/QML e live-build. Primeiro valide versões suportadas, pacotes e documentação oficiais; fixe codename e versões relevantes. Não misture repositórios incompatíveis. Se a base não atender, registre o impedimento e uma decisão arquitetural antes de substituí-la.
Reutilize Dolphin, configurações e loja existentes quando adequados. Use APIs do desktop e serviços como NetworkManager, PipeWire e portais conforme suporte confirmado. Verifique assinaturas/interfaces reais antes de escrever integração. Não invente APIs. Interface sem privilégios; elevação apenas por mecanismo existente e escopo mínimo. Prefira tema, layout e widgets existentes antes de criar extensões próprias. Não faça fork do Plasma no MVP.
Wine/Bottles são compatibilidade opcional, não isolamento. Apps Windows rodam sem root e com acessos minimizados; valide o sandbox efetivo. iOS fica fora do MVP.

INÍCIO
1. Inspecione instruções do projeto, estado Git e arquivos relevantes. Preserve mudanças existentes; não faça reset ou limpeza destrutiva.
2. Identifique host, recursos, ferramentas, acesso à rede, capacidade de virtualização e presença de ambiente gráfico.
3. Leia as referências visuais anexadas. Se faltarem, registre a ausência; não invente aprovação visual.
4. Registre uma proposta verificável de versões, laboratório, dependências e limites. Não instale o SO no host.
5. Crie ou atualize documentação enxuta: docs/LUMA_SPEC.md (escopo e etapas), docs/STATUS.md (estado atual), docs/TESTS.md (matriz), docs/decisions/ (decisões relevantes). Não sobrescreva instruções existentes.

ETAPAS
0. Auditar ambiente e fechar escopo/versões verificadas.
1. Preparar laboratório, VM com snapshot, scripts idempotentes e verificações básicas.
2. Implementar tema/layout nativo claro/escuro conforme referências; testar instalação e remoção.
3. Empacotar sessão Luma; validar janelas, atalhos, notificações, bloqueio e persistência.
4. Integrar rede, áudio e energia reais, incluindo falhas e dispositivos ausentes.
5. Integrar apps Linux, permissões de arquivos, associações, instalação/atualização/remoção.
6. Adicionar compatibilidade Windows para três apps/versões explicitamente definidos. Sem definição, registrar bloqueio dessa etapa, sem bloquear etapas independentes.
7. Revisar permissões, fontes/assinaturas, atualização, firewall e recuperação em VM.
8. Gerar ISO live com build documentado, manifesto, checksum e teste UEFI.
9. Integrar instalador existente; testar instalação e recuperação somente em disco virtual descartável.
10. Testar hardware disponível, acessibilidade e desempenho contra a base original.
11. Preparar alpha e executar fluxo completo; listar limitações reais e manutenção necessária.

CONTRATO DE CADA TAREFA
Antes de implementar, registre objetivo, pré-condições, arquivos/componentes envolvidos e critérios de aceite observáveis. Para critérios novos, atualize docs/TESTS.md antes de declarar sucesso.
Implemente o menor incremento completo que atenda ao objetivo. Execute testes apropriados, examine a falha, formule hipótese baseada na evidência e corrija a causa. Reexecute o teste afetado e uma regressão relevante. Não remova ou enfraqueça teste para esconder problema; só altere expectativa quando o requisito demonstravelmente estiver errado e registre por quê.
Se duas tentativas fundamentadas não trouxerem avanço, interrompa o ciclo repetitivo: salve reprodução mínima, logs e hipóteses descartadas; indique a próxima investigação ou necessidade de modelo mais forte. Não abandone tarefas independentes que ainda possam ser concluídas.

TESTES OBRIGATÓRIOS CONFORME A MUDANÇA
- Scripts: validação sintática, ShellCheck quando aplicável, erro de dependência e repetição sem duplicações.
- Lógica própria: testes unitários de comportamento relevante, não testes que apenas repetem a implementação.
- QML: lint e testes de componentes quando úteis; UI real exige sessão gráfica e inspeção visual.
- Integrações: serviço real em VM, caminho feliz, indisponibilidade e acesso negado.
- Desktop: teclado/mouse, foco visível, tema claro/escuro, persistência, 1366x768/1920x1080 e escala. Capturar telas e corrigir cortes/contraste.
- Boot/instalação: VM UEFI, disco virtual vazio, reboot sem ISO e recuperação por snapshot.
- Segurança: acesso indevido negado, elevação restrita, atualização adulterada rejeitada e recuperação após falha controlada em VM.
- Hardware: classificar Wi-Fi, Bluetooth, brilho, suspensão, GPU e monitores como pendentes se não houver dispositivo apropriado. Ethernet virtual não comprova Wi-Fi físico.
- Desempenho: comparar base e Luma no mesmo ambiente; 3 medições, mediana e variação. Definir e registrar metas antes de otimizar.

EVIDÊNCIAS E ESTADOS
Para cada teste registre identificador do requisito, comando/procedimento, ambiente/versões, resultado esperado, resultado observado, status e caminho do log/captura. Status: PASSOU, FALHOU ou NÃO EXECUTADO, com motivo. Não invente resultados nem diga 'todos passaram' se houver teste obrigatório não executado.
Uma etapa só fica APROVADA com critérios obrigatórios demonstrados. Falta de ferramenta gera BLOQUEADA e instruções exatas para executar o teste em outro ambiente. Arquivo escrito não significa software compilado; compilação não significa boot validado; boot não significa hardware validado.
Mantenha docs/STATUS.md curto: etapa/tarefa, alterações, verificações, limitações e próximo comando. Preserve logs completos em arquivos, sem despejá-los no chat.

SEGURANÇA OPERACIONAL
Trabalhe em VM e imagens de disco descartáveis. Nunca particione discos físicos, altere bootloader/Secure Boot do host, publique release, envie código remoto ou exponha segredos sem autorização específica. Inspecione scripts externos; não use curl|sh. Não desative verificação de assinatura, firewall ou controle de acesso para fazer teste passar. Nunca committe chaves de assinatura nem credenciais. Não crie senha padrão permanente. Não alegue suporte a Secure Boot sem validar a cadeia real da imagem customizada.

ECONOMIA DE CONTEXTO
Não releia o repositório inteiro a cada turno. Consulte STATUS, a seção pertinente da especificação e arquivos afetados. Use buscas direcionadas e diffs. Evite novas dependências, refatorações e documentação volumosa fora do objetivo. Não execute novamente testes caros se nada mudou e não há risco novo. Não reconstrua ISO a cada ajuste de cor; teste o pacote na VM primeiro. Não use multiagentes automaticamente. Não copie toda a especificação nas respostas.
Em troca de modelo ou sessão, use os arquivos de estado; não recomece o projeto. Não prometa economia percentual de tokens. Se a ferramenta mostrar uso/custo, registre por tarefa; caso contrário, não invente.

FORMATO DA ENTREGA
Responda brevemente com: tarefa concluída; principais mudanças; testes e evidências; pendências/riscos; próximo passo. Resumo usual até 300 palavras, com detalhes nos arquivos. Não imprima arquivos inteiros que já editou.

EXECUÇÃO DESTA PRIMEIRA SESSÃO
Execute SOMENTE a etapa 0 e prepare a especificação das etapas seguintes. Não implemente todas as etapas de uma vez. Faça inspeções reversíveis sem pedir confirmação repetida. Pergunte apenas por informação realmente impeditiva que não possa obter do ambiente. Termine indicando se a etapa 0 foi aprovada ou bloqueada, e a primeira tarefa concreta da etapa 1.
```

## Comando curto para continuar

```text
Leia as instruções do repositório e docs/STATUS.md. Execute somente a próxima tarefa pendente da etapa [N], conforme docs/LUMA_SPEC.md e os critérios de docs/TESTS.md. Implemente, teste, corrija e revalide o necessário. Preserve o trabalho existente. Não avance com teste obrigatório falhando ou não executado. Não reconstrua partes já aprovadas sem motivo. Atualize o estado e entregue evidências resumidas.
```

## Comando para diagnóstico com modelo mais forte

```text
Investigue somente o bloqueio descrito em docs/STATUS.md. Leia a reprodução e os logs referenciados antes de editar. Identifique a causa provável, execute um teste que diferencie as hipóteses e aplique a menor correção sustentada pela evidência. Não reescreva a arquitetura sem demonstrar necessidade. Valide a correção e uma regressão relevante. Se faltar ambiente, explique exatamente o teste pendente; não declare sucesso.
```

## Comando de revisão de marco

```text
Revise o diff e as evidências do marco [N]. Priorize defeitos concretos de comportamento, permissões, boot, persistência e recuperação. Não faça refatoração estética. Para cada problema cite arquivo, condição de reprodução, impacto e teste necessário. Corrija os problemas dentro do escopo, revalide e atualize o estado. Não aprove critérios sem evidência. Não publique a entrega.
```

## Economia sem perder controle

Use uma ferramenta principal por tarefa. A segunda pode revisar marcos de segurança, ISO e instalação, lendo o diff e evidências; não precisa repetir todo o desenvolvimento. Comece pelo modelo equilibrado em medium. Suba para high quando houver raciocínio de arquitetura ou risco de privilégio/boot; use um modelo mais forte só para dificuldade real. Reduza esforço nas alterações mecânicas delimitadas. O menor preço por token nem sempre gera o menor custo por tarefa corrigida.

## Fontes oficiais consultadas

- OpenAI, modelos e esforço: https://developers.openai.com/api/docs/guides/latest-model
- Anthropic, catálogo: https://platform.claude.com/docs/en/models/overview
- Claude Code, seleção/configuração: https://code.claude.com/docs/en/model-config
- Claude, esforço: https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings
- KDE, estilos Plasma: https://develop.kde.org/docs/plasma/theme/quickstart/

As versões de distribuição e APIs operacionais devem ser revalidadas na etapa 0; as tecnologias acima são uma proposta de arquitetura, não uma combinação já testada neste projeto.
