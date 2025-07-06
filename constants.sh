#!/bin/bash

# 防止重复加载
if [[ -n "$CONSTANTS_LOADED" ]]; then
    return 0
fi
readonly CONSTANTS_LOADED=1

# CloudflareSpeedTest 项目常量定义文件
# 只包含真正的常量，不包含可配置的参数

# ============= 版本信息 =============
readonly CLOUDFLARE_ST_VERSION="v2.3.0"
readonly CLOUDFLARE_ST_REPO="XIU2/CloudflareSpeedTest"
readonly QQWRY_REPO="metowolf/qqwry.dat"

# ============= 下载地址 =============
readonly CLOUDFLARE_ST_RELEASE_BASE="https://github.com/${CLOUDFLARE_ST_REPO}/releases/download"
readonly QQWRY_DOWNLOAD_URL_BASE="https://github.com/${QQWRY_REPO}/releases/latest/download/qqwry.dat"

# ============= 文件路径 =============
readonly APP_DIR="/app"
readonly CLOUDFLARE_ST_DIR="${APP_DIR}/CloudflareST"
readonly CLOUDFLARE_ST_BINARY="${CLOUDFLARE_ST_DIR}/CloudflareST"
readonly QQWRY_DATABASE="${CLOUDFLARE_ST_DIR}/qqwry.dat"
readonly IPV4_DATA_FILE="${CLOUDFLARE_ST_DIR}/ip.txt"
readonly IPV6_DATA_FILE="${CLOUDFLARE_ST_DIR}/ipv6.txt"
readonly RESULT_FILE="${CLOUDFLARE_ST_DIR}/result.csv"
readonly CRON_LOG_FILE="${APP_DIR}/cron.log"

# ============= 颜色常量 =============
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'

# ============= Emoji 常量 =============
readonly EMOJI_ROCKET="🚀"
readonly EMOJI_GLOBE="🌐"
readonly EMOJI_KEY="🔑"
readonly EMOJI_ROBOT="🤖"
readonly EMOJI_CHAT="💬"
readonly EMOJI_LINK="🔗"
readonly EMOJI_CALENDAR="📅"
readonly EMOJI_GEAR="🔧"
readonly EMOJI_TIMER="⏱️"
readonly EMOJI_CHART="📈"
readonly EMOJI_FOLDER="📁"
readonly EMOJI_FILE="📊"
readonly EMOJI_WORLD="🌍"
readonly EMOJI_BUILDING="🏗️"
readonly EMOJI_DOCKER="🐳"
readonly EMOJI_CLOCK="🕐"
readonly EMOJI_DOWNLOAD="⬇️"
readonly EMOJI_UPLOAD="⬆️"
readonly EMOJI_SPEED="🚄"
readonly EMOJI_TARGET="🎯"
readonly EMOJI_SHIELD="🛡️"
readonly EMOJI_BELL="🔔"
readonly EMOJI_SUCCESS="✅"
readonly EMOJI_WARNING="⚠️"
readonly EMOJI_ERROR="❌"
readonly EMOJI_INFO="ℹ️"
readonly EMOJI_DEBUG="🐛"
readonly EMOJI_NETWORK="🌐"
readonly EMOJI_SERVER="🖥️"
readonly EMOJI_DATABASE="🗄️"
readonly EMOJI_LOCATION="📍"
readonly EMOJI_PORT="🚪"
readonly EMOJI_TIME="⏰"

# ============= API 地址 =============
readonly CLOUDFLARE_API_BASE="https://api.cloudflare.com/client/v4"
readonly TELEGRAM_API_BASE="https://api.telegram.org"

# ============= 架构映射 =============
declare -A ARCH_MAP=(
    ["x86_64"]="amd64"
    ["aarch64"]="arm64"
    ["armv7l"]="armv7"
    ["i386"]="386"
)



# ============= 文件大小限制 =============
readonly MIN_QQWRY_SIZE=1000000  # qqwry.dat 最小文件大小 (1MB)

# ============= 退出码 =============
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_DOWNLOAD_ERROR=2
readonly EXIT_CONFIG_ERROR=3
readonly EXIT_SPEEDTEST_ERROR=4
readonly EXIT_DNS_ERROR=5
readonly EXIT_NOTIFICATION_ERROR=6

# ============= 通用函数 =============

# 获取架构对应的下载标识
get_arch_identifier() {
    local arch=$(uname -m)
    echo "${ARCH_MAP[$arch]:-unknown}"
}

# 检查架构是否支持
is_arch_supported() {
    local arch=$(uname -m)
    [[ -n "${ARCH_MAP[$arch]}" ]]
}

# 构建下载URL
build_download_url() {
    local version="${1:-$CLOUDFLARE_ST_VERSION}"
    local arch_id=$(get_arch_identifier)

    if [[ "$arch_id" == "unknown" ]]; then
        return 1
    fi

    echo "${CLOUDFLARE_ST_RELEASE_BASE}/${version}/CloudflareST_linux_${arch_id}.tar.gz"
}

# 应用GitHub代理
apply_github_proxy() {
    local url="$1"
    local proxy_url="$2"

    if [[ -n "$proxy_url" ]]; then
        echo "${proxy_url}/${url}"
    else
        echo "$url"
    fi
}

# 日志输出
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "DEBUG") echo "[$timestamp] [DEBUG] $message" ;;
        "INFO")  echo "[$timestamp] [INFO]  $message" ;;
        "WARN")  echo "[$timestamp] [WARN]  $message" ;;
        "ERROR") echo "[$timestamp] [ERROR] $message" >&2 ;;
        *)       echo "[$timestamp] $message" ;;
    esac
}

# 检查必需的环境变量
check_required_env() {
    local required_vars=("$@")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_message "ERROR" "缺少必需的环境变量: ${missing_vars[*]}"
        return 1
    fi

    return 0
}

# 验证文件存在且不为空
validate_file() {
    local file_path="$1"
    local min_size="${2:-1}"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    [[ "$file_size" -ge "$min_size" ]]
}

# 创建目录
ensure_directory() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
    fi
}

# 清理临时文件
cleanup_temp_files() {
    local temp_files=("$@")
    for file in "${temp_files[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
        fi
    done
}

# 导出函数
export -f log_message
export -f check_required_env
export -f validate_file
export -f ensure_directory
export -f cleanup_temp_files
export -f get_arch_identifier
export -f is_arch_supported
export -f build_download_url
export -f apply_github_proxy
