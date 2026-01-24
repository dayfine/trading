#!/bin/bash
#
# Development environment setup script for trading-1
#
# This script builds and starts a Docker container for OCaml development.
# It can be used instead of VS Code's Dev Containers extension.
#
# Usage:
#   .devcontainer/setup.sh [command]
#
# Commands:
#   build    Build the Docker image (default if no container exists)
#   start    Start the development container
#   shell    Open a shell in the running container
#   test     Run all tests in the container
#   stop     Stop the development container
#   rebuild  Force rebuild the Docker image
#
# Examples:
#   .devcontainer/setup.sh build   # Build the Docker image
#   .devcontainer/setup.sh start   # Start container in background
#   .devcontainer/setup.sh shell   # Open interactive shell
#   .devcontainer/setup.sh test    # Run tests
#

set -e

# Configuration
IMAGE_NAME="trading-1-dev"
CONTAINER_NAME="trading-1-dev"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="/workspaces/trading-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
}

# Check if image exists
image_exists() {
    docker image inspect "$IMAGE_NAME" &> /dev/null
}

# Check if container exists
container_exists() {
    docker container inspect "$CONTAINER_NAME" &> /dev/null
}

# Check if container is running
container_running() {
    [ "$(docker container inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" = "true" ]
}

# Build the Docker image
do_build() {
    log_info "Building Docker image '$IMAGE_NAME'..."
    docker build -t "$IMAGE_NAME" -f "$PROJECT_ROOT/.devcontainer/Dockerfile" "$PROJECT_ROOT"
    log_info "Docker image built successfully."
}

# Start the container
do_start() {
    if container_running; then
        log_info "Container '$CONTAINER_NAME' is already running."
        return
    fi

    if ! image_exists; then
        log_warn "Image not found. Building first..."
        do_build
    fi

    if container_exists; then
        log_info "Starting existing container '$CONTAINER_NAME'..."
        docker start "$CONTAINER_NAME"
    else
        log_info "Creating and starting container '$CONTAINER_NAME'..."
        docker run -d \
            --name "$CONTAINER_NAME" \
            -v "$PROJECT_ROOT:$WORKDIR" \
            -w "$WORKDIR/trading" \
            "$IMAGE_NAME" \
            tail -f /dev/null
    fi

    log_info "Container started. Use '.devcontainer/setup.sh shell' to open a shell."
}

# Open a shell in the container
do_shell() {
    if ! container_running; then
        log_warn "Container not running. Starting..."
        do_start
    fi

    log_info "Opening shell in container..."
    docker exec -it "$CONTAINER_NAME" bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && exec bash'
}

# Run tests
do_test() {
    if ! container_running; then
        log_warn "Container not running. Starting..."
        do_start
    fi

    log_info "Running tests..."
    docker exec "$CONTAINER_NAME" bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune runtest'
    log_info "Tests completed."
}

# Run a command in the container
do_exec() {
    if ! container_running; then
        log_warn "Container not running. Starting..."
        do_start
    fi

    docker exec "$CONTAINER_NAME" bash -c "cd /workspaces/trading-1/trading && eval \$(opam env) && $*"
}

# Stop the container
do_stop() {
    if container_running; then
        log_info "Stopping container '$CONTAINER_NAME'..."
        docker stop "$CONTAINER_NAME"
        log_info "Container stopped."
    else
        log_info "Container is not running."
    fi
}

# Force rebuild
do_rebuild() {
    log_info "Force rebuilding Docker image..."
    docker build --no-cache -t "$IMAGE_NAME" -f "$PROJECT_ROOT/.devcontainer/Dockerfile" "$PROJECT_ROOT"

    if container_exists; then
        log_info "Removing old container..."
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi

    log_info "Rebuild complete. Use '.devcontainer/setup.sh start' to start."
}

# Show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build    Build the Docker image"
    echo "  start    Start the development container"
    echo "  shell    Open a shell in the running container"
    echo "  test     Run all tests in the container"
    echo "  stop     Stop the development container"
    echo "  rebuild  Force rebuild the Docker image (no cache)"
    echo "  exec     Run a command in the container"
    echo ""
    echo "Examples:"
    echo "  $0 build        # Build the Docker image"
    echo "  $0 start        # Start container in background"
    echo "  $0 shell        # Open interactive shell"
    echo "  $0 test         # Run tests"
    echo "  $0 exec dune fmt  # Run dune fmt in container"
}

# Main
check_docker

case "${1:-}" in
    build)
        do_build
        ;;
    start)
        do_start
        ;;
    shell)
        do_shell
        ;;
    test)
        do_test
        ;;
    stop)
        do_stop
        ;;
    rebuild)
        do_rebuild
        ;;
    exec)
        shift
        do_exec "$@"
        ;;
    help|--help|-h)
        show_usage
        ;;
    "")
        # Default: show status and help
        echo "Trading-1 Development Environment Setup"
        echo "========================================"
        echo ""
        if image_exists; then
            echo "Docker image: $IMAGE_NAME (exists)"
        else
            echo "Docker image: $IMAGE_NAME (not built)"
        fi
        if container_exists; then
            if container_running; then
                echo "Container: $CONTAINER_NAME (running)"
            else
                echo "Container: $CONTAINER_NAME (stopped)"
            fi
        else
            echo "Container: $CONTAINER_NAME (not created)"
        fi
        echo ""
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
