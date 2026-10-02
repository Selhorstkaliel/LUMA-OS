# Luma — recuperar o sistema após uma atualização interrompida

Use quando o computador desligou durante uma atualização ou a loja informa que o sistema de pacotes está "travado" ou "inconsistente". Procedimento testado em VM (teste E7-04).

1. Ligue o computador. Se a área de trabalho abrir, abra o **Konsole** (Menu → Konsole). Se não abrir, na tela de login pressione **Ctrl+Alt+F3** e entre com seu usuário e senha de administrador.
2. Execute, um por vez, digitando sua senha quando pedido:
   ```
   sudo dpkg --configure -a
   sudo apt-get -f install
   sudo apt-get update && sudo apt-get upgrade
   ```
3. Confirme que não há pendências: `sudo dpkg --audit` não deve mostrar nada.
4. Reinicie (`sudo reboot`). Se estava no Ctrl+Alt+F3, volte à tela gráfica com **Ctrl+Alt+F1** ou reinicie.

Se o sistema não iniciar mais, escolha no menu do GRUB **Opções avançadas** e o kernel anterior.

## Recuperar pelo pendrive do Luma (sistema não inicia ou senha esquecida)

O item "recovery mode" do menu do GRUB **não funciona no Luma**: a conta root não tem senha (de propósito, não existe senha padrão), e nesse modo o sistema responde "a conta root está travada" e, ao pressionar Enter, segue para a tela de login normal. O caminho de recuperação é o pendrive de instalação. Procedimento testado em VM (teste E9-09), para instalação **sem** criptografia de disco.

1. Ligue o computador pelo pendrive do Luma (tecla do menu de boot do fabricante, em geral F12, F9 ou Esc) e espere a área de trabalho.
2. Abra o **Konsole** e descubra o disco do sistema com `lsblk` (exemplo abaixo: `/dev/sda`, partição 1 = EFI, partição 2 = sistema; em discos NVMe os nomes são `/dev/nvme0n1p1` e `/dev/nvme0n1p2`).
3. Monte o sistema instalado e entre nele:
   ```
   sudo mount /dev/sda2 /mnt
   sudo mount /dev/sda1 /mnt/boot/efi
   for d in dev dev/pts proc sys run; do sudo mount --bind /$d /mnt/$d; done
   sudo chroot /mnt
   ```
4. Dentro do sistema instalado, conforme o problema:
   - senha esquecida: `passwd SEU_USUARIO`
   - pacotes inconsistentes: `dpkg --configure -a` e depois `dpkg --audit` (não deve mostrar nada)
5. Saia e desmonte:
   ```
   exit
   for d in run sys proc dev/pts dev boot/efi; do sudo umount /mnt/$d; done
   sudo umount /mnt
   ```
6. Desligue, retire o pendrive e ligue de novo.

Com o disco criptografado, antes do passo 3 é preciso abrir o volume com a senha do disco (`sudo cryptsetup open /dev/sda2 luma` e montar `/dev/mapper/luma`). Esse caminho ainda não foi testado; sem a senha do disco os dados não podem ser recuperados.

Quem tem acesso físico ao computador e um pendrive consegue fazer o mesmo: sem criptografia de disco, a senha de login não protege os arquivos contra acesso físico.

> Isto recupera os **programas do sistema**. Não substitui backup dos seus arquivos: mantenha cópias dos documentos importantes em outro disco.
