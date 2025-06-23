#!/bin/bash

# ================================================================
# Nome:       backup-syspassdb-s3.sh
# Versão:     2.2
# Autor:      Glauber GF (mcnd2)
# Criado:     19/05/2025
# Atualizado: 21/06/2025
#
# Descrição:
#   Este script realiza o backup completo do SysPass, incluindo:
#     - Dump do banco de dados MySQL/MariaDB rodando em container Docker.
#     - Cópia do arquivo de configuração (config.xml).
#   Os arquivos de backup são armazenados localmente e, caso haja alterações,
#   são enviados automaticamente para um bucket S3 na AWS.
#
# Requisitos:
#   - AWS CLI instalado e configurado no host (perfil em ~/.aws/)
#   - Contêineres Docker do SysPass e do MySQL/MariaDB devidamente nomeados
#   - Permissões adequadas de leitura e escrita nos volumes utilizados
#
# Funcionalidades:
#   - Detecta alterações no dump do banco e no config.xml usando hashes 
#     snapshot e MD5.
#     Se não houver alterações desde o último backup, o upload é evitado.
#   - Gera logs detalhados em /var/log/syspass/backup.log.
#   - Realiza rotação automática dos logs, xml e sql, removendo arquivos com 
#     mais de 30 dias e mantém sempre os últimos 5 arquivos idenpendente se
#     mais de 30 dias.
#   - Suporte para agendamento via cron, ideal para backups automáticos diários.
#
# Segurança:
#   - As credenciais do banco são gerenciadas via arquivo temporário,
#     evitando exposição no terminal ou nos logs.
#   - Recomendado proteger este script e os diretórios de backup
#     contra acesso não autorizado.
#
# Licença:
#   GPLv3 – Uso livre, desde que sejam mantidos os créditos e a licença.
# ================================================================

# === Ativar modo seguro: 
# -e (encerra se algum comando falhar), 
# -u (encerra se usar variável não definida), 
# -o pipefail (erros em pipelines são tratados corretamente)
set -euo pipefail
trap 'log_message ERRO "Falha na linha $LINENO. Saindo."' ERR

# === Carregar variáveis do arquivo .env
ENV_PATH="/root/docker_syspass/.env"
set -a
source "$ENV_PATH"
set +a

# === Gerar timestamp (data + hora) para nomear arquivos
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# === Define caminhos dos arquivos de log, dump, config e hash
LOG_FILE="${LOG_DIR}/backup-${TIMESTAMP}.log"
CONFIG_HASH_FILE="${DUMP_DIR}/last-config.md5"
SNAPSHOT_HASH_FILE="${DUMP_DIR}/last-snapshot.hash"
DUMP_PATH="${DUMP_DIR}/syspassdb-dump_${HOSTNAME}_${TIMESTAMP}.sql"
CONFIG_PATH="${DUMP_DIR}/syspassdb-config_${HOSTNAME}_${TIMESTAMP}.xml"

# === Garantir que os diretórios de dump, log e AWS existem
mkdir -p "$DUMP_DIR" "$LOG_DIR" "$AWS_DEST_DIR"

# ==================== FUNÇÕES AUXILIARES ====================

# === Gravar logs com data, hora e nível (INFO, ERRO, SUCESSO)
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo "$(date '+%Y-%m-%d_%H:%M:%S') [${LEVEL}] :: ${MESSAGE}" | tee -a "$LOG_FILE"
}

# === Verificar se o container do banco está rodando
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        log_message ERRO "Container ${DB_CONTAINER} não está rodando! Verifique e tente novamente."
        exit 1
    fi
}

# === Criar arquivo mysql temporário no container para autenticação
generate_mysql_cnf() {
    local FILE
    FILE=$(mktemp)
    chmod 600 "$FILE"
    cat > "$FILE" <<EOF
[client]
user=${DB_USER}
password=${DB_PASS}
EOF
    docker cp "$FILE" "${DB_CONTAINER}:/tmp/my.cnf"
    rm -f "$FILE"
    log_message INFO "Arquivo temporário de autenticação MySQL criado no container."
}

# === Função para criar o snapshot do banco de dados dentro do container
#  O hash só muda quando há:
#    - Alterações no cofre (dados, senha, adição, remoção).
#    - Alterações nos usuários (senha, dados cadastrais, grupos).
#    - Não muda com login, logout, ou acesso comum.
#  Essa consulta cobre:
#    - Alteração no cofre (add, edit, remove contas, arquivos, tags, usuários vinculados, etc.).
#    - Alteração em usuários (nome, senha, grupos, permissões, etc.).
#    - Alteração estrutural (adição/remoção de categorias, plugins, campos customizados, grupos, tags...).

create_snapshot() {
    SNAPSHOT_QUERY="SELECT 
    MD5(CONCAT(
        -- Data da última alteração no Account e AccountHistory
        (SELECT IFNULL(UNIX_TIMESTAMP(MAX(A.dateEdit)), 0) FROM Account A),
        (SELECT IFNULL(GREATEST(
            UNIX_TIMESTAMP(MAX(AH.dateAdd)), 
            UNIX_TIMESTAMP(MAX(AH.dateEdit))
        ), 0) FROM AccountHistory AH),

        -- Data da última alteração em User (ignora login, só alteração real)
        (SELECT IFNULL(UNIX_TIMESTAMP(MAX(U.lastUpdate)), 0) FROM User U),

        -- Contagens das tabelas principais
        (SELECT COUNT(*) FROM Account),
        (SELECT COUNT(*) FROM AccountFile),
        (SELECT COUNT(*) FROM AccountToTag),
        (SELECT COUNT(*) FROM AccountToUser),
        (SELECT COUNT(*) FROM AccountToUserGroup),
        (SELECT COUNT(*) FROM Category),
        (SELECT COUNT(*) FROM CustomFieldData),
        (SELECT COUNT(*) FROM CustomFieldDefinition),
        (SELECT COUNT(*) FROM CustomFieldType),
        (SELECT COUNT(*) FROM Plugin),
        (SELECT COUNT(*) FROM PluginData),
        (SELECT COUNT(*) FROM Tag),
        (SELECT COUNT(*) FROM User),
        (SELECT COUNT(*) FROM UserGroup),
        (SELECT COUNT(*) FROM UserToUserGroup)
    )) AS snapshot_hash;"

    docker exec "$DB_CONTAINER" \
        mysql --defaults-extra-file=/tmp/my.cnf -N -B -e "$SNAPSHOT_QUERY" "$DB_NAME"
}

# === Copiar arquivo apenas se houver alteração (verifica hash)
copy_if_changed() {
    local SRC="$1" DEST="$2" DESC="$3"

    if [[ ! -f "$SRC" ]]; then
        log_message ERRO "Arquivo $DESC não encontrado: $SRC"
        return 1
    fi

    if [[ -f "$DEST" ]] && [[ "$(md5sum "$SRC" | awk '{print $1}')" == "$(md5sum "$DEST" | awk '{print $1}')" ]]; then
        log_message INFO "$DESC sem mudanças. Ignorando cópia."
    else
        [[ -f "$DEST" ]] && cp "$DEST" "${DEST}_$(date +%Y-%m-%d_%H%M%S).bak"
        cp "$SRC" "$DEST"
        log_message INFO "$DESC atualizado com sucesso."
    fi
}

# === Limpar arquivos antigos mantendo os N dias mais recentes, mesmo que antigos
clean_old_files_preserve_latest_n() {
    local DIR="$1"
    local PATTERN="$2"
    local DAYS="$3"
    local KEEP_COUNT="${4:-5}"  # padrão: manter 5 arquivos

    local FILE_LIST
    FILE_LIST=$(find "$DIR" -type f -name "$PATTERN")

    if [[ -z "$FILE_LIST" ]]; then
        log_message INFO "Nenhum arquivo encontrado com o padrão '$PATTERN' no diretório '$DIR'."
        return 0
    fi

    # === Listar ordenado por data de modificação (mais recente primeiro)
    local ALL_FILES
    mapfile -t ALL_FILES < <(ls -1t "$DIR"/$PATTERN 2>/dev/null)

    # === Arquivos a manter (os N mais recentes)
    local FILES_TO_KEEP=("${ALL_FILES[@]:0:$KEEP_COUNT}")

    # === Arquivos candidatos à remoção (mais antigos que X dias e não estão entre os N mais recentes)
    local FILES_TO_DELETE=()
    for file in "${ALL_FILES[@]:$KEEP_COUNT}"; do
        if [[ -f "$file" && $(find "$file" -mtime +"$DAYS" 2>/dev/null) ]]; then
            FILES_TO_DELETE+=("$file")
        fi
    done

    if [[ ${#FILES_TO_DELETE[@]} -eq 0 ]]; then
        log_message INFO "Nenhum arquivo elegível para exclusão em '$DIR' com padrão '$PATTERN'. Mantendo os $KEEP_COUNT mais recentes."
        return 0
    fi

    for file in "${FILES_TO_DELETE[@]}"; do
        rm -f "$file"
        log_message INFO "Arquivo removido: $(basename "$file")"
    done

    log_message INFO "Remoção concluída: ${#FILES_TO_DELETE[@]} arquivos excluídos. Mantidos os $KEEP_COUNT mais recentes."
}

# ==================== INÍCIO DO PROCESSO DE BACKUP ====================

log_message INFO "=========================================================="
log_message INFO "INICIANDO BACKUP DO BANCO DE DADOS DO SYSPASS"
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

# ==================== VERIFICA CONTAINER EM EXECUÇÃO ====================

log_message INFO "Verificando se o container ${DB_CONTAINER} está em execução..."
check_container

# ==================== CREDENCIAIS AWS ====================

copy_if_changed "${AWS_SRC_DIR}/${AWS_CREDENTIALS}" "${AWS_DEST_DIR}/credentials" "credenciais da AWS"
copy_if_changed "${AWS_SRC_DIR}/${AWS_CONFIG}" "${AWS_DEST_DIR}/config" "configurações da AWS"

# === Permissões dos arquivos
[ -f "${AWS_DEST_DIR}/credentials" ] && chmod 600 "${AWS_DEST_DIR}/credentials"
[ -f "${AWS_DEST_DIR}/config" ] && chmod 600 "${AWS_DEST_DIR}/config"
chmod 700 "$AWS_DEST_DIR"

# ==================== AUTENTICAÇÃO TEMPORÁRIA MYSQL/MARIADB ====================

log_message INFO "Gerando arquivo de autenticação MySQL no container..."
generate_mysql_cnf

# ==================== VERIFICAÇÃO DE ALTERAÇÃO DE ARQUIVOS ====================

CONFIG_CHANGED=false
SNAPSHOT_CHANGED=false
TEMP_CONFIG=""

# === Verificação do config.xml
log_message INFO "=================================================="
log_message INFO "Verificando alterações no config.xml..."
log_message INFO "=================================================="

TEMP_CONFIG="${DUMP_DIR}/.temp_config.xml"

if cp "$APP_CONFIG_CONTAINER_PATH" "$TEMP_CONFIG"; then
    log_message INFO "Arquivo config.xml copiado temporariamente."
else
    log_message ERRO "Falha ao copiar $APP_CONFIG_CONTAINER_PATH. Abortando."
    exit 1
fi

HASH_CONFIG_NEW=$(md5sum "$TEMP_CONFIG" | awk '{print $1}')
log_message INFO "Hash atual do config.xml: $HASH_CONFIG_NEW"

if [[ -f "$CONFIG_HASH_FILE" ]]; then
    HASH_CONFIG_OLD=$(awk '{print $1}' "$CONFIG_HASH_FILE")
    log_message INFO "Último hash encontrado para config.xml: $HASH_CONFIG_OLD"
else
    log_message INFO "Nenhum hash anterior encontrado para config.xml (primeira execução)."
    HASH_CONFIG_OLD=""
fi

if [[ "$HASH_CONFIG_NEW" != "$HASH_CONFIG_OLD" ]]; then
    log_message INFO "Alterações detectadas no config.xml."
    CONFIG_CHANGED=true
    echo "$HASH_CONFIG_NEW" > "$CONFIG_HASH_FILE"
else
    log_message INFO "Nenhuma alteração detectada no config.xml. Hash atual igual ao anterior."
    CONFIG_CHANGED=false
fi

# === Verificação do snapshot
log_message INFO "=================================================="
log_message INFO "Verificando alterações no snapshot do banco..."
log_message INFO "=================================================="

SNAPSHOT_HASH_NEW=$(create_snapshot)
log_message INFO "Snapshot atual: $SNAPSHOT_HASH_NEW"

if [[ -f "$SNAPSHOT_HASH_FILE" ]]; then
    SNAPSHOT_HASH_OLD=$(awk '{print $1}' "$SNAPSHOT_HASH_FILE")
    log_message INFO "Último snapshot hash encontrado: $SNAPSHOT_HASH_OLD"
else
    log_message INFO "Nenhum snapshot anterior encontrado (primeira execução)."
    SNAPSHOT_HASH_OLD=""
fi

if [[ "$SNAPSHOT_HASH_NEW" != "$SNAPSHOT_HASH_OLD" ]]; then
    log_message INFO "Alterações detectadas no snapshot."
    SNAPSHOT_CHANGED=true
    echo "$SNAPSHOT_HASH_NEW" > "$SNAPSHOT_HASH_FILE"
else
    log_message INFO "Nenhuma alteração detectada no snapshot. Hash atual igual ao anterior."
    SNAPSHOT_CHANGED=false
fi

# ==================== GERAÇÃO DO DUMP SQL ====================

log_message INFO "=================================================="
log_message INFO "Gerando dump.sql com mudanças detectadas..."
log_message INFO "=================================================="

# === Gerar dump.sql temporário para verificação
if [[ "$CONFIG_CHANGED" == true || "$SNAPSHOT_CHANGED" == true ]]; then
    log_message INFO "Alteração relevante detectada. Gerando dump.sql e config.xml..."

    DUMP_TEMP="${DUMP_DIR}/.temp_dump.sql"

    # === Bloqueia tabelas para consistência
    docker exec "$DB_CONTAINER" mysql --defaults-extra-file=/tmp/my.cnf -e "FLUSH TABLES WITH READ LOCK;"

    if docker exec "$DB_CONTAINER" mysqldump \
        --defaults-extra-file=/tmp/my.cnf \
        --skip-comments \
        --skip-dump-date \
        "$DB_NAME" > "$DUMP_TEMP"; then

        docker exec "$DB_CONTAINER" mysql --defaults-extra-file=/tmp/my.cnf -e "UNLOCK TABLES;"
        log_message INFO "DUMP SQL gerado com sucesso."

    else
        docker exec "$DB_CONTAINER" mysql --defaults-extra-file=/tmp/my.cnf -e "UNLOCK TABLES;"
        log_message ERRO "Erro ao gerar DUMP SQL."
        exit 1
    fi

    # === Mover os arquivos temporários com timestamp final
    mv "$DUMP_TEMP" "$DUMP_PATH"
    mv "$TEMP_CONFIG" "$CONFIG_PATH"

    # === Upload do DUMP SQL para o bucket S3
    aws s3 cp "$DUMP_PATH" "$AWS_BUCKET1/" --only-show-errors
    aws s3 cp "$DUMP_PATH" "$AWS_BUCKET2/" --profile "$AWS_PROFILE2" --only-show-errors
    log_message INFO "Backup do DUMP SQL realizado e enviado para o bucket S3."

    # === Upload do config.xml para o Bucket S3
    aws s3 cp "$CONFIG_PATH" "$AWS_BUCKET1/" --only-show-errors
    aws s3 cp "$CONFIG_PATH" "$AWS_BUCKET2/" --profile "$AWS_PROFILE2" --only-show-errors
    log_message INFO "Backup do CONFIG XML realizado e enviado para o bucket S3."

else
    log_message INFO "Nenhuma alteração real detectada. Nenhum backup realizado."
    [[ -f "$TEMP_CONFIG" ]] && rm -f "$TEMP_CONFIG"
fi

# ==================== LIMPEZA DE ARQUIVOS ANTIGOS ====================

log_message INFO "Iniciando limpeza de arquivos antigos..."

# === Remover arquivos antigos mais de 30 dias mantendo o 5 mais recentes
clean_old_files_preserve_latest_n "$DUMP_DIR" "${DUMP_PREFIX}_*.sql" 30 5
clean_old_files_preserve_latest_n "$DUMP_DIR" "${CONFIG_PREFIX}_*.xml" 30 5

clean_old_files_preserve_latest_n "$LOG_DIR" "backup-*.log" 30 5
clean_old_files_preserve_latest_n "$LOG_DIR" "cronjob-*.log" 30 5
clean_old_files_preserve_latest_n "$LOG_DIR" "download-*.log" 30 5
clean_old_files_preserve_latest_n "$LOG_DIR" "restore-*.log" 30 5

# === Remover o arquivo mysql temporário no container
docker exec "$DB_CONTAINER" rm -f /tmp/my.cnf || true

log_message SUCESSO "=========================================================="
log_message SUCESSO "PROCESSO CONCLUÍDO COM SUCESSO!"
log_message SUCESSO "=========================================================="
