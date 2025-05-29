#!/bin/bash

# ================================================================
# Nome:       config-motd.sh
# Versão:     1.0
# Autor:      Glauber GF (mcnd2)
# Criado:     17/04/2025
# Modificado: 21/05/2025
#
# Descrição:
#   Este script realiza a mudança do motd que são mensagem personalizadas
#   que é apresentada ao lofazer login no servidor.
# ================================================================

# === Modificar o motd.
sudo mv /etc/motd /etc/motd.ORIG
sudo cp /tmp/motd-syspass /etc/motd-syspass

# === Inserir linhas no final do arquivo '/etc/profile' para config do '/etc/motd'.
# === As cores básicas para "(tput setaf 'x')" são as numeradas abaixo:
# === 1-vermelho; 2-verde; 3-amarelo; 4-azul; 5-magenta; 6-ciano; 7-branco

echo '' >> /etc/profile
echo '## start motd - config to motd' >> /etc/profile
echo 'export TERM=xterm-256color' >> /etc/profile
echo '(tput setaf 6)' >> /etc/profile
echo 'cat /etc/motd-syspass' >> /etc/profile
echo '(tput setaf 6)' >> /etc/profile
echo 'echo ''' >> /etc/profile
echo 'echo '🅾🅿🅴🆁🅰🆃🅸🅽🅶 🆂🆈🆂🆃🅴🅼 :'' '`grep -oP "^PRETTY_NAME=\"\K[^\"]+" /etc/os-release`' >> /etc/profile
echo 'echo '🅷🅾🆂🆃🅽🅰🅼🅴 :'' '`hostname -s`' >> /etc/profile
echo 'echo '🅳🅾🅼🅰🅸🅽 :'' '`hostname -d`' >> /etc/profile
echo 'echo '🅳🅰🆃🅴 :'' '`date`' >> /etc/profile
echo 'echo '🆄🅿🆃🅸🅼🅴 :'' '`uptime -p`' >> /etc/profile
echo 'echo '🅿🆁🅸🆅🅰🆃🅴 🅸🅿 :'' '`hostname -I`' >> /etc/profile
echo 'echo '🅿🆄🅱🅻🅸🅲 🅸🅿 :'' '`dig +short myip.opendns.com @resolver1.opendns.com`' >> /etc/profile
echo 'echo '🅷🅾🅼🅴 :'' 'https://www.syspass.org/' >> /etc/profile
echo 'echo '🅳🅾🅲🆂 :'' 'https://doc.syspass.org/en/3.1/index.html' >> /etc/profile
echo 'echo ''' >> /etc/profile
echo '(tput setaf 7)' >> /etc/profile
echo '## end motd' >> /etc/profile
