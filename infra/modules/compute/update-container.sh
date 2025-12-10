#!/bin/bash
set -e

# Argumentos
REPO_URI="$1"
IMAGE_TAG="${2:-server}"
CONTAINER_NAME="service-app"
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Validacion
if [ -z "$REPO_URI" ]; then
  echo "Error: REPO_URI no proporcionado."
  exit 1
fi

echo "=== Iniciando actualización de contenedor (Podman): $CONTAINER_NAME ==="
echo "Región: $AWS_REGION"
echo "Imagen: $REPO_URI:$IMAGE_TAG"

# 1. Login ECR
echo "1. Autenticando en ECR..."
aws ecr get-login-password --region "$AWS_REGION" | podman login --username AWS --password-stdin "$REPO_URI"

# 2. Pull Imagen
echo "2. Descargando nueva imagen..."
# Limpieza preventiva
podman system prune -af --volumes || true
podman pull "$REPO_URI:$IMAGE_TAG"

# 3. Stop & Remove
echo "3. Deteniendo contenedor actual..."
if podman ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
  podman stop "$CONTAINER_NAME" || true
  podman rm "$CONTAINER_NAME" || true
else
  echo "El contenedor $CONTAINER_NAME no existe, continuando..."
fi

# 4. Run
echo "4. Iniciando nuevo contenedor..."
# Mapeo de puertos: Host 80 -> Container 8080
podman run -d \
  -p 80:8080 \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  "$REPO_URI:$IMAGE_TAG"

# 5. Verify
echo "5. Verificando estado..."
sleep 5
if podman ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
  echo "✅ Contenedor $CONTAINER_NAME está corriendo."
  podman ps | grep "$CONTAINER_NAME"
else
  echo "❌ Error: El contenedor no está corriendo."
  podman logs "$CONTAINER_NAME" --tail 20
  exit 1
fi

echo "=== Actualización completada exitosamente ==="
