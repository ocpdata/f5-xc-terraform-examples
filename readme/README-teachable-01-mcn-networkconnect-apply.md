# Teachable 01-mcn-networkconnect Apply

Este documento describe el workflow de GitHub Actions:

- `.github/workflows/teachable-01-mcn-networkconnect-apply.yaml`

Su objetivo es desplegar y validar escenarios del laboratorio **01-mcn-networkconnect** (AWS, Azure, Global Network y Enhanced Firewall) usando Terraform Cloud y credenciales de XC/AWS/Azure.

## Objetivo del workflow

El workflow orquesta, según la lección seleccionada:

1. Aplicación de variables de entorno para el laboratorio.
2. Aprovisionamiento de networking y credenciales cloud.
3. Creación/actualización de sitios (AWS VPC Site / Azure VNET Site).
4. Configuración de conectividad global entre sitios.
5. Validaciones de conectividad (SSH, ping y HTTP).
6. (Opcional) Aplicación y prueba de reglas de Enhanced Firewall.

## Triggers

- `workflow_dispatch`
  - Permite ejecución manual desde GitHub.
  - Inputs:
    - `lesson` (choice):
      - `azure-vnet-site`
      - `aws-vpc-site`
      - `global-network`
      - `enhanced-firewall`
    - `TF_VAR_prefix` (string, opcional)

- `workflow_call`
  - Permite invocación desde otros workflows.
  - Inputs:
    - `lesson`
    - `TF_VAR_prefix` (opcional)

## Secretos requeridos

### Terraform / XC

- `TF_CLOUD_ORGANIZATION`
- `TF_API_TOKEN`
- `XC_API_URL`
- `XC_P12_PASSWORD`
- `XC_API_P12_FILE`

### AWS

- `AWS_ACCESS_KEY`
- `AWS_SECRET_KEY`
- `AWS_SESSION_TOKEN`
- `XC_AWS_CLOUD_CREDENTIALS_NAME`

### Azure

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `XC_AZURE_CLOUD_CREDENTIALS_NAME`

## Jobs principales

- `apply_variables`
  - Aplica variables base y exporta outputs para jobs dependientes.

- `aws_credentials`, `aws_networking`, `aws_vpc_site`
  - Flujo para aprovisionamiento en AWS.

- `azure_credentials`, `azure_networking`, `azure_vnet_site`
  - Flujo para aprovisionamiento en Azure.

- `global_network`
  - Ejecuta Terraform para conectar dominios/sitios y expone outputs de conectividad:
    - `ssh_private_key`
    - `ssh_host`
    - `ssh_port`
    - IPs privadas de VMs, entre otros.

- `azure_global_network`, `aws_global_network`
  - Reaplica sitios con conexión al Global Network.

- `test_connection`
  - Valida conectividad extremo a extremo usando SSH hacia host de prueba y luego:
    - `ping` a VM privada AWS.
    - `curl` HTTP hacia endpoint de prueba.

- `xc_enhanced_firewall_rules`, `aws_enhanced_firewall`, `test_enhanched_firewall`
  - Solo para `lesson: enhanced-firewall`.
  - Aplica reglas de firewall y valida impacto en conectividad.

## Arquitectura desplegada por el workflow

```mermaid
flowchart LR
    OP[Operator / Dev Laptop]
    NET[Public Internet]

    subgraph AZURE_SITE[Azure Site]
      subgraph AZ_VNET[Azure VNET 172.10.0.0/16]
        AZ_OUT[Outside Subnet 172.10.31.0/24]
        AZ_IN[Inside Subnet 172.10.21.0/24]
        AZ_VM[Azure Test VM 172.10.21.100]
      end
      AZ_CE[XC Azure VNET Site]
      AZ_OUT --> AZ_CE
      AZ_IN --> AZ_CE
      AZ_VM --> AZ_IN
    end

    subgraph AWS_SITE[AWS Site]
      subgraph AWS_VPC[AWS VPC 10.10.0.0/16]
        AWS_OUT[Outside Subnet 10.10.31.0/24]
        AWS_IN[Inside Subnet 10.10.11.0/24]
        AWS_WL[Workload Subnet 10.10.21.0/24]
        AWS_VM[AWS Test VM 10.10.21.100]
      end
      AWS_CE[XC AWS VPC Site]
      AWS_OUT --> AWS_CE
      AWS_IN --> AWS_CE
      AWS_WL --> AWS_CE
      AWS_VM --> AWS_WL
    end

    subgraph XC_CORE[F5 Distributed Cloud]
      GVN
      EFW
    end

    OP --> NET --> AZ_CE
    AZ_CE <-->|Site Link| GVN
    AWS_CE <-->|Site Link| GVN

    AZ_VM -->|Ping / HTTP over Global Network| AWS_VM
    EFW -.optional policy attachment.-> AWS_CE
```

## Mejoras de robustez SSH incorporadas

En los jobs de prueba (`test_connection` y `test_enhanched_firewall`) se agregaron controles para reducir fallos intermitentes:

1. Decodificación segura de llave con `printf` + `base64 --decode`.
2. Validación de llave privada con `ssh-keygen -y -f`.
3. Reintentos de SSH (12 intentos, espera de 10 segundos).
4. Diagnóstico detallado (`-vvv`) solo en el último intento.

Esto ayuda especialmente cuando el endpoint SSH todavía no está listo al primer intento y evita fallos tempranos con `exit code 255`.

## Ejecución manual

1. Ir a **Actions** en GitHub.
2. Seleccionar workflow: **Teachable 01-mcn-networkconnect Apply**.
3. Ejecutar con **Run workflow**.
4. Elegir `lesson` según escenario.
5. (Opcional) definir `TF_VAR_prefix`.

## Criterios de éxito

- Los jobs de aprovisionamiento terminan en estado `success`.
- En `test_connection`:
  - SSH inicial exitoso.
  - Ping al target privado exitoso (o comportamiento esperado en pruebas de firewall).
  - Respuesta HTTP del endpoint de prueba.

## Troubleshooting rápido

- **Error de SSH (255 / connection closed):**
  - Revisar logs del último intento (`-vvv`).
  - Verificar que `ssh_host` y `ssh_port` de outputs sean correctos.
  - Confirmar que la VM/bastion esté activa y con acceso permitido.

- **Fallas de Terraform init/apply:**
  - Validar `TF_API_TOKEN`, `TF_CLOUD_ORGANIZATION` y nombre de workspace.
  - Confirmar que el secreto `XC_API_P12_FILE` esté correctamente codificado en base64.

- **Fallas de acceso cloud:**
  - Revisar expiración/permisos de credenciales AWS y Azure.

## Ruta del archivo del workflow

- `.github/workflows/teachable-01-mcn-networkconnect-apply.yaml`
