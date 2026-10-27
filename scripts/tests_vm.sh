#!/bin/bash

# Corzinha legais
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0;37m'

# Garante que os binários administrativos (/sbin e /usr/sbin) estejam no PATH do script
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

printf "${BLUE}==================================================${NC}\n"
printf "${BLUE}    BORN2BEROOT - DEBIAN 13 COMPLIANCE AUDIT      ${NC}\n"
printf "${BLUE}==================================================${NC}\n\n"

# 1. Sistema Operacional e Interface Gráfica
printf "${YELLOW}[1/10] Verificando Sistema e Interface Gráfica...${NC}\n"
OS=$(head -n 1 /etc/os-release | awk -F= '{print $2}' | tr -d '"')
printf "   OS Detectado: $OS\n"

if echo "$OS" | grep -qiE "debian|rocky"; then
    printf "   ${GREEN}✓ OS em conformidade (Debian/Rocky)${NC}\n"
else
    printf "   ${RED}✗ OS inválido pelo subject${NC}\n"
fi

if systemctl is-active --quiet gdm3 || systemctl is-active --quiet lightdm || systemctl is-active --quiet sddm || [ -f /usr/bin/Xorg ] || [ -f /usr/bin/wayland ]; then
    printf "   ${RED}✗ Interface Gráfica detectada! (Nota 0)${NC}\n"
else
    printf "   ${GREEN}✓ Modo de texto puro ativo (Sem X.org/Wayland)${NC}\n"
fi

# 2. Módulos de Segurança (AppArmor)
printf "\n${YELLOW}[2/10] Verificando Módulos de Segurança...${NC}\n"
# No Debian 13, checamos via sysfs ou systemctl para evitar falsos negativos do aa-status
if [ -d /sys/module/apparmor ] || systemctl is-active --quiet apparmor; then
    printf "   ${GREEN}✓ AppArmor está carregado e ativo no sistema${NC}\n"
else
    printf "   ${RED}✗ AppArmor desativado ou não carregado no kernel${NC}\n"
fi

# 3. Criptografia e Particionamento LVM
printf "\n${YELLOW}[3/10] Verificando Partições LVM Criptografadas...${NC}\n"
CRYPT_CHECK=$(lsblk -o TYPE | grep -c "crypt")
LVM_CHECK=$(lsblk -o TYPE | grep -c "lvm")

if [ "$CRYPT_CHECK" -ge 1 ]; then
    printf "   ${GREEN}✓ Criptografia (crypt) detectada ($CRYPT_CHECK partições)${NC}\n"
else
    printf "   ${RED}✗ Nenhuma partição criptografada encontrada (LUKS)${NC}\n"
fi

if [ "$LVM_CHECK" -ge 2 ]; then
    printf "   ${GREEN}✓ Volumes LVM detectados ($LVM_CHECK volumes)${NC}\n"
else
    printf "   ${RED}✗ Estrutura LVM menor que o exigido pelo subject${NC}\n"
fi

# 4. Configurações do Serviço SSH
printf "\n${YELLOW}[4/10] Verificando Serviço SSH...${NC}\n"
# Lê diretamente a configuração ativa do sshd_config para contornar formatações do comando ss
SSH_PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}')
if [ "$SSH_PORT" = "4242" ]; then
    printf "   ${GREEN}✓ SSH configurado estritamente na porta 4242${NC}\n"
else
    printf "   ${RED}✗ Porta SSH incorreta no sshd_config: '$SSH_PORT'${NC}\n"
fi

ROOT_SSH=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
if [ "$ROOT_SSH" = "no" ]; then
    printf "   ${GREEN}✓ Login SSH como Root está desativado (PermitRootLogin no)${NC}\n"
else
    printf "   ${RED}✗ Alerta de Segurança: Root ainda consegue logar via SSH ('$ROOT_SSH')${NC}\n"
fi

# 5. Configurações do Firewall (UFW)
printf "\n${YELLOW}[5/10] Verificando Firewall...${NC}\n"
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        printf "   ${GREEN}✓ UFW instalado e Ativo${NC}\n"
        UFW_PORTS=$(ufw status | grep -E "ALLOW" | awk '{print $1}' | tr '\n' ' ')
        printf "   Portas liberadas: $UFW_PORTS\n"
    else
        printf "   ${RED}✗ UFW está instalado, mas !! INATIVO !!. Rode: sudo ufw enable ou sudo systemctl start ufw${NC}\n"
    fi
else
    printf "   ${RED}✗ UFW não está instalado ou não foi encontrado no PATH${NC}\n"
fi

# 6. Hostname da Máquina
printf "\n${YELLOW}[6/10] Verificando Hostname...${NC}\n"
HOSTNAME=$(hostname)
if echo "$HOSTNAME" | grep -q "42$"; then
    printf "   ${GREEN}✓ Hostname válido: '$HOSTNAME' (Termina com 42)${NC}\n"
else
    printf "   ${RED}✗ Hostname inválido: '$HOSTNAME' (Deve terminar com 42)${NC}\n"
fi

# 7. Usuário e Grupos do Aluno
printf "\n${YELLOW}[7/10] Verificando Usuário e Grupos...${NC}\n"
TARGET_USER="eroque-d"

if id "$TARGET_USER" &>/dev/null; then
    # Captura os nomes dos grupos em vez dos IDs numéricos primários
    USER_GROUPS=$(id -Gn "$TARGET_USER")
    if echo "$USER_GROUPS" | grep -q "\bsudo\b" && echo "$USER_GROUPS" | grep -q "\buser42\b"; then
        printf "   ${GREEN}✓ Usuário '$TARGET_USER' pertence aos grupos 'user42' e 'sudo'${NC}\n"
    else
        printf "   ${RED}✗ Grupos incorretos. '$TARGET_USER' deveria ter 'sudo' e 'user42'. Grupos atuais: $USER_GROUPS${NC}\n"
    fi
else
    printf "   ${RED}✗ Usuário '$TARGET_USER' não existe no sistema${NC}\n"
fi

# 8. Política de Expiração de Senhas (/etc/login.defs)
printf "\n${YELLOW}[8/10] Verificando Prazos e Validade de Senhas...${NC}\n"
MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
MIN_DAYS=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
WARN_AGE=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}')

if [ "$MAX_DAYS" = "30" ] && [ "$MIN_DAYS" = "2" ] && [ "$WARN_AGE" = "7" ]; then
    printf "   ${GREEN}✓ login.defs configurado: Max 30 dias, Min 2 dias, Aviso 7 dias${NC}\n"
else
    printf "   ${RED}✗ Configurações de prazos de senha inválidas no login.defs:${NC}\n"
    printf "     PASS_MAX_DAYS: $MAX_DAYS (Esperado: 30)\n"
    printf "     PASS_MIN_DAYS: $MIN_DAYS (Esperado: 2)\n"
    printf "     PASS_WARN_AGE: $WARN_AGE (Esperado: 7)\n"
fi

# 9. Regras do Sudo (/etc/sudoers)
printf "\n${YELLOW}[9/10] Verificando Diretivas de Segurança do Sudo...${NC}\n"
if [ -f "/etc/sudoers" ]; then
    SUDO_TTY=$(grep -ri "requiretty" /etc/sudoers* 2>/dev/null)
    SUDO_LOG=$(grep -ri "logfile" /etc/sudoers* 2>/dev/null)
    SUDO_TRIES=$(grep -ri "passwd_tries" /etc/sudoers* 2>/dev/null)

    if [ -n "$SUDO_TTY" ]; then
        printf "   ${GREEN}✓ TTY Mode habilitado (requiretty)${NC}\n"
    else
        printf "   ${RED}✗ Modo TTY desativado no Sudoers${NC}\n"
    fi

    if [ -n "$SUDO_LOG" ]; then
        printf "   ${GREEN}✓ Histórico de inputs/outputs direcionado para logs (/var/log/sudo)${NC}\n"
    else
        printf "   ${RED}✗ Logs de input/output do sudo não configurados${NC}\n"
    fi

    if [ -n "$SUDO_TRIES" ]; then
        printf "   ${GREEN}✓ Limite de tentativas de senha ativo (passwd_tries)${NC}\n"
    else
        printf "   ${RED}✗ Limite de tentativas de senha não configurado${NC}\n"
    fi
else
    printf "   ${RED}✗ Não foi possível ler o arquivo /etc/sudoers${NC}\n"
fi

# 10. Agendamento do Script de Monitoramento (Cron)
printf "\n${YELLOW}[10/10] Verificando Cron e Script de Monitoramento...${NC}\n"
if [ -f "/home/$TARGET_USER/monitoring.sh" ] || [ -f "/usr/local/bin/monitoring.sh" ] || [ -f "/root/monitoring.sh" ]; then
    printf "   ${GREEN}✓ Arquivo 'monitoring.sh' encontrado no sistema${NC}\n"
else
    printf "   ${RED}✗ Script 'monitoring.sh' não foi localizado nos caminhos padrão${NC}\n"
fi

CRON_JOB=$(crontab -l 2>/dev/null | grep "monitoring.sh")
if [ -n "$CRON_JOB" ]; then
    printf "   ${GREEN}✓ Script de monitoramento agendado no Crontab do Root:${NC}\n     $CRON_JOB\n"
else
    printf "   ${RED}✗ Script não está agendado no crontab do root (sudo crontab -l está vazio)${NC}\n"
fi

printf "\n${BLUE}==================================================${NC}\n"
printf "${BLUE}               FIM DA AUDITORIA                   ${NC}\n"
printf "${BLUE}==================================================${NC}\n"

