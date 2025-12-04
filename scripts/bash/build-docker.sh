#!/bin/bash
# Script para construir la imagen Docker localmente
# Uso: ./build-docker.sh

set -e

SERVICE_NAME="apolo-procesamiento-inteligente"
IMAGE_TAG="local-$(date +%Y%m%d-%H%M%S)"

echo "Construyendo imagen Docker: ${SERVICE_NAME}:${IMAGE_TAG}"
echo ""

docker build \
    --platform linux/amd64 \
    -t ${SERVICE_NAME}:${IMAGE_TAG} \
    -t ${SERVICE_NAME}:local-latest \
    .

echo ""
echo "✓ Imagen construida exitosamente"
echo ""
echo "Para ejecutar localmente:"
echo "docker run -p 8080:8080 --rm \\"
echo "  -e BUCKET_NAME=preavaluos-pdf \\"
echo "  -e GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json \\"
echo "  -v /path/to/credentials.json:/path/to/credentials.json:ro \\"
echo "  ${SERVICE_NAME}:local-latest"
echo ""
