# Script para limpiar archivos obsoletos (PowerShell)
# Este script elimina los scripts antiguos que han sido reemplazados

Write-Host "Limpiando archivos obsoletos..." -ForegroundColor Blue
Write-Host ""

# Eliminar carpeta bash/
if (Test-Path "bash") {
    Write-Host "  Eliminando bash/" -ForegroundColor Yellow
    Remove-Item -Recurse -Force "bash"
    Write-Host "  OK - bash/ eliminada" -ForegroundColor Green
}

# Eliminar carpeta powershell/
if (Test-Path "powershell") {
    Write-Host "  Eliminando powershell/" -ForegroundColor Yellow
    Remove-Item -Recurse -Force "powershell"
    Write-Host "  OK - powershell/ eliminada" -ForegroundColor Green
}

# Eliminar scripts legacy individuales
$filesToRemove = @(
    "build-and-push.sh",
    "build-and-push.ps1",
    "deploy.ps1"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Write-Host "  Eliminando $file" -ForegroundColor Yellow
        Remove-Item $file
        Write-Host "  OK - $file eliminado" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Limpieza completada!" -ForegroundColor Green
Write-Host ""
Write-Host "Archivos restantes:" -ForegroundColor Cyan
Get-ChildItem
