#!/bin/bash
# ============================================================================
# Terraform Deployment Helper Script
# ============================================================================
# Script para facilitar el despliegue de infraestructura Terraform
# Uso: ./deploy.sh <ambiente> <acción>
# ============================================================================

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validar argumentos
if [ $# -lt 2 ]; then
    log_error "Uso: $0 <ambiente> <acción>"
    echo ""
    echo "Ambientes: dev, qa, prod"
    echo "Acciones: init, plan, apply, destroy, output, validate, fmt"
    echo ""
    echo "Ejemplos:"
    echo "  $0 dev init     # Inicializar Terraform para dev"
    echo "  $0 dev plan     # Ver plan de cambios para dev"
    echo "  $0 dev apply    # Aplicar cambios en dev"
    echo "  $0 prod plan    # Ver plan de cambios para prod"
    exit 1
fi

ENV=$1
ACTION=$2

# Validar ambiente
if [[ ! "$ENV" =~ ^(dev|qa|prod)$ ]]; then
    log_error "Ambiente inválido: $ENV"
    echo "Ambientes válidos: dev, qa, prod"
    exit 1
fi

# Variables
TFVARS_FILE="env/${ENV}.tfvars"
PLAN_FILE="${ENV}.tfplan"

# Validar que el archivo tfvars existe
if [ ! -f "$TFVARS_FILE" ]; then
    log_error "Archivo de variables no encontrado: $TFVARS_FILE"
    exit 1
fi

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   🚀 Apolo Procesamiento Inteligente - Terraform Deploy   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log_info "Ambiente: ${GREEN}${ENV}${NC}"
log_info "Acción: ${BLUE}${ACTION}${NC}"
echo ""

# Funciones para cada acción
terraform_init() {
    log_info "Inicializando Terraform..."
    terraform init -upgrade
    log_success "Terraform inicializado correctamente"
}

terraform_validate() {
    log_info "Validando configuración de Terraform..."
    terraform validate
    log_success "Configuración válida"
}

terraform_fmt() {
    log_info "Formateando archivos Terraform..."
    terraform fmt -recursive
    log_success "Archivos formateados"
}

terraform_plan() {
    log_info "Generando plan de ejecución para ${ENV}..."
    terraform plan -var-file="$TFVARS_FILE" -out="$PLAN_FILE"
    log_success "Plan generado: $PLAN_FILE"
    echo ""
    log_warning "Revisa el plan cuidadosamente antes de aplicar"
    log_info "Para aplicar: $0 $ENV apply"
}

terraform_apply() {
    if [ ! -f "$PLAN_FILE" ]; then
        log_warning "No se encontró plan previo. Generando plan..."
        terraform_plan
        echo ""
    fi

    log_warning "¿Estás seguro de aplicar estos cambios en ${ENV}? (yes/no)"
    read -r confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Operación cancelada"
        exit 0
    fi

    log_info "Aplicando cambios en ${ENV}..."
    terraform apply "$PLAN_FILE"
    log_success "Cambios aplicados correctamente"
    
    # Limpiar plan file
    rm -f "$PLAN_FILE"
    
    # Mostrar outputs importantes
    echo ""
    log_info "Outputs importantes:"
    terraform output function_url
    terraform output pdf_bucket_name
}

terraform_destroy() {
    log_error "⚠️  PELIGRO: Vas a DESTRUIR todos los recursos en ${ENV} ⚠️"
    log_warning "Escribe el nombre del ambiente para confirmar: "
    read -r confirmation
    
    if [ "$confirmation" != "$ENV" ]; then
        log_info "Operación cancelada"
        exit 0
    fi

    log_warning "Última confirmación. Escribe 'DESTROY' para continuar: "
    read -r final_confirm
    
    if [ "$final_confirm" != "DESTROY" ]; then
        log_info "Operación cancelada"
        exit 0
    fi

    log_info "Destruyendo recursos en ${ENV}..."
    terraform destroy -var-file="$TFVARS_FILE" -auto-approve
    log_success "Recursos destruidos"
}

terraform_output() {
    log_info "Mostrando outputs para ${ENV}..."
    echo ""
    terraform output
    echo ""
    log_info "Para ver un output específico: terraform output <nombre>"
}

# Ejecutar acción
case $ACTION in
    init)
        terraform_init
        ;;
    validate)
        terraform_validate
        ;;
    fmt)
        terraform_fmt
        ;;
    plan)
        terraform_validate
        terraform_plan
        ;;
    apply)
        terraform_validate
        terraform_apply
        ;;
    destroy)
        terraform_destroy
        ;;
    output)
        terraform_output
        ;;
    *)
        log_error "Acción desconocida: $ACTION"
        echo "Acciones válidas: init, plan, apply, destroy, output, validate, fmt"
        exit 1
        ;;
esac

echo ""
log_success "✓ Operación completada"
echo ""
