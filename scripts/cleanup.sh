#!/bin/bash
# Script para limpiar archivos obsoletos después de la migración
# Este script elimina los scripts antiguos que han sido reemplazados

set -e

echo "🧹 Limpiando archivos obsoletos..."
echo ""

# Eliminar carpeta bash/
if [ -d "bash" ]; then
    echo "  Eliminando bash/"
    rm -rf bash/
    echo "  ✓ bash/ eliminada"
fi

# Eliminar carpeta powershell/
if [ -d "powershell" ]; then
    echo "  Eliminando powershell/"
    rm -rf powershell/
    echo "  ✓ powershell/ eliminada"
fi

# Eliminar scripts legacy individuales
FILES_TO_REMOVE=(
    "build-and-push.sh"
    "build-and-push.ps1"
    "deploy.ps1"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        echo "  Eliminando $file"
        rm "$file"
        echo "  ✓ $file eliminado"
    fi
done

echo ""
echo "✅ Limpieza completada!"
echo ""
echo "Archivos restantes (deberían ser solo):"
ls -la
