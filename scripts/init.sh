#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - System Initialization Script

# Import utils and constants
source "$(dirname "$0")/utils.sh"

# Detect Linux architecture
detect_architecture() {
    local arch=$(uname -m)
    log_debug "Detected architecture: $arch"
    
    case "$arch" in
        "x86_64"|"amd64")
            echo "amd64"
            ;;
        "aarch64"|"arm64")
            echo "arm64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            log_error "Only x86_64 and aarch64 are supported"
            return 1
            ;;
    esac
}

# Check required commands
check_required_commands() {
    log_info "Checking system dependencies..."
    
    local missing_packages=""
    local required_commands=("bash" "curl" "jq" "tar" "wget")
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_warn "$cmd not installed"
            missing_packages="$missing_packages $cmd"
        fi
    done
    
    if [[ -n "$missing_packages" ]]; then
        install_packages "$missing_packages"
    else
        log_info "All dependencies satisfied"
    fi
}

# Install missing packages
install_packages() {
    local packages="$1"
    log_info "Need to install: $packages"
    
    if command_exists apk; then
        log_info "Using apk to install dependencies..."
        apk update && apk add $packages
    elif command_exists apt-get; then
        log_info "Using apt to install dependencies..."
        apt-get update && apt-get install -y $packages
    elif command_exists yum; then
        log_info "Using yum to install dependencies..."
        yum install -y $packages
    else
        log_error "Cannot identify package manager"
        log_error "Please manually install: $packages"
        return 1
    fi
}

# Download CloudflareSpeedTest v2.3.0
download_cloudflare_speedtest() {
    local arch="$1"
    
    log_info "Downloading CloudflareSpeedTest $CLOUDFLARE_ST_VERSION ($arch)..."
    
    ensure_directory "./CloudflareST"
    local temp_dir="./CloudflareST/temp"
    ensure_directory "$temp_dir"
    
    local filename="CloudflareST_linux_${arch}.tar.gz"
    local base_url="https://github.com/XIU2/CloudflareSpeedTest/releases/download/$CLOUDFLARE_ST_VERSION/$filename"
    
    local download_success=false
    # 构建下载URL，支持代理
    local final_url="$base_url"
    if [[ -n "$GITHUB_PROXY" ]]; then
        # 移除GITHUB_PROXY末尾的斜杠（如果有）
        local proxy_url="${GITHUB_PROXY%/}"
        final_url="${proxy_url}/${base_url}"
        log_info "使用GitHub代理下载: $final_url"
    else
        log_info "直接下载: $final_url"
    fi
    
    # 下载文件
    if command_exists wget; then
        if wget -O "$temp_dir/$filename" "$final_url"; then
            download_success=true
        fi
    elif command_exists curl; then
        if curl -L -o "$temp_dir/$filename" "$final_url"; then
            download_success=true
        fi
    fi
    
    if [[ "$download_success" != "true" ]]; then
        log_error "Download failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Extracting files..."
    if tar -xzf "$temp_dir/$filename" -C "$temp_dir/"; then
        mv "$temp_dir/CloudflareST" "./CloudflareST/"
        mv "$temp_dir/ip.txt" "./CloudflareST/" 2>/dev/null || true
        mv "$temp_dir/ipv6.txt" "./CloudflareST/" 2>/dev/null || true
        
        chmod +x "./CloudflareST/CloudflareST"
        rm -rf "$temp_dir"
        
        log_info "CloudflareSpeedTest v2.3.0 installation completed"
        return 0
    else
        log_error "Extraction failed"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Check CloudflareSpeedTest
check_cloudflare_speedtest() {
    if [[ -f "$CLOUDFLARE_ST_PATH" && -x "$CLOUDFLARE_ST_PATH" ]]; then
        log_info "CloudflareSpeedTest already exists"
        return 0
    fi
    
    log_info "CloudflareSpeedTest not found, downloading v2.3.0..."
    
    local arch
    if ! arch=$(detect_architecture); then
        return 1
    fi
    
    if download_cloudflare_speedtest "$arch"; then
        log_info "CloudflareSpeedTest download successful"
        return 0
    else
        log_error "CloudflareSpeedTest download failed"
        log_error "Please manually download v2.3.0 and extract to ./CloudflareST/ directory"
        return 1
    fi
}

# Main initialization function
init_system() {
    log_info "Starting system initialization..."
    
    if [[ -f "$INIT_FLAG_FILE" ]]; then
        log_info "Dependencies already checked, skipping"
    else
        if ! check_required_commands; then
            log_error "Dependency check failed"
            return 1
        fi
        
        touch "$INIT_FLAG_FILE"
        log_info "Dependency check completed"
    fi
    
    if ! check_cloudflare_speedtest; then
        log_error "CloudflareSpeedTest check failed"
        return 1
    fi
    
    log_info "System initialization completed"
    return 0
}

# If script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Note: init_logging should be called by parent script
    init_system
fi
