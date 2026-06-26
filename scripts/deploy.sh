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
# Generar .env dinámico
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
# Guardar versión anterior (ROLLBACK BASE)
########################################

echo "Guardando imagen anterior..."
docker tag ${DOCKER_USER}/${DOCKER_IMAGE}:latest ${DOCKER_USER}/${DOCKER_IMAGE}:previous || true

########################################
# Deploy nuevo
########################################

echo "Levantando servicios..."

docker compose pull
docker compose up -d --remove-orphans

########################################
# HEALTH CHECK
########################################

echo "Ejecutando health check..."

sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

echo "HTTP CODE: $HTTP_CODE"

########################################
# ROLLBACK LOGIC
########################################

if [ "$HTTP_CODE" -ne 200 ]; then

    echo "❌ HEALTH CHECK FALLÓ - INICIANDO ROLLBACK"

    docker compose down

    echo "Revirtiendo a versión anterior..."

    sed -i "s/:${IMAGE_TAG}/:previous/g" .env

    docker compose up -d --remove-orphans

    sleep 5

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "✅ ROLLBACK EXITOSO"
    else
        echo "💥 ROLLBACK FALLÓ - SISTEMA INESTABLE"
        exit 1
    fi

else
    echo "✅ DEPLOY EXITOSO"
fi

echo "======================================"
echo " DEPLOY FINISHED"
echo "======================================"