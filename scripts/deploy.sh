#!/bin/bash

set -e

echo "======================================"
echo " DEPLOY START"
echo "======================================"

########################################
# Args
########################################

REPO=$1
IMAGE_TAG=$2
DOCKER_USER=$3
DOCKER_IMAGE=$4

APP_DIR="/home/ec2-user/app"

echo "Repo: $REPO"
echo "Image tag: $IMAGE_TAG"

########################################
# Clonar repo si no existe
########################################

if [ ! -d "$APP_DIR/.git" ]; then
    echo "Repositorio no existe. Clonando..."
    git clone https://github.com/$REPO.git $APP_DIR
fi

cd $APP_DIR

########################################
# Actualizar repo
########################################

echo "Actualizando código..."

git fetch origin main
git reset --hard origin/main

########################################
# Generar .env dinámico (CORRECTO)
########################################

echo "Generando .env..."

cat > .env <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

DOCKERHUB_USERNAME=$DOCKER_USER
DOCKER_IMAGE=$DOCKER_IMAGE
IMAGE_TAG=$IMAGE_TAG
EOF

########################################
# Deploy Docker
########################################

echo "Levantando servicios..."

docker compose pull
echo "DEBUG .env:"
cat .env || true

if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "ERROR: POSTGRES_PASSWORD vacío"
  exit 1
fi
docker compose up -d --remove-orphans

########################################
# Health check
########################################

echo "Verificando API..."

sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "DEPLOY EXITOSO 🚀"
else
    echo "DEPLOY FALLÓ ❌"
    exit 1
fi

echo "======================================"
echo " DEPLOY FINISHED"
echo "======================================"