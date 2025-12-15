# ============================================================================
# Terraform Deployment Helper Script (PowerShell)
# ============================================================================
# Script para facilitar el despliegue de infraestructura Terraform en Windows
# Uso: .\deploy.ps1 -Environment <ambiente> -Action <acción>
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("init", "plan", "apply", "destroy", "output", "validate", "fmt")]
    [string]$Action
)

# Colores para output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Variables
$TfVarsFile = "infrastructure\terraform\env\$Environment.tfvars"
$PlanFile = "$Environment.tfplan"

# Validar que el archivo tfvars existe
if (-not (Test-Path $TfVarsFile)) {
    Write-Error-Custom "Archivo de variables no encontrado: $TfVarsFile"
    exit 1
}

# Banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🚀 Apolo Procesamiento Inteligente - Terraform Deploy   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Info "Ambiente: $Environment"
Write-Info "Acción: $Action"
Write-Host ""

# Funciones para cada acción
function Invoke-TerraformInit {
    Write-Info "Inicializando Terraform..."
    terraform init -upgrade
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform inicializado correctamente"
    } else {
        Write-Error-Custom "Error al inicializar Terraform"
        exit $LASTEXITCODE
    }
}

function Invoke-TerraformValidate {
    Write-Info "Validando configuración de Terraform..."
    terraform validate
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Configuración válida"
    } else {
        Write-Error-Custom "Configuración inválida"
        exit $LASTEXITCODE
    }
}

function Invoke-TerraformFmt {
    Write-Info "Formateando archivos Terraform..."
    terraform fmt -recursive
    Write-Success "Archivos formateados"
}

function Invoke-TerraformPlan {
    Write-Info "Generando plan de ejecución para $Environment..."
    terraform plan -var-file="$TfVarsFile" -out="$PlanFile"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Plan generado: $PlanFile"
        Write-Host ""
        Write-Warning-Custom "Revisa el plan cuidadosamente antes de aplicar"
        Write-Info "Para aplicar: .\deploy.ps1 -Environment $Environment -Action apply"
    } else {
        Write-Error-Custom "Error al generar plan"
        exit $LASTEXITCODE
    }
}

function Invoke-TerraformApply {
    if (-not (Test-Path $PlanFile)) {
        Write-Warning-Custom "No se encontró plan previo. Generando plan..."
        Invoke-TerraformPlan
        Write-Host ""
    }

    $confirmation = Read-Host "¿Estás seguro de aplicar estos cambios en $Environment ? (yes/no)"
    
    if ($confirmation -ne "yes") {
        Write-Info "Operación cancelada"
        exit 0
    }

    Write-Info "Aplicando cambios en $Environment..."
    terraform apply "$PlanFile"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Cambios aplicados correctamente"
        
        # Limpiar plan file
        if (Test-Path $PlanFile) {
            Remove-Item $PlanFile
        }
        
        # Mostrar outputs importantes
        Write-Host ""
        Write-Info "Outputs importantes:"
        terraform output function_url
        terraform output pdf_bucket_name
    } else {
        Write-Error-Custom "Error al aplicar cambios"
        exit $LASTEXITCODE
    }
}

function Invoke-TerraformDestroy {
    Write-Error-Custom "⚠️  PELIGRO: Vas a DESTRUIR todos los recursos en $Environment  ⚠️"
    $confirmation = Read-Host "Escribe el nombre del ambiente para confirmar"
    
    if ($confirmation -ne $Environment) {
        Write-Info "Operación cancelada"
        exit 0
    }

    $finalConfirm = Read-Host "Última confirmación. Escribe 'DESTROY' para continuar"
    
    if ($finalConfirm -ne "DESTROY") {
        Write-Info "Operación cancelada"
        exit 0
    }

    Write-Info "Destruyendo recursos en $Environment..."
    terraform destroy -var-file="$TfVarsFile" -auto-approve
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Recursos destruidos"
    } else {
        Write-Error-Custom "Error al destruir recursos"
        exit $LASTEXITCODE
    }
}

function Invoke-TerraformOutput {
    Write-Info "Mostrando outputs para $Environment..."
    Write-Host ""
    terraform output
    Write-Host ""
    Write-Info "Para ver un output específico: terraform output <nombre>"
}

# Ejecutar acción
switch ($Action) {
    "init" {
        Invoke-TerraformInit
    }
    "validate" {
        Invoke-TerraformValidate
    }
    "fmt" {
        Invoke-TerraformFmt
    }
    "plan" {
        Invoke-TerraformValidate
        Invoke-TerraformPlan
    }
    "apply" {
        Invoke-TerraformValidate
        Invoke-TerraformApply
    }
    "destroy" {
        Invoke-TerraformDestroy
    }
    "output" {
        Invoke-TerraformOutput
    }
}

Write-Host ""
Write-Success "✓ Operación completada"
Write-Host ""
