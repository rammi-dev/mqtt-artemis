#!/bin/bash
# =============================================================================
# Bash Completion for deploy-gke.sh
# =============================================================================
# Installation:
#   source scripts/completion/deploy-gke-completion.sh
#
# Or add to ~/.bashrc:
#   source /home/rami/Work/artemis/scripts/completion/deploy-gke-completion.sh
# =============================================================================

_deploy_gke_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All available commands
    opts="all cluster terraform kubeconfig infrastructure cert-manager ingress-nginx analytics artemis clickhouse nifi redis dagster prometheus grafana dashboard-api verify destroy cleanup-disks help"

    # Generate completions
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

# Register completion for deploy-gke.sh
complete -F _deploy_gke_completion deploy-gke.sh
complete -F _deploy_gke_completion ./scripts/deploy-gke.sh
complete -F _deploy_gke_completion ./deploy-gke.sh

# Also create an alias for convenience
alias deploy='./scripts/deploy-gke.sh'
complete -F _deploy_gke_completion deploy
