#!/bin/bash

# ================================================================
# Nome:       cronjobs.sh
# Versão:     1.1
# Autor:      Glauber GF (mcnd2)
# Criado:     19/05/2025
# Modificado: 28/05/2025
#
# Requisitos:
#   - Distribuição Linux baseada em Debian/Ubuntu (para apt)
#   - Permissão de root para instalar pacotes e editar crontab
#   - Script de backup localizado no caminho especificado em $SCRIPT_PATH
#   - AWS CLI configurado previamente com as credenciais de acesso (via aws configure 
# ou variáveis de ambiente)
#
# Observações:
#   - O script é idempotente: executá-lo múltiplas vezes não cria duplicatas no crontab.
#   - O serviço 'cron' será iniciado automaticamente caso esteja desativado.
#
# Segurança:
#   - Certifique-se de que o script de backup e este script não estejam acessíveis por 
# usuários não autorizados.
# ================================================================

# === Tratar erros de forma mais robusta e detectável
set -euo pipefail

# === Capturar e imprimir uma mensagem de erro personalizada
trap 'log_message ERRO "Falha na linha $LINENO. Saindo."' ERR

# ==================== FUNÇÃO DE LOG ====================

log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${LEVEL}] :: ${MESSAGE}" | tee -a "$LOG_FILE"
}

# === Variáveis
LOG_DIR="/var/log/syspass"
LOG_FILE="${LOG_DIR}/cronjob-$(date '+%Y-%m-%d_%H%M%S').log"
USER_NAME="root"
SCRIPT_PATH="/root/docker_syspass/script_backup/backup-syspassdb-s3.sh"
CRON_ENTRY="0 2 * * * /bin/bash $SCRIPT_PATH"
CRON_COMMENT="# Essa cron executa todos os dias às 2h da manhã o script 'backup-syspassdb-s3.sh'."
AWS_SECURITY_DIR="/root/docker_syspass/script_backup"
AWS_PROFILE_PATH="/root/.aws"

# ==================== VERIFICAÇÃO DA CRON ====================

# === Verificar se o cron está instalado
log_message INFO "Verificando se a cron está instalado..."

if ! command -v cron >/dev/null 2>&1 && ! command -v crond >/dev/null 2>&1; then
    log_message INFO "A cron não está instalado. Instalando..."
    apt update && apt install -y cron
else
    log_message INFO "A cron já está instalado."
fi

# === Verificar se o serviço cron está ativo
if ! systemctl is-active --quiet cron; then
    log_message INFO "O serviço da cron está inativo. Iniciando..."
    systemctl enable cron
    systemctl start cron
else
    log_message INFO "O serviço da cron já está em execução."
fi

# === Adicionar entrada no crontab do usuário, se ainda não existir
if ! crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
    log_message INFO "Adicionando entrada na crontab do usuário '${USER_NAME}'..."

    TMP_CRON=$(mktemp)

    # === Exportar o crontab atual (se houver) para o arquivo temporário
    crontab -l 2>/dev/null > "$TMP_CRON" || true

    # === Adicionar comentário e a nova entrada
    echo "$CRON_COMMENT" >> "$TMP_CRON"
    echo "$CRON_ENTRY" >> "$TMP_CRON"

    # === Instalar o novo crontab
    crontab "$TMP_CRON"

    # === Remover o arquivo temporário
    rm "$TMP_CRON"

    log_message SUCESSO "=========================================================="
    log_message SUCESSO "ENTRADA ADICIONADA AO CONTRAB COM SUCESSO!"
    log_message SUCESSO "=========================================================="
else
    log_message INFO "A entrada no crontab já existe. Nenhuma ação necessária."
fi
