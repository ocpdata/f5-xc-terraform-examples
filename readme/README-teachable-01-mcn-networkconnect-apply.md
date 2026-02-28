# Teachable 01-mcn-networkconnect Apply

Este documento describe el workflow de GitHub Actions:

- `.github/workflows/teachable-01-mcn-networkconnect-apply.yaml`

Su objetivo es desplegar y validar escenarios del laboratorio **01-mcn-networkconnect** (AWS, Azure, Global Network y Enhanced Firewall) usando Terraform Cloud y credenciales de XC/AWS/Azure.

---

## Resumen de arquitectura y caso de uso

### ¿Para qué sirve este laboratorio?

Este laboratorio implementa un escenario de **Multi-Cloud Networking (MCN)** entre AWS y Azure utilizando **F5 Distributed Cloud (XC)** como plano de conectividad y control. Cubre tres capacidades clave de la plataforma:

| Capacidad                                      | Descripción                                                                                                                                                                                                |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Conectividad multi-cloud**                   | Establece un túnel cifrado entre un sitio AWS y un sitio Azure a través de la Global Virtual Network de XC, sin necesidad de VPNs tradicionales ni peering directo entre nubes.                            |
| **Customer Edge (CE) como punto de presencia** | Despliega nodos CE de F5 XC dentro del VPC/VNET del cliente, actuando como gateway inteligente con visibilidad y control de tráfico este-oeste entre nubes.                                                |
| **Enhanced Firewall distribuido**              | Aplica políticas de seguridad de red directamente en el CE (micro-segmentación entre nubes), permitiendo bloquear o permitir flujos específicos sin alterar la infraestructura de red nativa de cada nube. |

### Arquitectura conceptual

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         F5 Distributed Cloud (XC)                           │
│                                                                              │
│    ┌──────────────────────────────────────────────────────────────────┐     │
│    │                    Global Virtual Network (GVN)                   │     │
│    │          Plano de conectividad cifrada entre sitios               │     │
│    └──────────┬───────────────────────────────────┬───────────────────┘     │
└───────────────┼───────────────────────────────────┼─────────────────────────┘
                │ Site Link                          │ Site Link
     ┌──────────▼──────────┐               ┌─────────▼───────────┐
     │    AWS VPC Site      │               │  Azure VNET Site     │
     │  (Customer Edge CE)  │               │  (Customer Edge CE)  │
     │                      │               │                      │
     │  VPC 10.10.0.0/16    │               │  VNET 172.10.0.0/16  │
     │  ├─ Outside (WAN)    │               │  ├─ Outside (WAN)    │
     │  ├─ Inside  (LAN)    │               │  └─ Inside  (LAN)    │
     │  └─ Workload subnet  │               │                      │
     │     └─ AWS Test VM   │               │  └─ Azure Test VM    │
     │        10.10.21.100  │               │     172.10.21.100    │
     └──────────────────────┘               └─────────────────────┘
              ▲  Ping / HTTP sobre GVN                ▲
              └────────────────────────────────────────┘
                 Tráfico este-oeste inter-cloud validado
```

### Casos de uso típicos

1. **Conectar workloads en múltiples nubes sin infraestructura de red compleja**
   Empresas que despliegan aplicaciones distribuidas entre AWS y Azure pueden usar XC MCN para que los servicios se comuniquen de forma privada sin gestionar VPNs, Transit Gateways o ExpressRoute/Direct Connect.

2. **Migración progresiva de workloads entre nubes**
   Permite que una aplicación en Azure consuma servicios legacy en AWS (o viceversa) durante una migración, con visibilidad y control de tráfico centralizado en XC.

3. **Seguridad perimetral distribuida (Enhanced Firewall)**
   Aplicar políticas de firewall L3/L4 en los CE de cada nube para micro-segmentar el tráfico inter-cloud sin depender de los security groups nativos de cada proveedor. Ideal cuando se requiere una política de seguridad uniforme multi-cloud.

4. **Laboratorio de aprendizaje / PoC**
   Valida en un entorno reproducible y automatizado cómo XC establece la conectividad, qué rutas se propagan y cómo se comporta el firewall distribuido ante reglas de permiso/denegación.

### Componentes desplegados por lección

```
azure-vnet-site   →  Red Azure + Credenciales XC + CE Azure
aws-vpc-site      →  Red AWS   + Credenciales XC + CE AWS
global-network    →  Todo lo anterior + GVN + VMs de prueba + test ping/HTTP
enhanced-firewall →  Todo lo anterior + reglas de firewall XC + test de bloqueo
```

---

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
  RUNNER[GitHub Actions Runner]
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

    RUNNER --> NET --> AZ_CE
    AZ_CE <-->|Site Link| GVN
    AWS_CE <-->|Site Link| GVN

    AZ_VM -->|Ping / HTTP over Global Network| AWS_VM
    EFW -.optional policy attachment.-> AWS_CE
```

### Rol de las subredes en la topología

| Subred                  | Propósito principal                                               | Uso en este laboratorio                                                          |
| ----------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `outside subnet`        | Lado WAN/upstream del sitio XC (salida/entrada hacia red externa) | Permite que el CE establezca conectividad con XC y transporte enlaces del sitio. |
| `inside subnet`         | Lado LAN/downstream del sitio XC                                  | Conecta el CE con la red interna del entorno (rutas privadas).                   |
| `workload subnet` (AWS) | Segmento de cargas de aplicación                                  | Aloja la VM de prueba `10.10.21.100` usada para ping/HTTP desde Azure.           |

En resumen: **outside = borde externo**, **inside = borde interno**, **workload = apps**.

## Mejoras de robustez SSH incorporadas

En los jobs de prueba (`test_connection` y `test_enhanched_firewall`) se agregaron controles para reducir fallos intermitentes:

1. Decodificación segura de llave con `printf` + `base64 --decode`.
2. Validación de llave privada con `ssh-keygen -y -f`.
3. Reintentos de SSH (12 intentos, espera de 10 segundos).
4. Diagnóstico detallado (`-vvv`) solo en el último intento.

Esto ayuda especialmente cuando el endpoint SSH todavía no está listo al primer intento y evita fallos tempranos con `exit code 255`.

## Pruebas manuales desde laptop

Una vez que el workflow haya terminado correctamente en lección `global-network`, puedes replicar las mismas pruebas que ejecuta el job `test_connection` desde tu laptop.

### Pre-requisitos

- Haber configurado el secreto `SSH_PRIVATE_KEY` en GitHub (la misma llave se usa para provisionar las VMs).
- Tener los valores de `ssh_host` y `ssh_port` del job `global_network` (se imprimen en el log del step **Print output vars**).
- Tu llave privada local (la que corresponde a `SSH_PRIVATE_KEY`):

```bash
SSH_KEY=~/.ssh/mcn_lab        # ruta a tu llave privada
SSH_HOST="<valor de ssh_host>" # ej: ves-io-xxxx.ac.vh.ves.io
SSH_PORT="<valor de ssh_port>" # ej: 9322
AWS_VM_IP="10.10.21.100"       # IP privada de la VM en AWS
```

Debe ejecutarse el siguiente comando para proteger la llave privada local

```bash
chmod 600 "$SSH_KEY"
```

### 1. Verificar que la llave es válida

```bash
ssh-keygen -y -f "$SSH_KEY"
```

Debe devolver la clave pública. Si falla, la llave no coincide con la usada en el deploy.

### 2. Test de conectividad SSH (jump host Azure → runner)

```bash
ssh -i "$SSH_KEY" \
    -p "$SSH_PORT" \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    ubuntu@"$SSH_HOST" \
    "echo 'SSH connection successful.'"
```

### 3. Test de Ping (Azure VM → AWS VM via Global Network)

```bash
ssh -i "$SSH_KEY" \
    -p "$SSH_PORT" \
    -o StrictHostKeyChecking=no \
    ubuntu@"$SSH_HOST" \
    "ping -c 4 -W 10 -v $AWS_VM_IP"
```

> **Nota:** 100% packet loss en el ping no es bloqueante — ICMP puede estar restringido por security group. El test real es HTTP.

### 4. Test HTTP (Azure VM → AWS VM via Global Network)

```bash
ssh -i "$SSH_KEY" \
    -p "$SSH_PORT" \
    -o StrictHostKeyChecking=no \
    ubuntu@"$SSH_HOST" \
    "curl -s -D - http://$AWS_VM_IP/test"
```

Una respuesta HTTP `200 OK` confirma que la conectividad MCN Azure↔AWS está operativa.

### 5. Script completo

```bash
#!/usr/bin/env bash
set -euo pipefail

SSH_KEY=~/.ssh/mcn_lab
SSH_HOST="<ssh_host del output>"
SSH_PORT="<ssh_port del output>"
AWS_VM_IP="10.10.21.100"

SSH_OPTS=(-i "$SSH_KEY" -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

echo "=== SSH Test ==="
ssh "${SSH_OPTS[@]}" ubuntu@"$SSH_HOST" "echo 'SSH OK'"

echo "=== Ping Test ==="
ssh "${SSH_OPTS[@]}" ubuntu@"$SSH_HOST" "ping -c 4 -W 10 $AWS_VM_IP" || echo "Ping failed (may be blocked by SG)"

echo "=== HTTP Test ==="
ssh "${SSH_OPTS[@]}" ubuntu@"$SSH_HOST" "curl -s -D - http://$AWS_VM_IP/test"
```

### Obtener ssh_host y ssh_port

Los valores se muestran en el log del step **Print output vars** del job `global_network`:

```
ssh_host: ves-io-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.ac.vh.ves.io
ssh_port: XXXXX
```

También disponibles como outputs del job en la sección **Summary** del workflow run.

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

---

## Destroy del laboratorio

### Workflow de destroy

El archivo `.github/workflows/teachable-01-mcn-networkconnect-destroy.yaml` destruye **todos** los recursos aprovisionados por el apply, independientemente de la lección que fue ejecutada. No requiere seleccionar lección: elimina todo el stack completo en un único disparo.

**Triggers:**

- `workflow_dispatch` — ejecución manual desde GitHub Actions.
- `workflow_call` — invocación desde otro workflow.

**Input opcional:** `TF_VAR_prefix` — debe coincidir con el prefijo usado en el apply.

### Orden de destrucción

El destroy respeta el orden inverso al apply para evitar dependencias huérfanas en F5 XC y en las nubes:

```
apply_variables
    ├── aws_vpc_site      (1° — elimina CE en AWS; quita la referencia al enhanced firewall y al GVN)
    │       ├── aws_credentials   (2° — elimina credenciales AWS en XC)
    │       └── aws_networking    (2° — elimina VPC, subredes y SGs en AWS)
    ├── azure_vnet_site   (1° — elimina CE en Azure; quita la referencia al GVN)
    │       ├── azure_credentials  (2° — elimina credenciales Azure en XC)
    │       └── azure_networking   (2° — elimina VNET y subredes en Azure)
    └── enhanced_firewall (2° — elimina política de firewall XC, ya sin referencias de sitios)
            └── workloads (3° — elimina GVN y VMs, ya sin referencias de sitios ni policys)
```

> **Por qué los sites se destruyen primero:** la política de Enhanced Firewall está vinculada al AWS VPC Site (referencia en XC). Si se intenta borrar la policy antes que el site, la API de XC devuelve error `409 CONFLICT: still being referred by 1 objects`. Del mismo modo, el GVN tiene referencias desde ambos sites; si los sites ya no existen, el GVN puede eliminarse limpiamente.

### Jobs del workflow de destroy

| Job                 | Terraform workspace         | Qué elimina                                              |
| ------------------- | --------------------------- | -------------------------------------------------------- |
| `enhanced_firewall` | `teachable-01-mcn-fw`       | Política de Enhanced Firewall en XC                      |
| `workloads`         | `teachable-01-mcn`          | Global Virtual Network, VMs de prueba, rutas inter-cloud |
| `aws_vpc_site`      | workspace AWS VPC Site      | Customer Edge en AWS (AWS VPC Site)                      |
| `azure_vnet_site`   | workspace Azure VNET Site   | Customer Edge en Azure (Azure VNET Site)                 |
| `aws_credentials`   | workspace AWS Credentials   | Cloud Credentials de AWS en XC                           |
| `aws_networking`    | workspace AWS Networking    | VPC, subredes y security groups en AWS                   |
| `azure_credentials` | workspace Azure Credentials | Cloud Credentials de Azure en XC                         |
| `azure_networking`  | workspace Azure Networking  | VNET y subredes en Azure                                 |

### Ejecución del destroy

1. Ir a **Actions** en GitHub.
2. Seleccionar workflow: **Teachable 01-mcn-networkconnect Destroy**.
3. Ejecutar con **Run workflow**.
4. (Opcional) definir `TF_VAR_prefix` si fue usado en el apply.

### Troubleshooting del destroy

- **Error 409 al destruir `enhanced_firewall` (`still being referred by 1 objects - aws_vpc_site`):**
  Ocurre si el AWS VPC Site todavía tiene la política adjunta. El site debe destruirse **antes** que la policy. El orden de dependencias del workflow garantiza esto: `aws_vpc_site` se ejecuta en paralelo con `azure_vnet_site` antes de `enhanced_firewall`. Si el error aparece, verificar que el job `aws_vpc_site` haya completado exitosamente antes de reintentar.

- **Falla en `workloads`:** Verificar que los secretos XC (`XC_API_P12_FILE`, `XC_P12_PASSWORD`, `XC_API_URL`) y los de AWS/Azure sean válidos. Este job requiere todos porque destruye recursos en XC, AWS y Azure.

- **Falla en `enhanced_firewall` con "workspace not found":** Normal si nunca se ejecutó la lección `enhanced-firewall`. El workspace no existe y Terraform init fallará. Se puede ignorar; no impacta el resto del destroy.

- **Recursos de red que no se destruyen (VPC/VNET) — error `InUseSubnetCannotBeDeleted`:**
  El CE de XC crea NICs en Azure durante su aprovisionamiento. Cuando el `azure_vnet_site` destroy termina en Terraform/XC, el CE todavía puede tardar varios minutos en limpiar esas NICs en Azure. Si `azure_networking` intenta destruir la subnet mientras la NIC `TEACHABLE-MCN-NIC` aún existe, Azure devuelve error `400 InUseSubnetCannotBeDeleted`.
  El workflow agrega automáticamente una espera de 3 minutos + 5 reintentos con 60 segundos de pausa en el destroy de `azure-networking`. Si persiste, esperar más tiempo y relanzar manualmente el destroy.

---

## Ruta del archivo del workflow

- `.github/workflows/teachable-01-mcn-networkconnect-apply.yaml`
- `.github/workflows/teachable-01-mcn-networkconnect-destroy.yaml`
