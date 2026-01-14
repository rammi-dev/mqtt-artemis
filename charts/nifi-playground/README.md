# NiFi Playground

A local Kubernetes environment for running Apache NiFi, NiFi Registry, and NiFi Operator using Minikube. This project automates the deployment of a full NiFi stack including shared infrastructure like ZooKeeper and PostgreSQL.

## Prerequisites

Ensure you have the following installed locally:
*   **Docker**: Container runtime.
*   **Minikube**: Local Kubernetes cluster.
*   **Kubectl**: Kubernetes CLI.
*   **Helm**: Package manager for Kubernetes.

## Quick Start

### 1. Setup Environment
Initialize the Minikube cluster with the required profile and resources:
```bash
./scripts/setup-minikube.sh
```

### 2. Configuration
Create a `.env` file from the example to set your database credentials:
```bash
cp .env.example .env
# Edit .env if you want to change default passwords
```

### 3. Deploy All
Deploy the entire stack (Storage, Zookeeper, Postgres, Operator, Registry, Clusters) in the correct order:
```bash
./scripts/deploy.sh all
```
*Note: This script handles image building, dependency updates, and ordered deployment.*

## Deployment Options

You can also deploy components individually using `./scripts/deploy.sh [component]`:

| Command | Description |
|---------|-------------|
| `build` | Build custom Docker images (e.g., NiFi Registry with Postgres Driver) |
| `storage-zookeeper` | Deploy StorageClass for ZooKeeper |
| `secrets` | Generate Kubernetes Secrets from `.env` |
| `zookeeper` | Deploy Shared ZooKeeper |
| `postgres` | Deploy Shared PostgreSQL |
| `operator` | Deploy NiFi Operator (CRDs & Controller) |
| `registry` | Deploy NiFi Registry (Custom Image) |
| `clusters` | Deploy NiFi Clusters (Init & Secondary) |

## Accessing Services

### NiFi Registry
*   **URL:** `http://localhost:8080/nifi-registry`
*   **Port Forwarding:** (If not using Ingress/NodePort with localhost binding)
    ```bash
    kubectl port-forward -n nifi-registry svc/nifi-registry 8080:18080
    ```

### NiFi Clusters
*   **URL (Init Cluster):** `https://localhost:8443/nifi` (Port may vary, check `kubectl get svc -n nifi-initcluster`)

## Custom Images
This project uses a custom Docker image for NiFi Registry to include the PostgreSQL JDBC driver and a robust startup script.
*   Source: `images/nifi-registry/`
*   Build Command: `./scripts/deploy.sh build`

## Teardown
To stop and completely remove the local cluster:
```bash
minikube delete -p nifi-playground
```
