#!/bin/bash

# ================================================================
# Nome:       download-syspassdb-s3.sh
# Versão:     1.1
# Autor:      Glauber GF (mcnd2)
# Criado:     22/05/2025
# Modificado: 25/05/2025
#
# Descrição:
#   Este script realiza o download dos arquivos de backup mais 
#   recentes (DUMP .sql e config .xml) armazenados em um bucket S3.
#
# Funcionamento:
#   - Verifica e identifica os arquivos .sql e .xml mais recentes 
#     no bucket S3 especificado.
#   - Realiza o download dos arquivos encontrados para o diretório 
#     de destino local.
#   - Gera logs detalhados de todo o processo.
#
# Requisitos:
#   - AWS CLI configurado com credenciais válidas.
#   - Permissão de acesso ao bucket S3.
# ================================================================

# === Tratar erros de forma mais robusta e detectável
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

# === Variáveis derivadas
LOG_FILE="${LOG_DIR}/download-$(date '+%Y-%m-%d_%H%M%S').log"

# Garante que os diretórios de dump, log e AWS existem
mkdir -p "$DOWNLOAD_DIR" "$LOG_DIR" "$AWS_DEST_DIR"

# ==================== INÍCIO DO PROCESSO DE DOWNLOAD ====================

log_message INFO "=========================================================="
log_message INFO "INICIANDO DOWNLOAD DO BACKUP DO SYSPASS"
log_message INFO "=========================================================="

# ==================== VERIFICA SE O AWSCLI ESTA INSTALADO ====================

log_message INFO "Verificando se o AWSCLI está instalado..."

if ! command -v aws >/dev/null 2>&1; then
    log_message INFO "O AWSCLI não está instalado. Instalando..."
    apt update && apt install -y awscli
    log_message SUCESSO "O AWSCLI foi instalado."
else
    log_message INFO "O AWSCLI já está instalado."
fi

# ==================== FUNÇÃO ARQUIVOS SE DIFERENTE ====================

copy_if_changed() {
    local SRC="$1"
    local DEST="$2"
    local DESC="$3"

    if [[ ! -f "$SRC" ]]; then
        log_message ERRO "Arquivo $DESC não encontrado: $SRC"
        return 1
    fi

    if [[ -f "$DEST" ]]; then
        local HASH_SRC HASH_DEST
        HASH_SRC=$(md5sum "$SRC" | awk '{print $1}')
        HASH_DEST=$(md5sum "$DEST" | awk '{print $1}')

        if [[ "$HASH_SRC" == "$HASH_DEST" ]]; then
            log_message INFO "Arquivo de $DESC sem mudanças. Ignorando cópia."
            return
        else
            local TS
            TS=$(date +%Y-%m-%d_%H%M%S)
            local BACKUP="${DEST}_${TS}.bak"
            cp "$DEST" "$BACKUP"
            log_message INFO "Mudança detectada no arquivo de $DESC. Backup criado: $BACKUP"
        fi
    fi

    cp "$SRC" "$DEST"
    log_message INFO "Arquivo de $DESC atualizado com sucesso."
}

# ==================== CREDENCIAIS AWS ====================

copy_if_changed "${AWS_SRC_DIR}/${AWS_CREDENTIALS}" "${AWS_DEST_DIR}/credentials" "credenciais da AWS"
copy_if_changed "${AWS_SRC_DIR}/${AWS_CONFIG}" "${AWS_DEST_DIR}/config" "configurações da AWS"

# === Permissões dos arquivos
[ -f "${AWS_DEST_DIR}/credentials" ] && chmod 600 "${AWS_DEST_DIR}/credentials"
[ -f "${AWS_DEST_DIR}/config" ] && chmod 600 "${AWS_DEST_DIR}/config"
chmod 700 "$AWS_DEST_DIR"

# ==================== DOWNLOAD DO BACKUP DO BUCKET S3 ====================

log_message INFO "Buscando no Bucket S3 os arquivos mais recentes do dump do banco e do config.xml..."

# === Dump SQL mais recente
dump_latest_file=$(aws s3 ls "${AWS_BUCKET1}/" --recursive | grep '.sql' | sort -k1,1 -k2,2 | tail -n1 | awk '{print $4}')

if [[ -z "$dump_latest_file" ]]; then
    log_message ERRO "Nenhum arquivo .sql encontrado no bucket ${AWS_BUCKET1}."
else
    log_message INFO "O backup do dump mais recente é $dump_latest_file."
    aws s3 cp "${AWS_BUCKET1}/${dump_latest_file}" "${DOWNLOAD_DIR}/${DUMP_DOWNLOAD_FILE}" --only-show-errors
fi

# === Config XML mais recente
xml_latest_file=$(aws s3 ls "${AWS_BUCKET1}/" --recursive | grep '.xml' | sort -k1,1 -k2,2 | tail -n1 | awk '{print $4}')

if [[ -z "$xml_latest_file" ]]; then
    log_message ERRO "Nenhum arquivo .xml encontrado no bucket ${AWS_BUCKET1}."
else
    log_message INFO "O backup do config mais recente é $xml_latest_file."
    aws s3 cp "${AWS_BUCKET1}/${xml_latest_file}" "${DOWNLOAD_DIR}/${CONFIG_DOWNLOAD_FILE}" --only-show-errors
fi

# === Verificação final
if [[ -n "$dump_latest_file" && -n "$xml_latest_file" ]]; then
    log_message SUCESSO "=========================================================="
    log_message SUCESSO "DOWNLOAD CONCLUÍDO COM SUCESSO PARA ${DOWNLOAD_DIR}."
    log_message SUCESSO "=========================================================="
else
    log_message ERRO "O download dos arquivos falhou. Verifique o log para detalhes."
fi
