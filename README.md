---
Projeto: terraform-proxmox-debian-syspass
Descrição: Este projeto automatiza a criação de uma máquina virtual Debian 12 (Bookworm) no Proxmox utilizando Terraform e Cloud-Init, realizando a instalação do sysPass via Docker, além de configurar um processo completo de backup e restauração no Amazon S3.
Autor: Glauber GF (mcnd2)
Criado em: 26-05-2025
---

![Image](https://github.com/glaubergf/terraform-proxmox-debian-syspass/blob/main/images/tf-pm-syspass.png)

![Image](https://github.com/glaubergf/terraform-proxmox-debian-syspass/blob/main/images/syspass.png)

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

# Servidor Debian sysPass (Docker)

Este projeto provisiona um servidor **Debian 12 (Bookworm)** no **Proxmox VE** utilizando **Terraform** e **cloud-init**, com implantação automatizada do gerenciador de senhas **sysPass** em container **Docker**.

## 🪄 O Projeto Realiza

- Download automático da imagem Debian noCloud.
- Criação de VM no Proxmox via QEMU.
- Configuração automática via Cloud-Init.
- Instalação do Docker e implantação do sysPass como container.
- Restauração automática do banco de dados sysPass (dump + config.xml) a partir do S3.
- Backup diário do banco no S3, executado via cron.
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
![AWS S3](https://img.shields.io/badge/AWS%20S3-FF9900?logo=amazonaws&logoColor=white&style=for-the-badge)
- [AWS S3](https://aws.amazon.com/pt/s3/) — Armazenamento de objetos.

## 💡 Motivação

Automatizar a criação de um ambiente seguro e escalável para gerenciamento de senhas, garantindo:

- Implantação consistente;
- Backup automatizado e versionado;
- Facilidade na restauração e manutenção.

## 🛠️ Pré-requisitos

- Proxmox VE com API habilitada.
- Usuário no Proxmox com permissão para criação de VMs.
- Terraform instalado (versão recomendada >= 1.5).
- Bucket na AWS S3 configurado.
- Chave de acesso à AWS configurada.
- Chave SSH pública e privada para acesso à VM.

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
│   ├── tproxmox_id_rsa
│   └── proxmox_id_rsa.pub
├── terraform.tfvars
├── variables.tf
└── vm-proxmox.tf
```
## 🚀 Fluxo de Funcionamento

1. **Templates gerados:** cloud-init e configuração de rede.
2. **Transferência:** arquivos enviados via Terraform para o Proxmox.
3. **Criação da VM:** provisionada com imagem Debian nocloud.
4. **Execução de scripts:** instala Docker, configura sistema e sysPass.
5. **Backup:** restauração do último backup do S3.
6. **Automação:** script no cron para backup diário, com upload ao S3.

## ▶️ Execução do Projeto

1. Clone este repositório:

```bash
git clone https://github.com/glaubergf/terraform-proxmox-debian-syspass.git
cd terraform-proxmox-debian-syspass
```

2. Edite o arquivo `terraform.tfvars` com suas configurações.

3. Inicialize o Terraform:

```bash
terraform init
```

4. Mostra o que será criado:

```bash
terraform plan
```

5. Aplica o provisionamento:

```bash
terraform apply
```

6. Destrói toda a infraestrutura criada (caso necessário):

```bash
terraform destroy
```

7. Para executar sem confirmação interativa, use:

```bash
terraform apply --auto-approve
terraform destroy --auto-approve
```

## ☁️ Sobre a imagem Debian nocloud

Este projeto utiliza a imagem Debian nocloud por maior estabilidade no provisionamento via Terraform no Proxmox, evitando problemas recorrentes como **kernel panic** em outras versões (*generic*, *genericcloud*).

## 🔒 Sobre o sysPass

O sysPass é uma aplicação web segura e colaborativa para gerenciamento de senhas, com funcionalidades como:

- Compartilhamento controlado;
- ACLs e perfis;
- Backup, exportação e auditoria;
- Integração com LDAP;
- Suporte a campos personalizados.

Mais informações: [https://syspass-doc.readthedocs.io/](https://syspass-doc.readthedocs.io/)

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
