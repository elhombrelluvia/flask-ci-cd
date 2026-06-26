#!/bin/bash
set -e

echo "======================================"
echo " DEPLOY START"
echo "======================================"

REPO=$1
IMAGE_TAG=$2
DOCKER_USER=$3
DOCKER_IMAGE=$4
APP_DIR="/home/ec2-user/app"

# [Opcional] Si decides eliminar la clonación de Git en el EC2, 
# esta sección de Git clone/fetch la puedes remover por completo.
if [ ! -d "$APP_DIR/.git" ]; then
    echo "Repositorio no existe. Clonando..."
    git clone https://github.com/$REPO.git $APP_DIR
fi
cd $APP_DIR
echo "Actualizando código..."
git fetch origin main
git reset --hard origin/main

# Generar .env dinámico
echo "Generating .env..."
cat > .env <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
DOCKERHUB_USERNAME=$DOCKER_USER
DOCKER_IMAGE=$DOCKER_IMAGE
IMAGE_TAG=$IMAGE_TAG
EOF

# Guardar versión anterior para Rollback
echo "Guardando backup de imagen actual..."
docker tag ${DOCKER_USER}/${DOCKER_IMAGE}:latest ${DOCKER_USER}/${DOCKER_IMAGE}:previous || true

echo "Levantando nuevos servicios..."
docker compose pull
docker compose up -d --remove-orphans

# HEALTH CHECK CON REINTENTOS (Mucho más robusto que un sleep fijo)
echo "Ejecutando health check..."
MAX_RETRIES=5
RETRY_COUNT=0
HTTP_CODE=0
# Ajusta el puerto aquí si tu app no mapea al puerto 80 externo
TARGET_URL="http://localhost:8000" 

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$HTTP_CODE" -ne 200 ]; do
    sleep 3
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL" || echo "000")
    echo "Intento $((RETRY_COUNT+1))/$MAX_RETRIES - HTTP CODE: $HTTP_CODE"
    RETRY_COUNT=$((RETRY_COUNT+1))
done

########################################
# ROLLBACK LOGIC
########################################
if [ "$HTTP_CODE" -ne 200 ]; then
    echo "❌ HEALTH CHECK FALLÓ - INICIANDO ROLLBACK"
    
    # Detener lo que se rompió
    docker compose down
    
    echo "Revirtiendo .env a la versión estable anterior..."
    # SOLUCIONADO: Reemplazo exacto basado en la clave del archivo .env
    sed -i "s/IMAGE_TAG=${IMAGE_TAG}/IMAGE_TAG=previous/g" .env
    
    echo "Levantando contenedores con la versión anterior..."
    docker compose up -d --remove-orphans
    
    sleep 5
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL" || echo "000")
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "✅ ROLLBACK EXITOSO - SISTEMA ESTABLE EN VERSIÓN ANTERIOR"
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