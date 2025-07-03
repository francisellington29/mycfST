#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - Entry Script

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import utils
source "$SCRIPT_DIR/scripts/utils.sh"

# Show banner
show_banner() {
    echo -e "${CYAN}"
    echo "=================================================="
    echo "  CloudflareSpeedTest DDNS v2.0"
    echo "  Modern DDNS automation tool"
    echo "=================================================="
    echo -e "${NC}"
}

# Detect environment
detect_environment() {
    if [[ -f "/.dockerenv" ]] || [[ -n "${container:-}" ]]; then
        echo "docker"
    else
        echo "terminal"
    fi
}

# Load config
load_config() {
    local config_file
    
    # 优先查找项目根目录的config.conf
    if [[ -f "$(dirname "$SCRIPT_DIR")/config.conf" ]]; then
        config_file="$(dirname "$SCRIPT_DIR")/config.conf"
    elif [[ -f "$SCRIPT_DIR/config.conf" ]]; then
        config_file="$SCRIPT_DIR/config.conf"
    elif [[ -f "./config.conf" ]]; then
        config_file="./config.conf"
    else
        log_warn "Configuration file not found, using defaults"
        return 0
    fi
    
    log_info "Loading configuration: $config_file"
    source "$config_file"
    log_info "Configuration loaded successfully"
}

# Initialize environment
init_environment() {
    local env_type="$1"
    
    log_info "Initializing environment: $env_type"
    
    # Set timezone
    if [[ -n "${SCHEDULE_TIMEZONE:-}" ]]; then
        export TZ="$SCHEDULE_TIMEZONE"
    fi
    
    # Create directories
    local base_dir
    if [[ "$env_type" == "docker" ]]; then
        base_dir="/app"
    else
        base_dir="$(pwd)"
    fi
    
    ensure_directory "$base_dir/logs"
    ensure_directory "$base_dir/CloudflareST"
}

# Setup cron
setup_cron() {
    local env_type="$1"
    
    if [[ "${SCHEDULE_ENABLED:-true}" != "true" ]]; then
        log_info "Cron disabled"
        return 0
    fi
    
    log_info "Setting up cron: ${SCHEDULE_CRON:-0 */6 * * *}"
    
    if [[ "$env_type" == "docker" ]]; then
        # 使用旧版本的方案：脚本自己处理环境变量继承，并设置定时任务标识
        echo "${SCHEDULE_CRON:-0 */6 * * *} cd /app && CRON_EXECUTION=true /app/scripts/speedtest.sh" > /tmp/crontab
        crontab /tmp/crontab 2>/dev/null || true
        crond -f -d 8 &
    else
        log_info "Please add to system crontab:"
        echo "${SCHEDULE_CRON:-0 */6 * * *} $SCRIPT_DIR/scripts/speedtest.sh"
    fi
}

# Run startup task
run_startup_task() {
    if [[ "${SCHEDULE_STARTUP_RUN:-true}" == "true" ]]; then
        "$SCRIPT_DIR/scripts/speedtest.sh"
    fi
}

# Docker main loop
docker_main_loop() {
    log_info "Docker mode: keeping container running"
    
    while true; do
        sleep 60
        if [[ "${SCHEDULE_ENABLED:-true}" == "true" ]] && ! pgrep crond >/dev/null 2>&1; then
            log_warn "crond process died, restarting"
            crond -f -d 8 &
        fi
    done
}

# Main function
main() {
    local env_type=$(detect_environment)
    
    init_logging >/dev/null 2>&1
    load_config >/dev/null 2>&1

    if ! bash "$SCRIPT_DIR/scripts/init.sh" >/dev/null 2>&1; then
        log_error "初始化失败"
        exit 1
    fi
    
    init_environment "$env_type" >/dev/null 2>&1
    run_startup_task
    setup_cron "$env_type" >/dev/null 2>&1
    
    if [[ "$env_type" == "docker" ]]; then
        docker_main_loop >/dev/null 2>&1
    fi
}

trap 'log_info "Received exit signal"; exit 0' SIGTERM SIGINT

main "$@"