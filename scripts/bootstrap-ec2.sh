#!/bin/bash

set -e

echo "===================================="
echo " Actualizando sistema..."
echo "===================================="

sudo dnf update -y

echo "===================================="
echo " Instalando Docker..."
echo "===================================="

sudo dnf install docker -y

sudo systemctl enable docker
sudo systemctl start docker

echo "===================================="
echo " Agregando ec2-user al grupo docker..."
echo "===================================="

sudo usermod -aG docker ec2-user

echo "===================================="
echo " Instalando Docker Compose..."
echo "===================================="

sudo mkdir -p /usr/local/lib/docker/cli-plugins

sudo curl -SL \
https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
-o /usr/local/lib/docker/cli-plugins/docker-compose

sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "===================================="
echo " Instalando Git..."
echo "===================================="

sudo dnf install git -y

echo "===================================="
echo " Creando carpeta de despliegue..."
echo "===================================="

mkdir -p /home/ec2-user/app

echo "===================================="
echo " Versiones instaladas"
echo "===================================="

docker --version
docker compose version
git --version

echo "===================================="
echo " Bootstrap completado"
echo "===================================="

echo ""
echo "IMPORTANTE:"
echo "Cierra la sesión SSH y vuelve a entrar"
echo "para que el grupo docker tenga efecto."