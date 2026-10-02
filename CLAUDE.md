# Luma — instruções do repositório

- Especificação e etapas: [docs/LUMA_SPEC.md](docs/LUMA_SPEC.md). Plano original completo: [docs/reference/Luma_Plano_e_Prompts.md](docs/reference/Luma_Plano_e_Prompts.md).
- Estado atual e próximo passo: [docs/STATUS.md](docs/STATUS.md). Matriz de testes: [docs/TESTS.md](docs/TESTS.md). Decisões: [docs/decisions/](docs/decisions/).
- Executar uma tarefa por vez; não declarar APROVADA sem evidência registrada em docs/TESTS.md.
- Nunca particionar discos físicos, alterar bootloader/Secure Boot do host, publicar, fazer push ou commitar segredos sem autorização específica.
- Host é Windows 11; boot/desktop/instalação só são validados em VM Linux UEFI.
