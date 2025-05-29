#!/bin/bash

# ================================================================
# Nome:       restore-syspassdb.sh
# Versão:     1.1
# Autor:      Glauber GF (mcnd2)
# Criado:     14/05/2025
# Modificado: 25/05/2025
#
# Descrição:
#   Este script realiza a restauração completa do sysPass, incluindo:
#     - Banco de dados (MariaDB/MySQL) armazenado no container do banco.
#     - Arquivo de configuração config.xml no volume persistente do container da aplicação.
#
# Funcionalidades:
#   - Carrega variáveis de ambiente a partir do arquivo .env.
#   - Realiza log detalhado de todas as etapas no diretório especificado.
#   - Restaura o dump SQL para o container do banco.
#   - Copia o arquivo config.xml para o volume do container da aplicação.
#   - Reinicia os containers envolvidos para aplicar as alterações.
#
# Segurança e Robustez:
#   - Utiliza set -euo pipefail para garantir interrupção em erros.
#   - Implementa tratamento de erros com trap para capturar a linha e a causa da falha.
#
# Requisitos:
#   - Docker e docker-compose instalados.
#   - Containers sysPass configurados: banco (DB) e aplicação (APP).
#   - Arquivo .env com as variáveis corretamente configuradas.
# ================================================================

# === Tratar erros de forma robusta
set -euo pipefail

# === Capturar e imprimir uma mensagem de erro personalizada
trap 'log_message ERRO "Falha na linha $LINENO. Saindo."' ERR

# === Carregar variáveis do .env
ENV_PATH="/root/docker_syspass/.env"
set -a
source "$ENV_PATH"
set +a

# === Função de log
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${LEVEL}] :: ${MESSAGE}" | tee -a "$LOG_FILE"
}

# === Gera timestamp (data + hora) para logs
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# === Variáveis locais derivadas do .env
LOG_FILE="${LOG_DIR}/restore-${TIMESTAMP}.log"

# ==================== INÍCIO DO PROCESSO DE RESTAURAÇÃO ====================

log_message INFO "=========================================================="
log_message INFO "INICIANDO RESTAURAÇÃO DO BANCO DE DADOS DO SYSPASS"
log_message INFO "=========================================================="

# === Verificar se o arquivo dump existe
if [[ ! -f "$DOWNLOAD_DIR/$DUMP_DOWNLOAD_FILE" ]]; then
    log_message ERRO "Arquivo de dump NÃO encontrado: $DOWNLOAD_DIR/$DUMP_DOWNLOAD_FILE"
    exit 1
fi

# === Restaurar o dump do banco de dados
log_message INFO "Restaurando o backup do banco de dados do sysPass..."
docker exec -i "$DB_CONTAINER" mariadb -u "$DB_ROOT" -p"$DB_ROOT_PASS" "$DB_NAME" < "$DOWNLOAD_DIR/$DUMP_DOWNLOAD_FILE"

# === Verificar se o arquivo config.xml existe
if [[ ! -f "$DOWNLOAD_DIR/$CONFIG_DOWNLOAD_FILE" ]]; then
    log_message ERRO "Arquivo de configuração NÃO encontrado: $DOWNLOAD_DIR/$CONFIG_DOWNLOAD_FILE"
    exit 1
fi

# === Restaurar o config.xml
log_message INFO "Copiando o config.xml para o volume do container do sysPass..."
cp "$DOWNLOAD_DIR/$CONFIG_DOWNLOAD_FILE" "$APP_CONFIG_CONTAINER_PATH"

# === Reiniciar os containers
log_message INFO "Reiniciando os containers $DB_CONTAINER e $APP_CONTAINER..."
docker compose restart

log_message SUCESSO "=========================================================="
log_message SUCESSO "RESTAURAÇÃO DO BANCO DE DADOS DO SYSPASS CONCLUÍDA!"
log_message SUCESSO "=========================================================="
