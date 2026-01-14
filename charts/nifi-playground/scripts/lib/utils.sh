#!/bin/bash

# Colors for output
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

ensure_driver() {
    local DRIVER_URL="https://jdbc.postgresql.org/download/postgresql-42.6.0.jar"
    local DEST="lib/postgresql-jdbc.jar"
    
    if [ ! -f "$DEST" ]; then
        log_info "Downloading Postgres JDBC driver..."
        curl -L -o "$DEST" "$DRIVER_URL"
    else
        log_info "Postgres JDBC driver found locally."
    fi
}
