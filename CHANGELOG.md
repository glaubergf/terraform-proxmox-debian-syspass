# Atualizações do Projeto - Versionamento e Melhorias

## ✅ Versão 2.2 - Backup Condicional com Snapshot Inteligente  
📅 Data: 2025-06-21

### 1. Backup somente quando há mudanças reais
- **📌 Verificação via Snapshot Hash**: Implementada verificação inteligente baseada em consulta SQL que resume o estado do banco, garantindo que backups só sejam feitos quando dados sensíveis forem modificados.
- **⚙️ Gatilho de Alterações**: Agora o backup só ocorre quando:
  - O `config.xml` é alterado (**MD5** comparado).
  - O estado real do banco (alterações em senhas, contas, usuários, grupos etc) muda (**Snapshot hash** comparado).
- **⛔️ Remoção da verificação de hash do dump.sql**: O hash do conteúdo do `dump.sql` não é mais utilizado para validar mudanças, evitando falsos positivos causados por variações irrelevantes (ex: ordenação, timestamp).

### 2. Otimizações e Confiabilidade
- **🧹 Dump Gerado Somente Quando Necessário**: Geração do `mysqldump` ocorre apenas se houver alterações reais, reduzindo I/O e economizando processamento.
- **🔒 LOCK durante Dump**: Implementado `FLUSH TABLES WITH READ LOCK` antes do dump e `UNLOCK` após, para garantir consistência sem corromper o arquivo.
- **✅ Upload sincronizado**: Dump e config.xml são enviados juntos ao S3 apenas quando ambos forem relevantes.

### 3. Logs Detalhados e Processamento Claro
- **📋 Logs Específicos por Etapa**: Incluem início/fim do processo, verificação de cada item, comparação de hashes, resultado das verificações e upload final.
- **♻️ Exclusão Segura de Temporários**: Em caso de não haver alterações, arquivos `.temp_*` são automaticamente removidos com mensagens claras no log.
- **🔧 Controle Manual via Variáveis de Ambiente**: Arquivo `.env` centraliza todas as configurações, caminhos e credenciais envolvidas no processo de backup.

---

## ✅ Versão 2.1 - Melhoria no Controle e Validação de Hashes  
📅 Data: 2025-06-20

### 1. Aperfeiçoamento no Controle de Hash
- **📂 Controle Centralizado de Hashes**: Agora todos os backups (dump, config e snapshot) têm seus arquivos `.md5` e `.hash` gerados de forma centralizada, permitindo uma verificação mais fácil e precisa das alterações.
- **🔄 Comparação Consistente**: Arquivos `.md5` e `.hash` são comparados entre si para garantir a integridade dos backups e evitar falsos positivos em alterações.
- **🧹 Limpeza e Preservação de Arquivos Hash**: Somente o arquivo hash mais recente é mantido, otimizando o uso de armazenamento e evitando acúmulo de dados antigos e desnecessários.

---

## ✅ Versão 2.0 - Monitoramento Inteligente de Alterações e Otimizações de Limpeza  
📅 Data: 2025-06-20

### 1. Detecção Inteligente de Alterações
- **🔍 Snapshot de Tabelas-Chave**: Adicionado cálculo de hash de um conjunto relevante de tabelas (`Account`, `User`, `AccountHistory`, etc) para identificar alterações reais nos dados.
- **🛡️ Verificação do Arquivo de Configuração (`config.xml`)**: Agora é gerado e comparado um hash MD5 para identificar mudanças de forma segura, evitando backups desnecessários.
- **🔁 Verificação Dupla com MD5**: Após o dump ser gerado, seu conteúdo é comparado com o dump anterior através de hash MD5, garantindo que só ocorra backup em caso de mudanças reais.

### 2. Processamento e Logs Aprimorados
- **🧹 Limpeza Inteligente**:
  - Arquivos com mais de 30 dias são removidos automaticamente.
  - Os **últimos 5 arquivos mais recentes por tipo** (dumps, config, logs) são **preservados mesmo que tenham mais de 30 dias**.
- **📝 Logs Estruturados**:
  - Toda execução gera log detalhado com marcação de tempo.
  - Log de remoção de arquivos antigos foi refinado para listar os removidos e o mais recente preservado.

### 3. Melhorias Técnicas
- **📂 Controle via Arquivos de Hash**: Cada backup agora gera seus próprios arquivos `.md5` e `.hash`, armazenando os valores de verificação para comparação futura.
- **🔄 Maior Confiabilidade**: Redução de falsos positivos em mudanças e menor uso de banda e armazenamento com uploads mais precisos.
- **🧪 Restauração Validada**: Dumps gerados foram testados com sucesso em ambiente bare-metal com restauração completa da base.

---

## 🏁 Versão 1.0 - Implementação Inicial do Backup Automatizado  
📅 Data: 2025-06-15

### 1. Estrutura Básica do Backup
- **📦 Backup da Base de Dados via `mysqldump`**: Dump completo do banco Syspass gerado com timestamp no nome.
- **☁️ Upload para Amazon S3**: Arquivos de dump são enviados automaticamente para dois buckets distintos (por perfis separados da AWS).
- **📁 Nomeação por Timestamp**: Organização automática dos arquivos com data e hora, permitindo múltiplos backups diários e fácil histórico.

### 2. Execução e Logging
- **🧾 Log de Execução**: Toda execução gera logs armazenados em `/var/log/syspass` com saída padronizada.
- **🧰 Estrutura de Diretórios**: Diretórios `log`, `dump`, `s3` e `config` são validados/criados automaticamente.

---

> Este changelog é parte fundamental da documentação técnica do projeto, permitindo rastreabilidade, controle de versões e acompanhamento da evolução das boas práticas de DevOps aplicadas ao backup automatizado do sysPass.
