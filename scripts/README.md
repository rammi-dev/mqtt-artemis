# Scripts Directory

Modular deployment and utility scripts for the Edge Analytics platform.

## Structure

```
scripts/
├── lib/
│   └── common.sh           # Shared library functions
├── deploy-gke.sh          # Main deployment script (modular)
├── access-info.sh         # Service access information
└── deploy-legacy.sh       # Legacy deployment script (deprecated)
```

## Main Scripts

### deploy-gke.sh

Modular deployment script with support for step-by-step or full deployment.

**Usage:**
```bash
./scripts/deploy-gke.sh [command]
```

**Commands:**
- `all` - Deploy everything (default)
- `terraform` - Create GKE cluster
- `kubeconfig` - Configure kubectl
- `infrastructure` - Deploy cert-manager + ingress-nginx
- `cert-manager` - Deploy cert-manager only
- `ingress-nginx` - Deploy ingress-nginx only
- `analytics` - Deploy all analytics components
- `artemis` - Deploy Artemis MQTT only
- `clickhouse` - Deploy ClickHouse only
- `nifi` - Deploy Apache NiFi only
- `redis` - Deploy Redis only
- `dagster` - Deploy Dagster only
- `prometheus` - Deploy Prometheus only
- `grafana` - Deploy Grafana only
- `dashboard-api` - Deploy Dashboard API only
- `verify` - Verify deployment
- `destroy` - Destroy all resources
- `help` - Show help

**Examples:**
```bash
# Full deployment
./scripts/deploy-gke.sh all

# Step-by-step
./scripts/deploy-gke.sh terraform
./scripts/deploy-gke.sh kubeconfig
./scripts/deploy-gke.sh infrastructure
./scripts/deploy-gke.sh analytics

# Individual infrastructure components
./scripts/deploy-gke.sh cert-manager
./scripts/deploy-gke.sh ingress-nginx

# Individual analytics components
./scripts/deploy-gke.sh artemis
./scripts/deploy-gke.sh clickhouse
./scripts/deploy-gke.sh nifi
./scripts/deploy-gke.sh redis
./scripts/deploy-gke.sh dagster
./scripts/deploy-gke.sh prometheus
./scripts/deploy-gke.sh grafana
./scripts/deploy-gke.sh dashboard-api
```

### access-info.sh

Display access information for all deployed services.

**Usage:**
```bash
./scripts/access-info.sh
```

**Shows:**
- Ingress IP and domain
- Service URLs (via ingress)
- Port-forward commands
- Service credentials
- Quick commands
- API endpoints
- Cluster status

## Library

### lib/common.sh

Shared functions used by all scripts.

**Functions:**
- `log_info()` - Info message
- `log_warn()` - Warning message
- `log_error()` - Error message
- `log_step()` - Step message
- `log_success()` - Success message
- `command_exists()` - Check if command exists
- `check_required_tools()` - Verify required tools
- `check_kubectl_context()` - Verify kubectl is configured
- `check_namespace()` - Check if namespace exists
- `get_terraform_output()` - Get Terraform output value
- `wait_for_pods()` - Wait for pods to be ready
- `helm_release_exists()` - Check if Helm release exists
- `print_header()` - Print section header
- `print_section()` - Print section
- `confirm_action()` - Confirm user action

**Usage in scripts:**
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

log_info "Starting deployment..."
check_required_tools kubectl helm terraform
INGRESS_IP=$(get_terraform_output "ingress_ip")
```

## Deprecated

### deploy-legacy.sh

Original deployment script. Kept for reference but deprecated.

Use `deploy-gke.sh` instead.

## Development

### Adding New Scripts

1. Create script in `scripts/` directory
2. Source the common library:
   ```bash
   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
   ```
3. Use common functions for consistency
4. Make executable: `chmod +x scripts/your-script.sh`
5. Update this README

### Adding New Library Functions

1. Edit `lib/common.sh`
2. Add function with clear documentation
3. Export variables if needed
4. Test with existing scripts

## Best Practices

1. **Always use common library** - Don't duplicate logging/utility functions
2. **Check prerequisites** - Use `check_required_tools()` at script start
3. **Handle errors** - Use `set -e` and proper error messages
4. **Provide help** - Include usage information in scripts
5. **Be idempotent** - Scripts should be safe to run multiple times
6. **Use colors** - Make output readable with color-coded messages
7. **Confirm destructive actions** - Use `confirm_action()` for dangerous operations
