# flask-ci-cd

Template de infraestructura CI/CD para APIs Flask sobre AWS EC2, con despliegue automatizado vía GitHub Actions. Incluye Flask + Gunicorn, Nginx como proxy inverso, PostgreSQL y Docker Compose.

---

## Arquitectura

```
Internet
   │
   ▼
[Nginx :80]          ← proxy inverso
   │
   ▼
[Flask/Gunicorn :8000]   ← contenedor de la API
   │
   ▼
[PostgreSQL :5432]   ← base de datos
```

Todos los servicios corren en contenedores Docker sobre una misma red interna (`app-network`). Nginx es el único punto expuesto al exterior (puerto 80). La API y la base de datos no son accesibles directamente desde Internet.

---

## Flujo CI/CD

```
Push a main
     │
     ▼
GitHub Actions
  ├── [CI] Build & push imagen Docker → Docker Hub
  └── [CD] SSH a EC2 → docker compose pull + up -d
```

El pipeline tiene dos etapas:

1. **CI**: construye la imagen Docker de la API, la etiqueta y la sube a Docker Hub.
2. **CD**: se conecta a la instancia EC2 vía SSH, hace `docker compose pull` para traer la imagen nueva y luego `docker compose up -d` para redeployar sin downtime apreciable.

---

## Requisitos previos

- Cuenta AWS con una instancia EC2 corriendo (recomendado Ubuntu 22.04+)
- Par de claves SSH para acceder a la instancia
- Cuenta en Docker Hub
- Repositorio forkeado/clonado en tu GitHub

---

## Setup inicial de la instancia EC2 (una sola vez)

Antes del primer deploy, la instancia debe tener Docker y Docker Compose instalados. Ejecuta el script de bootstrap conectándote por SSH:

```bash
ssh -i tu-clave.pem ubuntu@<IP_DE_TU_EC2>
```

Una vez dentro:

```bash
bash <(curl -s https://raw.githubusercontent.com/<TU_USUARIO>/flask-ci-cd/main/scripts/bootstrap-ec2.sh)
```

Este script instala Docker, Docker Compose y configura los permisos necesarios. Solo necesitas ejecutarlo una vez por instancia.

---

## Variables y secretos de GitHub

Navega a tu repositorio → **Settings → Secrets and variables → Actions**.

### Secrets (Settings → Secrets → Actions → New repository secret)

Son valores sensibles que GitHub cifra y nunca expone en logs.

| Secret | Descripción | Ejemplo |
|--------|-------------|---------|
| `SSH_PRIVATE_KEY` | Clave privada SSH para conectarse a la EC2 (contenido del archivo `.pem`) | `-----BEGIN RSA PRIVATE KEY-----...` |
| `EC2_HOST` | IP pública o DNS de tu instancia EC2 | `54.123.45.67` |
| `EC2_USER` | Usuario SSH de la instancia | `ubuntu` |
| `DOCKERHUB_USERNAME` | Tu usuario de Docker Hub | `miusuario` |
| `DOCKERHUB_TOKEN` | Access token de Docker Hub (no uses tu contraseña) | `dckr_pat_xxxx` |
| `POSTGRES_PASSWORD` | Contraseña de la base de datos | `supersecret123` |

### Variables (Settings → Variables → Actions → New repository variable)

Son valores no sensibles que se pueden ver en los logs.

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DOCKER_IMAGE` | Nombre de la imagen en Docker Hub | `flask-api` |
| `POSTGRES_DB` | Nombre de la base de datos | `mydb` |
| `POSTGRES_USER` | Usuario de PostgreSQL | `myuser` |

### Cómo se usan en el proyecto

El archivo `docker-compose.yml` referencia estas variables así:

```yaml
image: ${DOCKERHUB_USERNAME}/${DOCKER_IMAGE}:${IMAGE_TAG}
```

El pipeline de GitHub Actions genera un archivo `.env` en la EC2 durante el deploy con todos los valores necesarios para que Docker Compose los recoja automáticamente.

---

## Estructura del repositorio

```
flask-ci-cd/
├── .github/
│   └── workflows/
│       ├── ci.yml          # Build y push de imagen Docker
│       └── cd.yml          # Deploy en EC2 vía SSH
├── app/
│   ├── Dockerfile          # Imagen de la API Flask
│   ├── requirements.txt    # Dependencias Python
│   └── ...                 # Código de tu API
├── nginx/
│   └── nginx.conf          # Configuración del proxy inverso
├── scripts/
│   ├── bootstrap-ec2.sh    # Instalación de Docker en EC2 (una vez)
│   └── deploy.sh           # Script ejecutado remotamente en cada deploy
├── docker-compose.yml      # Orquestación de los tres servicios
├── .dockerignore
└── .gitignore
```

---

## Personalizar para tu propia API

Este repositorio es un template. Para adaptarlo a tu proyecto:

1. Reemplaza el contenido de `app/` con el código de tu API Flask.
2. Actualiza `app/requirements.txt` con tus dependencias.
3. Si tu API necesita variables de entorno adicionales, agrégalas como secrets/variables en GitHub y añádelas al paso de generación del `.env` en el workflow de CD.
4. Ajusta `nginx/nginx.conf` si necesitas rutas especiales, SSL o configuración de cabeceras.

---

## Comandos útiles en la EC2

```bash
# Ver el estado de los contenedores
docker compose ps

# Ver logs de la API
docker compose logs api -f

# Ver logs de Nginx
docker compose logs nginx -f

# Reiniciar solo la API
docker compose restart api

# Bajar todo
docker compose down

# Subir todo manualmente
docker compose up -d
```

---

## Notas de seguridad

- Nunca subas el archivo `.env` al repositorio. Está en `.gitignore` por defecto.
- Usa **Access Tokens** de Docker Hub en lugar de tu contraseña.
- Asegúrate de que el Security Group de tu EC2 solo tenga el puerto 22 (SSH) y el 80 (HTTP) abiertos. El puerto de PostgreSQL (5432) y el de Gunicorn (8000) **no** deben estar expuestos públicamente.
