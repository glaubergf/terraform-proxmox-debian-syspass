<!---
# ================================================================
Projeto: terraform-proxmox-debian-syspass
---
Descrição:  Este projeto automatiza a criação de uma máquina virtual
    Debian 12 (Bookworm) no Proxmox utilizando Terraform e Cloud-Init, 
    realizando a instalação do sysPass via Docker, além de configurar um 
    processo completo de backup e restauração no Amazon S3.
---
Autor:      Glauber GF (mcnd2)
Criado:     26-05-2025
Atualizado: 23/06/2025
# ================================================================
--->

# Servidor Debian sysPass (Docker)

![Image](https://github.com/glaubergf/terraform-proxmox-debian-syspass/blob/main/images/tf-pm-syspass.png)

![Image](https://github.com/glaubergf/terraform-proxmox-debian-syspass/blob/main/images/syspass.png)

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

## 📜 Sobre o Projeto

Este projeto provisiona um servidor **Debian 12 (Bookworm)** no **Proxmox VE** utilizando **Terraform** e **cloud-init**, com implantação automatizada do gerenciador de senhas **sysPass** em container **Docker**.

## 🪄 O Projeto Realiza

- Download automático da imagem atualizada do Debian noCloud.
- Criação de VM no Proxmox via QEMU.
- Configuração do sistema operacional via Cloud-Init.
- Instalação e configuração do Docker.
- Deploy do container do sysPass e MariaDB.
- Restauração automática do banco de dados sysPass (dump.sql + config.xml) a partir do bucket S3.
- Backup diário do banco para o bucket S3, executado via cron.
- Validação de alteração no banco antes de realizar novos backups.

## 🧩 Tecnologias Utilizadas

![Terraform](https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white&style=for-the-badge)
- [Terraform](https://developer.hashicorp.com/terraform) — Provisionamento de infraestrutura como código (IaC).
 ---
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?logo=proxmox&logoColor=white&style=for-the-badge)
- [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) — Hypervisor para virtualização.
---
![Cloud-Init](https://img.shields.io/badge/Cloud--Init-00ADEF?logo=cloud&logoColor=white&style=for-the-badge)
- [Cloud-Init](https://cloudinit.readthedocs.io/en/latest/) — Ferramenta de inicialização e configuração automatizada da VM.
---
![Debian](https://img.shields.io/badge/Debian-A81D33?logo=debian&logoColor=white&style=for-the-badge)
- [Debian 12 (Bookworm)](https://www.debian.org/) — Sistema operacional da VM.
---
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white&style=for-the-badge)
- [Docker](https://www.docker.com/) — Containerização da aplicação sysPass.
---
![sysPass](https://img.shields.io/badge/sysPass-394855?style=for-the-badge&logo=lock&logoColor=white)
- [sysPass](https://syspass-doc.readthedocs.io/en/3.1/) — Gerenciador de senhas seguro e colaborativo.
---
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
- [MariaDB](https://mariadb.org) — Banco de dados relacional
---
![AWS S3](https://img.shields.io/badge/AWS%20S3-FF9900?logo=amazonaws&logoColor=white&style=for-the-badge)
- [AWS S3](https://aws.amazon.com/pt/s3/) — Armazenamento de objetos.

## 💡 Motivação

Automatizar a criação de um ambiente seguro e escalável para gerenciamento de senhas, garantindo:

- Implantação consistente;
- Backup automatizado e versionado;
- Facilidade na restauração e manutenção.

## 🛠️ Pré-requisitos

- ✅ Proxmox VE com API habilitada.
- ✅ Usuário no Proxmox com permissão para criação de VMs.
- ✅ Bucket na AWS S3 configurado.
- ✅ Chave de acesso à AWS configurada.
- ✅ Chave SSH pública e privada para acesso à VM.
- ✅ Terraform instalado localmente.

## 📂 Estrutura do Projeto

```
terraform-proxmox-debian-syspass
├── configs
│   ├── backup-syspassdb-s3.sh
│   ├── cloud-config.yml
│   ├── config-motd.sh
│   ├── cronjobs.sh
│   ├── docker-compose.yml
│   ├── download-syspassdb-s3.sh
│   ├── motd-syspass
│   ├── network-config.yml
│   ├── restore-syspassdb.sh
│   └── vm-template.sh
├── images
│   └── tf-pm-syspass.png
├── CHANGELOG.md
├── LICENSE
├── notes
│   ├── art-ascii-to-modt.txt
│   ├── docker-compose.yml.template
│   ├── dotenv.template
│   ├── restore-file-config.xml.txt
│   └── terraform.tfvars.template
├── output.tf
├── provider.tf
├── README.md
├── security
│   ├── .env
│   ├── aws-config
│   ├── aws-credentials
│   ├── proxmox_id_rsa
│   └── proxmox_id_rsa.pub
├── terraform.tfvars
├── variables.tf
└── vm-proxmox.tf
```

### 📄 Arquivos

- `provider.tf` → Provedor do Proxmox
- `vm_proxmox.tf` → Criação da VM, configuração da rede, execução dos scripts
- `variables.tf` → Definição de variáveis
- `terraform.tfvars` → Valores das variáveis (customização)
- `cloud_config.yml` → Configurações do Cloud-Init (usuário, pacotes, timezone, scripts)
- `network_config.yml` → Configuração de rede estática
- `docker-compose.yml` → Define e organiza os contêineres Docker
- `.env` → Variáveis de acesso ao banco de dados, bucket S3, credenciais AWS, diretórios e arquivos

## 🚀 Fluxo de Funcionamento

1. **Terraform Init:** Inicializa o Terraform e carrega os providers e módulos necessários.

2. **Download da imagem Debian noCloud:** Baixa a imagem Debian pré-configurada (noCloud) se ainda não estiver no Proxmox.

3. **Criação da VM no Proxmox:** Terraform cria uma VM no Proxmox com base nas variáveis definidas.

4. **Aplicação do Cloud-Init:** Injeta configuração automática na VM (rede, usuário, SSH, hostname, etc.).

5. **Configuração inicial da VM:** A VM é inicializada e aplica configurações básicas (acesso remoto, hostname, rede, etc.).

6. **Preparação da VM:** Envio de arquivos de confiurações para a VM, instalação do Docker e Docker Compose na VM, etc.

7. **Deploy dos containers:** O Docker Compose sobe o container do sysPass e do mariaDB.

8. **Execução dos scripts:** Após o sysPass estiver inicializado corretamente, executa o download de backup do S3, restaura o banco e faz novo backup do banco restaurado do sysPass para o bucket S3.

## 🛠️ Terraform

Ferramenta de IaC (Infrastructure as Code) que permite definir e gerenciar infraestrutura através de arquivos de configuração declarativos.

Saiba mais: [https://developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform)

## 🖥️ Proxmox VE

O Proxmox VE é um hipervisor bare-metal, robusto e completo, muito utilizado tanto em ambientes profissionais quanto em homelabs. É uma plataforma de virtualização open-source que permite gerenciar máquinas virtuais e containers de forma eficiente, com suporte a alta disponibilidade, backups, snapshots e uma interface web intuitiva.

Saiba mais: [https://www.proxmox.com/](https://www.proxmox.com/)

## 🐧 Debian

Distribuição Linux livre, estável e robusta. A imagem utilizada é baseada em **Debian noCloud**, que permite integração com Cloud-Init no Proxmox.

Saiba mais: [https://www.debian.org/](https://www.debian.org/)

### ☁️ Sobre a imagem Debian nocloud

Este projeto utiliza a imagem Debian nocloud por maior estabilidade no provisionamento via Terraform no Proxmox, evitando problemas recorrentes como **kernel panic** em outras versões (*generic*, *genericcloud*).

## ☁️ Cloud-Init

Ferramenta de provisionamento padrão de instâncias de nuvem. Permite configurar usuários, pacotes, rede, timezone, scripts e mais, tudo automaticamente na criação da VM.

Saiba mais: [https://cloudinit.readthedocs.io/](https://cloudinit.readthedocs.io/)

## 🐳 Docker

Plataforma que permite empacotar, distribuir e executar aplicações em containers de forma leve, portátil e isolada, facilitando a implantação e escalabilidade de serviços.

Saiba mais: [https://www.docker.com](https://www.docker.com)

## 🔒 sysPass

O sysPass é uma aplicação web segura e colaborativa para gerenciamento de senhas, com funcionalidades como:

- Compartilhamento controlado;
- ACLs e perfis;
- Backup, exportação e auditoria;
- Integração com LDAP;
- Suporte a campos personalizados.

Mais informações: [https://syspass-doc.readthedocs.io/](https://syspass-doc.readthedocs.io/)

## ▶️ Execução do Projeto

1. Clone o repositório:

```bash
git clone https://github.com/glaubergf/terraform-proxmox-debian-syspass.git
cd terraform-proxmox-debian-syspass
```

2. Edite o arquivo `terraform.tfvars` com suas variáveis.

3. Inicialize o Terraform:

```bash
terraform init
```

4. Execute o plano para mostra o que será criado:

```bash
terraform plan
```

5. Aplique o provisionamento (infraestrutura):

```bash
terraform apply
```

6. Para destruir toda a infraestrutura criada (caso necessário):

```bash
terraform destroy
```

7. Para executar sem confirmação interativa, use:

```bash
terraform apply --auto-approve
terraform destroy --auto-approve
```

## 🤝 Contribuições

Contribuições são bem-vindas!

## 📜 Licença

Este projeto está licenciado sob os termos da **[GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.html)**.

### 🏛️ Aviso Legal

```
Copyright (c) 2025

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo
sob os termos da Licença Pública Geral GNU conforme publicada pela
Free Software Foundation, na versão 3 da Licença.

Este programa é distribuído na esperança de que seja útil,
mas SEM NENHUMA GARANTIA, nem mesmo a garantia implícita de
COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM DETERMINADO FIM.

Veja a Licença Pública Geral GNU para mais detalhes.
```
