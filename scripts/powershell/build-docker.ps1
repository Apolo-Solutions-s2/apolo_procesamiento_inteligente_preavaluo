# Script para construir la imagen Docker localmente (PowerShell)
# Uso: .\build-docker.ps1

$ServiceName = "apolo-procesamiento-inteligente"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ImageTag = "local-$Timestamp"

Write-Host "Construyendo imagen Docker: ${ServiceName}:${ImageTag}" -ForegroundColor Cyan
Write-Host ""

docker build `
    --platform linux/amd64 `
    -t "${ServiceName}:${ImageTag}" `
    -t "${ServiceName}:local-latest" `
    .

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Imagen construida exitosamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "Para ejecutar localmente:" -ForegroundColor Yellow
    Write-Host "docker run -p 8080:8080 --rm ``" -ForegroundColor White
    Write-Host "  -e BUCKET_NAME=preavaluos-pdf ``" -ForegroundColor White
    Write-Host "  -e GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json ``" -ForegroundColor White
    Write-Host "  -v /path/to/credentials.json:/path/to/credentials.json:ro ``" -ForegroundColor White
    Write-Host "  ${ServiceName}:local-latest" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "✗ Error al construir la imagen" -ForegroundColor Red
    exit 1
}
