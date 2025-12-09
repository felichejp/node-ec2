#!/bin/bash
set -e

# Script para construir la AMI personalizada con Docker preinstalado

echo "=== Building Custom AMI: al2023-docker-arm64 ==="
echo ""

# Verificar que Packer está instalado
if ! command -v packer &> /dev/null; then
    echo "Error: Packer no está instalado"
    echo "Instala Packer desde: https://www.packer.io/downloads"
    exit 1
fi

# Verificar que AWS CLI está configurado
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI no está instalado"
    exit 1
fi

# Verificar credenciales AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials no configuradas"
    echo "Configura tus credenciales con: aws configure o export AWS_PROFILE"
    exit 1
fi

echo "Packer version:"
packer version

echo ""
echo "AWS Account:"
aws sts get-caller-identity --query 'Account' --output text

echo ""
echo "Iniciando construcción de AMI..."
echo ""

# Construir la AMI
packer build al2023-docker-arm64.pkr.hcl

echo ""
echo "=== AMI construida exitosamente ==="
echo ""
echo "Para usar esta AMI en Terraform, actualiza el módulo compute con:"
echo "  custom_ami_id = \"<AMI_ID>\""
echo ""
echo "El AMI ID se puede encontrar en el archivo packer-manifest.json"

