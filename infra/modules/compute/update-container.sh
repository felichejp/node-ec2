#!/bin/bash
set -e

# Argumentos
REPO_URI="$1"
IMAGE_TAG="${2:-server}"
CONTAINER_NAME="service-app"

# Validacion
if [ -z "$REPO_URI" ]; then
  echo "Error: REPO_URI no proporcionado."
  exit 1
fi

# Obtener región del metadata service con retries
echo "Obteniendo región desde metadata service..."
AWS_REGION=""
for i in {1..10}; do
  AWS_REGION=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "")
  if [ -n "$AWS_REGION" ]; then
    break
  fi
  echo "Intento $i/10: Esperando metadata service..."
  sleep 2
done

if [ -z "$AWS_REGION" ]; then
  echo "❌ Error: No se pudo obtener la región del metadata service"
  echo "Intentando usar región por defecto: us-east-1"
  AWS_REGION="us-east-1"
fi

# Detectar runtime disponible (podman o docker)
if command -v podman > /dev/null 2>&1; then
  RUNTIME="podman"
  echo "=== Usando Podman como runtime ==="
elif command -v docker > /dev/null 2>&1; then
  RUNTIME="docker"
  echo "=== Usando Docker como runtime ==="
else
  echo "❌ Error: No se encontró podman ni docker"
  exit 1
fi

echo "=== Iniciando actualización de contenedor ($RUNTIME): $CONTAINER_NAME ==="
echo "Región: $AWS_REGION"
echo "Imagen: $REPO_URI:$IMAGE_TAG"

# 1. Login ECR
echo "1. Autenticando en ECR..."
if [ "$RUNTIME" = "podman" ]; then
  aws ecr get-login-password --region "$AWS_REGION" | podman login --username AWS --password-stdin "$REPO_URI"
else
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REPO_URI"
fi

# 2. Pull Imagen
echo "2. Descargando nueva imagen..."
# Limpieza preventiva
if [ "$RUNTIME" = "podman" ]; then
  podman system prune -af --volumes || true
  podman pull "$REPO_URI:$IMAGE_TAG"
else
  docker system prune -af --volumes || true
  docker pull "$REPO_URI:$IMAGE_TAG"
fi

# 3. Stop & Remove
echo "3. Deteniendo contenedor actual..."
if [ "$RUNTIME" = "podman" ]; then
  if podman ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    podman stop "$CONTAINER_NAME" || true
    podman rm "$CONTAINER_NAME" || true
  else
    echo "El contenedor $CONTAINER_NAME no existe, continuando..."
  fi
else
  if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
  else
    echo "El contenedor $CONTAINER_NAME no existe, continuando..."
  fi
fi

# 4. Run
echo "4. Iniciando nuevo contenedor..."
# Mapeo de puertos: Host 80 -> Container 8080
if [ "$RUNTIME" = "podman" ]; then
  podman run -d \
    -p 80:8080 \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    "$REPO_URI:$IMAGE_TAG"
else
  docker run -d \
    -p 80:8080 \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    "$REPO_URI:$IMAGE_TAG"
fi

# 5. Verify
echo "5. Verificando estado..."
sleep 5
if [ "$RUNTIME" = "podman" ]; then
  if podman ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "✅ Contenedor $CONTAINER_NAME está corriendo."
    podman ps | grep "$CONTAINER_NAME"
  else
    echo "❌ Error: El contenedor no está corriendo."
    podman logs "$CONTAINER_NAME" --tail 20
    exit 1
  fi
else
  if docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "✅ Contenedor $CONTAINER_NAME está corriendo."
    docker ps | grep "$CONTAINER_NAME"
  else
    echo "❌ Error: El contenedor no está corriendo."
    docker logs "$CONTAINER_NAME" --tail 20
    exit 1
  fi
fi

echo "=== Actualización completada exitosamente ==="
