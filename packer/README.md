# Packer AMI Build

Este directorio contiene la configuración de Packer para crear una AMI personalizada basada en Amazon Linux 2023 ARM64 con Docker y SSM Agent preinstalados.

## Requisitos

- Packer instalado: https://www.packer.io/downloads
- AWS CLI configurado con credenciales apropiadas
- Permisos IAM para crear AMIs y lanzar instancias EC2

## Uso

### Construir la AMI

```bash
cd packer
export AWS_PROFILE=personal  # o usa tus credenciales AWS
packer build al2023-docker-arm64.pkr.hcl
```

### Usar la AMI en Terraform

Después de construir la AMI, actualiza el módulo `compute` para usar la AMI personalizada en lugar de la AMI pública.

