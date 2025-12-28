# Shell Completions

Bash completion scripts for deployment commands.

## Quick Setup

```bash
# Add to your ~/.bashrc
echo "source /home/rami/Work/artemis/scripts/completion/deploy-gke-completion.sh" >> ~/.bashrc

# Reload
source ~/.bashrc
```

## Usage

After setup, you can use Tab completion:

```bash
./scripts/deploy-gke.sh <TAB>
# Shows: all cluster terraform kubeconfig infrastructure cert-manager ...

./scripts/deploy-gke.sh clu<TAB>
# Completes to: cluster

# Or use the alias
deploy <TAB>
# Shows all commands
```

## Available Completions

### deploy-gke.sh

**All commands:**
- `all` - Deploy everything
- `cluster` - Create GKE cluster
- `terraform` - Create GKE cluster (alias)
- `kubeconfig` - Configure kubectl
- `infrastructure` - Deploy infrastructure
- `cert-manager` - Deploy cert-manager
- `ingress-nginx` - Deploy ingress-nginx
- `analytics` - Deploy analytics
- `artemis` - Deploy Artemis MQTT
- `clickhouse` - Deploy ClickHouse
- `nifi` - Deploy Apache NiFi
- `redis` - Deploy Redis
- `dagster` - Deploy Dagster
- `prometheus` - Deploy Prometheus
- `grafana` - Deploy Grafana
- `dashboard-api` - Deploy Dashboard API
- `verify` - Verify deployment
- `destroy` - Destroy everything
- `cleanup-disks` - Clean up orphaned disks
- `help` - Show help

## Alias

The completion script also creates a convenient alias:

```bash
deploy cluster      # Instead of ./scripts/deploy-gke.sh cluster
deploy analytics    # Instead of ./scripts/deploy-gke.sh analytics
deploy verify       # Instead of ./scripts/deploy-gke.sh verify
```

## Manual Installation

If you don't want to modify ~/.bashrc, you can source it manually in each session:

```bash
source scripts/completion/deploy-gke-completion.sh
```

## Testing

```bash
# Source the completion
source scripts/completion/deploy-gke-completion.sh

# Test it
./scripts/deploy-gke.sh <TAB><TAB>
# Should show all available commands

# Test partial completion
./scripts/deploy-gke.sh ana<TAB>
# Should complete to: analytics

# Test alias
deploy clu<TAB>
# Should complete to: cluster
```

## Troubleshooting

**Completion not working?**

1. Make sure bash-completion is installed:
   ```bash
   sudo apt-get install bash-completion  # Ubuntu/Debian
   ```

2. Check if completion is sourced:
   ```bash
   type _deploy_gke_completion
   # Should show: _deploy_gke_completion is a function
   ```

3. Reload bash:
   ```bash
   source ~/.bashrc
   ```

**Still not working?**

Make sure you're using bash (not zsh or other shells):
```bash
echo $SHELL
# Should show: /bin/bash
```

For zsh, you'll need a different completion format.
