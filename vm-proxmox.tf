# Origem do arquivo de configuração do Cloud Init.
data "template_file" "cloud_init" {
  template = file(var.cloud_config_file)

  vars = {
    ssh_key  = file(var.ssh_key)
    hostname = var.vm_hostname
    domain   = var.vm_domain
    password = var.vm_password
    user     = var.vm_user
  }
}

data "template_file" "network_config" {
  template = file(var.network_config_file)
}

# Criar uma cópia local dos arquivos para transferir para o servidor Proxmox.
resource "local_file" "cloud_init" {
  content  = data.template_file.cloud_init.rendered
  filename = "${path.module}/configs/syspass-cloud-init.cfg"
}

resource "local_file" "network_config" {
  content  = data.template_file.network_config.rendered
  filename = "${path.module}/configs/syspass-network-config.cfg"
}

# Transferir os arquivos para o servidor Proxmox.
resource "null_resource" "cloud_init" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key)
    host        = var.srv_proxmox
  }

  provisioner "file" {
    source      = local_file.cloud_init.filename
    destination = "/var/lib/vz/snippets/syspass-cloud-init.yml"
  }

  provisioner "file" {
    source      = local_file.network_config.filename
    destination = "/var/lib/vz/snippets/syspass-network-config.yml"
  }
}

# Copiar o script de template para o servidor Proxmox e executá-lo.
resource "null_resource" "proxmox_template_script" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key)
    host        = var.srv_proxmox
  }

  # Copiar o script para o Proxmox.
  provisioner "file" {
    source      = var.vm_template_script_path
    destination = "/tmp/vm-template.sh"
  }

  # Executar o script no Proxmox.
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/vm-template.sh",
      "bash /tmp/vm-template.sh"
    ]
  }
}

# Criar a VM, depende da execução do script no Proxmox.
resource "proxmox_vm_qemu" "debian_nocloud" {
  depends_on = [
    null_resource.proxmox_template_script,
    null_resource.cloud_init
  ]

  name        = var.vm
  target_node = var.node

  # Clonar o modelo 'bookworm-cloudinit'.
  clone   = var.template
  os_type = "cloud-init"

  # Opções do Cloud Init
  cicustom = "user=${var.storage_proxmox}:snippets/syspass-cloud-init.yml,network=${var.storage_proxmox}:snippets/syspass-network-config.yml"

  # Configurações de hardware.
  vmid    = var.vm_vmid
  cores   = var.vm_cores
  memory  = var.vm_memory
  sockets = 1
  agent   = 1
  kvm     = true
  numa    = false
  onboot  = true

  # Definir os parâmetros do disco de inicialização bootdisk = "scsi0".
  scsihw = "virtio-scsi-pci" # virtio-scsi-single

  # Configurar disco principal
  disk {
    slot     = "scsi0"
    type     = "disk"
    format   = "raw"
    iothread = true
    storage  = var.storage_proxmox
    size     = var.disk_size
  }

  # Configurar drive do CloudInit.
  disk {
    type = "cloudinit"
    slot = "scsi1" #"ide2"
    #format  = "qcow2" # o Proxmox ignora o parâmetro 'format' quando usa type 'cloudinit'.
    storage = var.storage_proxmox
  }

  # Ordem de boot.
  boot = "order=scsi0;scsi1" #ide2

  # Adicionar configuração de BIOS (UEFI 'ovmf' / BIOS tradicional 'seabios').
  bios = "seabios"

  # Aumentar o tempo de espera para o agente QEMU, se necessário.
  agent_timeout = 60

  # Desabilitar a verificação de IPv6.
  skip_ipv6 = true

  # Configurar rede da VM.
  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = var.vm_macaddr
  }

  # Ignorar alterações nos atributos dos recursos.
  lifecycle {
    ignore_changes = [
      cicustom,
      sshkeys,
      network
    ]
  }
}

## Provisionar as configurações dentro da VM após criada.
# Envio de arquivos para a VM
resource "null_resource" "upload_files" {
  depends_on = [proxmox_vm_qemu.debian_nocloud]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = var.config_motd_script_path
    destination = "/tmp/config-motd.sh"
  }

  provisioner "file" {
    source      = var.motd_syspass_path
    destination = "/tmp/motd-syspass"
  }

  provisioner "file" {
    source      = var.docker_compose_path
    destination = "/tmp/docker-compose.yml"
  }

  provisioner "file" {
    source      = var.file_env_path
    destination = "/tmp/.env"
  }

  provisioner "file" {
    source      = var.aws_credentials_path
    destination = "/tmp/aws-credentials"
  }

  provisioner "file" {
    source      = var.aws_config_path
    destination = "/tmp/aws-config"
  }

  provisioner "file" {
    source      = var.download_syspassdb_path
    destination = "/tmp/download-syspassdb-s3.sh"
  }

  provisioner "file" {
    source      = var.restore_syspassdb_path
    destination = "/tmp/restore-syspassdb.sh"
  }

  provisioner "file" {
    source      = var.backup_syspassdb_path
    destination = "/tmp/backup-syspassdb-s3.sh"
  }

  provisioner "file" {
    source      = var.cronjobs_path
    destination = "/tmp/cronjobs.sh"
  }
}

# Instalação do Docker na VM
resource "null_resource" "install_docker" {
  depends_on = [null_resource.upload_files]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "if ! command -v docker >/dev/null 2>&1; then",
      "  sudo apt update",
      "  sudo apt install -y ca-certificates curl gnupg lsb-release",
      "  sudo install -m 0755 -d /etc/apt/keyrings",
      "  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "  echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "  sudo apt update",
      "  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "  sudo systemctl enable docker",
      "  sudo systemctl start docker",
      "else",
      "  echo 'Docker já está instalado.'",
      "fi"
    ]
  }
}

# Organização dos arquivos na VM e execução do script MOTD
resource "null_resource" "prepare_environment" {
  depends_on = [null_resource.install_docker]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /root/docker_syspass/script_backup",
      "sudo mkdir -p /root/.aws",
      "sudo mkdir -p /var/log/syspass",
      "sudo mv /tmp/docker-compose.yml /root/docker_syspass/docker-compose.yml",
      "sudo mv /tmp/.env /root/docker_syspass/.env",
      "sudo mv /tmp/aws-credentials /root/docker_syspass/script_backup/aws-credentials",
      "sudo mv /tmp/aws-config /root/docker_syspass/script_backup/aws-config",
      "sudo mv /tmp/download-syspassdb-s3.sh /root/docker_syspass/script_backup/download-syspassdb-s3.sh",
      "sudo mv /tmp/restore-syspassdb.sh /root/docker_syspass/script_backup/restore-syspassdb.sh",
      "sudo mv /tmp/backup-syspassdb-s3.sh /root/docker_syspass/script_backup/backup-syspassdb-s3.sh",
      "sudo mv /tmp/cronjobs.sh /root/docker_syspass/script_backup/cronjobs.sh",
      "sudo chown -R root:root /root/docker_syspass/",

      # Executar script MOTD
      "sudo chmod +x /tmp/config-motd.sh",
      "sudo bash /tmp/config-motd.sh"
    ]
  }
}

# Subir containers Docker
resource "null_resource" "docker_up" {
  depends_on = [null_resource.prepare_environment]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker compose -f /root/docker_syspass/docker-compose.yml up -d",
      "echo 'Containers iniciados. Aguardando banco de dados subir...'; sleep 20"
    ]
  }
}

# Executar download do s3, restore do db, backup para o s3 e configurar cronjob
resource "null_resource" "execute_scripts" {
  depends_on = [null_resource.docker_up]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /root/docker_syspass/script_backup/*.sh",
      "sudo bash /root/docker_syspass/script_backup/download-syspassdb-s3.sh || echo 'Download falhou ou não é necessário.'",
      "sudo bash /root/docker_syspass/script_backup/restore-syspassdb.sh || echo 'Restore falhou ou não é necessário.'",
      "sudo bash /root/docker_syspass/script_backup/backup-syspassdb-s3.sh || echo 'Backup inicial falhou ou não é necessário.'",
      "sudo bash /root/docker_syspass/script_backup/cronjobs.sh || echo 'Falha ao configurar cronjob.'"
    ]
  }
}
