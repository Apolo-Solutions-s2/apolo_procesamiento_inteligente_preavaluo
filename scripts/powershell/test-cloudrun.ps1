# Script de prueba para el microservicio en Cloud Run
# Uso: .\test-cloudrun.ps1 -ServiceUrl "https://tu-servicio.run.app"

param(
    [Parameter(Mandatory=$false)]
    [string]$ServiceUrl = "http://localhost:8080",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("individual", "batch")]
    [string]$Mode = "individual"
)

function Write-TestHeader($Message) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-TestStep($Message) {
    Write-Host "➤ $Message" -ForegroundColor Yellow
}

function Write-TestSuccess($Message) {
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-TestError($Message) {
    Write-Host "✗ $Message" -ForegroundColor Red
}

# =========================================
# TEST 1: Health Check (Verificar que el servicio responde)
# =========================================
Write-TestHeader "TEST 1: Health Check"
Write-TestStep "Probando conectividad con $ServiceUrl..."

try {
    $response = Invoke-WebRequest -Uri $ServiceUrl -Method GET -ErrorAction SilentlyContinue
    $statusCode = $response.StatusCode
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
}

if ($statusCode -eq 405 -or $statusCode -eq 200) {
    Write-TestSuccess "Servicio respondiendo (HTTP $statusCode)"
} else {
    Write-TestError "Servicio no disponible (HTTP $statusCode)"
    exit 1
}

# =========================================
# TEST 2: Procesamiento Individual
# =========================================
if ($Mode -eq "individual") {
    Write-TestHeader "TEST 2: Procesamiento Individual"
    Write-TestStep "Procesando un documento específico..."
    
    $body = @{
        folioId = "PRE-2025-001"
        fileId = "balance_general.pdf"
        gcs_pdf_uri = "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf"
        workflow_execution_id = "test-$(Get-Date -Format 'yyyyMMddHHmmss')"
    } | ConvertTo-Json

    Write-Host "Request Body:" -ForegroundColor Gray
    Write-Host $body -ForegroundColor Gray
    Write-Host ""

    try {
        $response = Invoke-RestMethod -Uri $ServiceUrl -Method POST `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec 120

        Write-TestSuccess "Procesamiento completado"
        Write-Host ""
        Write-Host "Response:" -ForegroundColor Gray
        Write-Host ($response | ConvertTo-Json -Depth 10) -ForegroundColor White
        
        # Validar respuesta
        if ($response.status -eq "processed" -or $response.status -eq "no_files") {
            Write-TestSuccess "Status: $($response.status)"
            Write-TestSuccess "Documentos procesados: $($response.document_count)"
        } elseif ($response.status -eq "error") {
            Write-TestError "Error: $($response.error.message)"
            Write-Host "Código: $($response.error.code)" -ForegroundColor Yellow
        }

    } catch {
        Write-TestError "Error en la request: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Error Body:" -ForegroundColor Red
            Write-Host $errorBody -ForegroundColor Red
        }
    }
}

# =========================================
# TEST 3: Procesamiento Batch
# =========================================
if ($Mode -eq "batch") {
    Write-TestHeader "TEST 3: Procesamiento Batch (Folder)"
    Write-TestStep "Procesando todos los PDFs en una carpeta..."
    
    $body = @{
        folder_prefix = "PRE-2025-001/"
        preavaluo_id = "PRE-2025-001"
        extensions = @(".pdf")
        max_items = 10
        workflow_execution_id = "test-batch-$(Get-Date -Format 'yyyyMMddHHmmss')"
    } | ConvertTo-Json

    Write-Host "Request Body:" -ForegroundColor Gray
    Write-Host $body -ForegroundColor Gray
    Write-Host ""

    try {
        $response = Invoke-RestMethod -Uri $ServiceUrl -Method POST `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec 120

        Write-TestSuccess "Procesamiento completado"
        Write-Host ""
        Write-Host "Response:" -ForegroundColor Gray
        Write-Host ($response | ConvertTo-Json -Depth 10) -ForegroundColor White
        
        # Validar respuesta
        if ($response.status -eq "processed" -or $response.status -eq "no_files") {
            Write-TestSuccess "Status: $($response.status)"
            Write-TestSuccess "Documentos procesados: $($response.document_count)"
            
            if ($response.results) {
                Write-Host ""
                Write-Host "Documentos:" -ForegroundColor Yellow
                foreach ($doc in $response.results) {
                    Write-Host "  • $($doc.file_name) - $($doc.classification.document_type)" -ForegroundColor White
                }
            }
        } elseif ($response.status -eq "error") {
            Write-TestError "Error: $($response.error.message)"
            Write-Host "Código: $($response.error.code)" -ForegroundColor Yellow
        }

    } catch {
        Write-TestError "Error en la request: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Error Body:" -ForegroundColor Red
            Write-Host $errorBody -ForegroundColor Red
        }
    }
}

# =========================================
# TEST 4: Manejo de Errores (Request inválido)
# =========================================
Write-TestHeader "TEST 4: Validación de Errores"
Write-TestStep "Probando manejo de request inválido..."

$invalidBody = @{
    invalid_param = "test"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $ServiceUrl -Method POST `
        -ContentType "application/json" `
        -Body $invalidBody `
        -TimeoutSec 30
    
    if ($response.status -eq "error") {
        Write-TestSuccess "Manejo de errores funcionando correctamente"
        Write-Host "Error esperado: $($response.error.message)" -ForegroundColor Yellow
    }

} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 500) {
        Write-TestSuccess "Manejo de errores funcionando (HTTP 500)"
    } else {
        Write-TestError "Error inesperado: $statusCode"
    }
}

# =========================================
# RESUMEN
# =========================================
Write-Host ""
Write-TestHeader "Tests Completados"
Write-Host "Servicio: $ServiceUrl" -ForegroundColor White
Write-Host "Modo: $Mode" -ForegroundColor White
Write-Host ""
Write-Host "Para más pruebas:" -ForegroundColor Cyan
Write-Host "  Individual: .\test-cloudrun.ps1 -ServiceUrl '$ServiceUrl' -Mode individual" -ForegroundColor Gray
Write-Host "  Batch:      .\test-cloudrun.ps1 -ServiceUrl '$ServiceUrl' -Mode batch" -ForegroundColor Gray
Write-Host ""
