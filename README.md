# Node.js on AWS EC2 with CI/CD

Este proyecto implementa una infraestructura completa en AWS para desplegar una aplicación Node.js utilizando Terraform, Docker, y un pipeline de CI/CD automatizado.

## Arquitectura

La infraestructura se despliega en AWS utilizando **Terraform** y consta de los siguientes componentes:

*   **VPC:** Red privada virtual con subredes públicas y privadas en múltiples zonas de disponibilidad.
*   **Compute (EC2):** Instancia `t4g.small` (ARM64) basada en Amazon Linux 2023.
    *   Docker preinstalado y configurado vía `user_data`.
    *   Expansión automática del sistema de archivos.
    *   Acceso gestionado vía AWS Systems Manager (SSM) - Sin SSH abierto.
*   **Contenedores:**
    *   **Amazon ECR:** Repositorios privados para almacenar imágenes Docker de la aplicación y entornos de construcción.
    *   **Buildah:** Herramienta utilizada en el CI para construir imágenes Docker sin daemon, optimizado para seguridad.
*   **CI/CD Pipeline:**
    *   **AWS CodePipeline:** Orquesta el flujo de despliegue.
    *   **AWS CodeBuild:** Construye la imagen Docker de la aplicación y la sube a ECR.
    *   **GitHub Actions:** Construye y actualiza las imágenes base y de entorno (Buildah) en ECR.
    *   **EventBridge:** Dispara el pipeline automáticamente cuando se actualiza el código fuente en S3.
*   **Almacenamiento:**
    *   **S3:** Bucket para almacenar el código fuente (artefactos) y logs.

## Estructura del Proyecto

```
.
├── .github/workflows/   # Workflows de GitHub Actions (Build imágenes base)
├── Docker-Images/       # Dockerfiles para imágenes base y herramientas
├── code/                # Código fuente de la aplicación Node.js
├── infra/               # Código Terraform (IaC)
│   ├── modules/
│   │   ├── cicd/        # CodePipeline, CodeBuild
│   │   ├── compute/     # Instancia EC2, Security Groups
│   │   ├── ecr/         # Repositorios ECR
│   │   ├── networking/  # VPC, Subnets, Gateways
│   │   └── s3/          # Bucket S3
│   └── main.tf          # Configuración principal de Terraform
└── README.md
```

## Requisitos

*   [Terraform](https://www.terraform.io/downloads.html) >= 1.0
*   [AWS CLI](https://aws.amazon.com/cli/) configurado con credenciales.
*   Una cuenta de AWS.

## Despliegue

1.  **Inicializar Terraform:**
    ```bash
    cd infra
    terraform init
    ```

2.  **Planificar cambios:**
    ```bash
    terraform plan
    ```

3.  **Aplicar infraestructura:**
    ```bash
    terraform apply
    ```

## Flujo de Trabajo (CI/CD)

1.  **Imágenes Base:**
    *   Al crear un tag en git (ej: `base-image-node22-v1.0.0`), GitHub Actions construye la imagen base y la sube a ECR.

2.  **Despliegue de Aplicación:**
    *   Al crear un tag en git (ej: `server-v1.0.0`), GitHub Actions empaqueta el código (`server.zip`) y lo sube a S3.
    *   EventBridge detecta el nuevo archivo en S3 y activa CodePipeline.
    *   CodeBuild descarga el zip, construye la imagen Docker y la sube a ECR.
    *   CodeBuild se conecta a la instancia EC2 vía SSM y actualiza el contenedor en ejecución con la nueva imagen.

## Seguridad

*   La instancia EC2 no tiene el puerto 22 (SSH) abierto a internet. El acceso se realiza exclusivamente a través de AWS Systems Manager (Session Manager).
*   Solo el puerto 80 (HTTP) está expuesto públicamente.
*   Los roles de IAM siguen el principio de privilegio mínimo.
