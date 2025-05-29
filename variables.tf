variable "proxmox_url" {
  description = "URL do servidor Proxmox"
  type        = string
}

variable "proxmox_token_id" {
  description = "ID do token da API do Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Segredo do token da API do Proxmox"
  type        = string
  sensitive   = true
}

variable "vm_hostname" {
  description = "Nome do host para a VM"
  type        = string
}

variable "vm_ip" {
  description = "IP do host para a VM"
  type        = string
}

variable "vm_domain" {
  description = "Domínio para a VM"
  type        = string
}

variable "vm_password" {
  description = "Senha do usuário da VM"
  type        = string
  sensitive   = true
}

variable "vm_user" {
  description = "Nome do usuário da VM"
  type        = string
  sensitive   = true
}

variable "srv_proxmox" {
  description = "IP do servidor Proxmox"
  type        = string
  sensitive   = true
}

variable "vm" {
  description = "Nome da VM"
  type        = string
}

variable "node" {
  description = "Nó do cluster"
  type        = string
}

variable "template" {
  description = "Clone do template"
  type        = string
}

variable "vm_vmid" {
  description = "VMID da VM"
  type        = number
}

variable "vm_memory" {
  description = "Memória disponível da VM (in MB)"
  type        = number
}

variable "vm_cores" {
  description = "Quantidade de cores da VM"
  type        = number
}

variable "storage_proxmox" {
  description = "Armazanemnto do Proxmox"
  type        = string
}

variable "vm_macaddr" {
  description = "Endereço MAC da rede da VM"
  type        = string
}

variable "disk_size" {
  description = "Tamanho do disco da VM (in GB)"
  type        = number
}

variable "ssh_key" {
  description = "Chave SSH pública para acessar a VM"
  type        = string
}

variable "private_key" {
  description = "Chave SSH privada"
  type        = string
}

variable "cloud_config_file" {
  description = "Caminho para o arquivo de configuração do cloud init"
  type        = string
}

variable "network_config_file" {
  description = "Caminho para o arquivo de configuração de rede"
  type        = string
}

variable "vm_template_script_path" {
  description = "Caminho para o script do template da VM"
  type        = string
}

variable "config_motd_script_path" {
  description = "Caminho para o script de configuração do MOTD"
  type        = string
}

variable "motd_syspass_path" {
  description = "Caminho para o arquivo de MOTD do sysPass"
  type        = string
}

variable "docker_compose_path" {
  description = "Caminho para o arquivo do docker-compose"
  type        = string
}

variable "file_env_path" {
  description = "Caminho para o arquivo '.env' com as variaveis do banco de dados"
  type        = string
  sensitive   = true
}

/*variable "syspassdb_config_path" {
  description = "Caminho para o arquivo 'config.xml' de conexão do banco de dados"
  type        = string
}

variable "syspassdb_dump_path" {
  description = "Caminho para o dump do banco de dados"
  type        = string
}*/

variable "download_syspassdb_path" {
  description = "Caminho do script de download do backup do banco de dados"
  type        = string
}

variable "restore_syspassdb_path" {
  description = "Caminho do script de restauração do banco de dados"
  type        = string
}

variable "backup_syspassdb_path" {
  description = "Caminho do script de backup do banco de dados"
  type        = string
}

variable "cronjobs_path" {
  description = "Caminho do script para adicionar o script de backup na cron"
  type        = string
}

variable "aws_credentials_path" {
  description = "Caminho para o arquivo de crendencial da AWS"
  type        = string
}

variable "aws_config_path" {
  description = "Caminho para o arquivo de configuração da AWS"
  type        = string
}
