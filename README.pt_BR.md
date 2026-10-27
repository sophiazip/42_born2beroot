<p align="center">
  <i>Este projeto foi criado como parte do currículo da 42 por eroque-d</i>
</p>
<h1 align="center">Born2beRoot</h1>
<p align="center">
  <strong>Um pequeno servidor, para entender o que funciona por baixo dele</strong>
</p>

## Descrição

O Born2beRoot apresenta virtualização e administração de sistemas por meio da
configuração de um servidor Linux seguro no VirtualBox ou UTM. Este repositório
oferece scripts para personalizar uma ISO do instalador do Debian estável e
configurar os serviços e as políticas obrigatórias: LVM criptografado, SSH na
porta 4242, UFW, AppArmor, regras de senha, registros do sudo e um relatório de
monitoramento.

Os scripts preparam o instalador e configuram o sistema instalado; eles não criam
a máquina virtual nem o disco virtual, não geram a assinatura do disco e não
substituem a verificação do resultado nem o entendimento de cada configuração.
O Debian Installer ainda solicita a senha de criptografia do disco. Os hashes das
senhas das contas ficam embutidos na ISO gerada, então mantenha-a privada e não a
adicione ao repositório.

## Compilação e uso

Instale as ferramentas no Debian ou Ubuntu:

```sh
sudo apt install xorriso openssl coreutils
```

Baixe uma imagem oficial netinst amd64 do Debian estável no
[site de imagens de CD do Debian](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/)
e gere o instalador personalizado:

```sh
scripts/build-iso.sh debian-stable-amd64-netinst.iso born2beroot.iso
```

O script pede seu login da 42 (sem o sufixo `42` do hostname) e, em seguida, as
senhas do root e do usuário. Ele verifica o tamanho e as classes de caracteres das
senhas e grava seus hashes SHA-512 na ISO gerada. Não adicione essa ISO ao
repositório. Use uma máquina virtual com um disco vazio de pelo menos 20 GB e
acesso à rede; o particionamento guiado com LVM criptografado apaga o disco
selecionado.

Inicialize a máquina virtual pela `born2beroot.iso`. No menu de inicialização do
Debian Installer, edite a opção **Install** (`e` no GRUB ou `Tab` no menu BIOS) e
acrescente:

```text
auto=true priority=critical preseed/file=/cdrom/preseed.cfg
```

Inicialize pela opção editada e digite a senha do LVM criptografado quando
solicitado. Depois da instalação, inicialize pelo disco virtual e remova a ISO. No
console da máquina virtual, troque as senhas iniciais do root e do usuário quando
solicitado; isso aplica as regras de qualidade e histórico configuradas. Em
seguida, conecte-se com:

```sh
ssh -p 4242 <seu-login>@<ip-da-vm>
```

> O instalador precisa de acesso à rede para baixar os pacotes. O firewall permite
> somente conexões de entrada pela porta TCP 4242.

## Estrutura do código

A configuração segue estas etapas:

1. `scripts/build-iso.sh` pede os dados das contas, gera um preseed e adiciona o
   arquivo e os scripts de instalação a uma ISO inicializável usando `xorriso`.
2. O Debian Installer particiona o disco da máquina virtual com LVM criptografado
   e instala o sistema Debian mínimo e os pacotes necessários.
3. `scripts/late-install.sh` configura o hostname e os grupos do usuário, SSH, UFW,
   sudo, qualidade de senha via PAM, validade das senhas, AppArmor e cron.
4. O cron executa `scripts/monitoring.sh` na inicialização e a cada dez minutos,
   transmitindo o relatório aos terminais conectados com `wall`.

## Organização dos arquivos

```text
scripts/
├── build-iso.sh       gera uma ISO personalizada do instalador Debian
├── late-install.sh    configura segurança e serviços no sistema instalado
├── monitoring.sh      exibe informações do sistema e uso de recursos
└── tests_vm.sh        diversos testes para verificar se as configurações da VM estão corretas em relação ao subject
```

## Escolhas de projeto

O Debian estável é recomendado pelo subject e oferece uma instalação mínima para
servidores, um amplo ecossistema de pacotes e administração direta com `apt`. Seu
modelo de versões estáveis prioriza pacotes testados. O Rocky Linux é mais próximo
do ecossistema Red Hat Enterprise Linux e costuma usar `dnf` e SELinux, mas exige
uma configuração diferente e não foi escolhido para este projeto.

O instalador usa LVM criptografado para o sistema e a área de swap. O login de root
via SSH fica desativado, o usuário da 42 pertence aos grupos `user42` e `sudo`, e o
UFW permite conexões SSH de entrada pela porta 4242. Nenhum ambiente gráfico é
instalado. O AppArmor é ativado na inicialização, e o cron executa o monitoramento
periódico exigido.

| Tema | Configuração Debian | Alternativa |
|---|---|---|
| Debian vs Rocky Linux | Debian estável, `apt` e AppArmor; instalação simples para servidor | Rocky Linux, `dnf` e SELinux; familiar em ambientes RHEL |
| AppArmor vs SELinux | AppArmor confina aplicações com perfis baseados em caminhos | SELinux usa rótulos e regras de política para controle obrigatório de acesso |
| UFW vs firewalld | UFW oferece um firewall de host simples; somente TCP 4242 é permitido para conexões de entrada | firewalld oferece zonas e abstrações de serviços; o subject exige seu uso com Rocky |
| VirtualBox vs UTM | VirtualBox é uma opção comum e multiplataforma para a máquina virtual exigida | UTM usa QEMU e é útil em Macs com Apple Silicon, inclusive com emulação quando necessária |

## Recursos

- PDF do subject Born2beRoot fornecido com o ambiente do projeto (não incluído neste repositório)
- [Guia de instalação do Debian](https://www.debian.org/releases/stable/amd64/)
- [Documentação do preseed do Debian](https://www.debian.org/releases/stable/amd64/apbs04.en.html)
- [Informações sobre as versões do Debian](https://www.debian.org/releases/)
- [Configuração do servidor OpenSSH](https://manpages.debian.org/openssh-server/sshd_config.5.en.html)
- [Manual do UFW](https://manpages.debian.org/ufw/ufw.8.en.html)
- [Manual do sudoers](https://manpages.debian.org/sudo/sudoers.5.en.html)

### IA

- A IA criou completamente o [script de testes](./scripts/tests_vm.sh). Eu apenas revisei.
- A IA auxiliou na elaboração e organização dos scripts e da documentação com base
nos requisitos do subject. Revisei a configuração e verifiquei a VM instalada.
