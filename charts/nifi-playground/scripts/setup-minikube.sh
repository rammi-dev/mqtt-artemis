#!/bin/bash
set -e

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# Source libraries
source scripts/lib/minikube.sh

# Defaults
CPUS=4
MEMORY=8192
NODES=1
PROFILE="nifi-playground"

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --cpus <count>    Number of CPUs (default: $CPUS)"
    echo "  --memory <MB>     Memory in MB (default: $MEMORY)"
    echo "  --nodes <count>   Number of nodes (default: $NODES)"
    echo "  --profile <name>  Minikube profile name (default: $PROFILE)"
    echo "  --2nodes          Shortcut for 2 nodes"
    echo "  -h, --help        Show this help message"
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cpus)
                CPUS="$2"
                shift 2
                ;;
            --memory)
                MEMORY="$2"
                shift 2
                ;;
            --nodes)
                NODES="$2"
                shift 2
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --2nodes)
                NODES=2
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Main Execution
parse_args "$@"
start_minikube "$PROFILE" "$CPUS" "$MEMORY" "$NODES"
