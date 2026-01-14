# NiFi Playground Implementation Plan

## Goal Description
Create a development playground for NiFi on Minikube using NiFiKop (NiFi Operator). The setup will include scripts to start Minikube, and Helm charts to deploy the NiFi Operator, NiFi Clusters (in multiple namespaces), and NiFi Registry.

## User Review Required
> [!NOTE]
> Ensuring specific versions of NiFiKop are used. I will target the latest stable version.

> [!NOTE]
> **Simplification**: `cert-manager` is disabled (`nifikop.certManager.enabled=false`) to reduce complexity and resource overhead for this playground. Secure communication (TLS) between nodes is not strictly required for this local development setup.

## Proposed Changes

### Scripts
#### [NEW] [setup-minikube.sh](file:///home/rami/Work/artemis/charts/nifi-playground/scripts/setup-minikube.sh)
- Script to start a Minikube cluster with sufficient resources (CPUs/Memory) for NiFi.

#### [NEW] [deploy.sh](file:///home/rami/Work/artemis/charts/nifi-playground/scripts/deploy.sh)
- Script to orchestrate the Helm deployments to different namespaces.

### Helm Charts
#### [NEW] [Chart.yaml](file:///home/rami/Work/artemis/charts/nifi-playground/Chart.yaml)
- Umbrella chart or specific chart for the playground.
- Dependencies: `nifikop` (using `konpyutaika-incubator` repo).

#### [NEW] [values.yaml](file:///home/rami/Work/artemis/charts/nifi-playground/values.yaml)
- Configuration for Operator, Clusters, and Registry.

## Verification Plan

### Automated Tests
- Run `setup-minikube.sh` and check `kubectl get nodes`.
- Run `deploy.sh`.
- Check pods: `kubectl get pods -A`.

### Manual Verification
- Access NiFi UI via port-forwarding or Ingress (if configured).
