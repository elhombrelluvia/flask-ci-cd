#!/bin/bash

set -e

echo "====================================="
echo " Bootstrap EC2"
echo "====================================="

########################################
# Actualizar sistema
########################################

sudo dnf update -y

########################################
# Docker
########################################

if ! command -v docker >/dev/null 2>&1; then

    echo "Instalando Docker..."

    sudo dnf install docker -y

    sudo systemctl enable docker

    sudo systemctl start docker

    sudo usermod -aG docker ec2-user

else

    echo "Docker ya instalado."

fi

########################################
# Git
########################################

if ! command -v git >/dev/null 2>&1; then

    echo "Instalando Git..."

    sudo dnf install git -y

else

    echo "Git ya instalado."

fi

########################################
# Docker Compose
########################################

if ! docker compose version >/dev/null 2>&1; then

    echo "Instalando Docker Compose..."

    sudo mkdir -p /usr/local/lib/docker/cli-plugins

    sudo curl -SL \
    https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose

    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

else

    echo "Docker Compose ya instalado."

fi

########################################
# Directorio aplicación
########################################

mkdir -p /home/ec2-user/app

echo ""
echo "====================================="
echo "Bootstrap finalizado"
echo "====================================="

docker --version
docker compose version
git --version