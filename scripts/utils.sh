#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - 公共工具函数

# 导入常量定义
source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"

# 设置日志级别
set_log_level() {
    case "${1:-info}" in
        "debug") CURRENT_LOG_LEVEL=${LOG_DEBUG} ;;
        "info")  CURRENT_LOG_LEVEL=${LOG_INFO} ;;
        "warn")  CURRENT_LOG_LEVEL=${LOG_WARN} ;;
        "error") CURRENT_LOG_LEVEL=${LOG_ERROR} ;;
        *) CURRENT_LOG_LEVEL=${LOG_INFO} ;;
    esac
}

# 日志函数
log_message() {
    local level=$1
    local color=$2
    local prefix=$3
    local message=$4
    
    if [[ $level -lt $CURRENT_LOG_LEVEL ]]; then
        return 0
    fi
    
    # 一次性获取时间信息
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    local date_str=${datetime%% *}  # 提取日期部分
    
    echo -e "${color}[${datetime}] ${prefix}${NC} ${message}" >&2

    # Write to log file (use date-based naming)
    local log_file="logs/app-${date_str}.log"
    mkdir -p "logs" 2>/dev/null || true
    echo "[${datetime}] ${prefix} ${message}" >> "$log_file" 2>/dev/null || true
}

# 具体日志函数
log_debug() {
    log_message ${LOG_DEBUG} "${YELLOW}" "[DEBUG]" "$1"
}

log_info() {
    log_message ${LOG_INFO} "${GREEN}" "[INFO] " "$1"
}

log_warn() {
    log_message ${LOG_WARN} "${YELLOW}" "[WARN] " "$1"
}

log_error() {
    log_message ${LOG_ERROR} "${RED}" "[ERROR]" "$1"
}

# 简化的成功/失败日志函数
log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    local date_str=${datetime%% *}
    local log_file="logs/app-${date_str}.log"
    mkdir -p "logs" 2>/dev/null || true
    echo "[${datetime}] [SUCCESS] $1" >> "$log_file" 2>/dev/null || true
}

log_failure() {
    echo -e "${RED}❌ $1${NC}" >&2
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    local date_str=${datetime%% *}
    local log_file="logs/app-${date_str}.log"
    mkdir -p "logs" 2>/dev/null || true
    echo "[${datetime}] [FAILURE] $1" >> "$log_file" 2>/dev/null || true
}

# 文件操作函数
ensure_directory() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        log_error "ensure_directory: 目录路径不能为空"
        return 1
    fi
    
    if [[ ! -d "$dir" ]]; then
        if mkdir -p "$dir" 2>/dev/null; then
            log_debug "创建目录: $dir"
        else
            log_error "创建目录失败: $dir"
            return 1
        fi
    fi
    return 0
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 获取格式化时间（与日志时间格式一致）
get_formatted_time() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 检查网络连接
check_network() {
    local timeout=${1:-5}
    local test_url=${2:-"https://baidu.com"}
    
    if ! command_exists curl; then
        log_error "curl命令不存在，无法检查网络连接"
        return 1
    fi
    
    if curl -s --connect-timeout "$timeout" --max-time $((timeout + 2)) "$test_url" >/dev/null 2>&1; then
        return 0
    else
        log_debug "网络连接检查失败: $test_url"
        return 1
    fi
}

# Initialize logging system
init_logging() {
    ensure_directory "logs"

    local log_level="${SPEEDTEST_DEBUG:-false}"
    if [[ "$log_level" == "true" ]]; then
        set_log_level "debug"
    else
        set_log_level "info"
    fi

    log_info "Logging system initialized"
    
    # 清理旧日志文件（保留最多2天）
    cleanup_old_logs
}

# 清理旧日志文件（保留最多2天）
cleanup_old_logs() {
    local logs_dir="logs"
    
    if [[ ! -d "$logs_dir" ]]; then
        return 0
    fi
    
    # 查找并删除2天前的日志文件（按日期命名：*-YYYY-MM-DD.log）
    find "$logs_dir" -name "*-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].log" -type f -mtime +2 -exec rm -f {} \; 2>/dev/null || true
    
    # 清理空的日志文件
    find "$logs_dir" -name "*.log" -type f -size 0 -exec rm -f {} \; 2>/dev/null || true
    
    log_debug "Old log files cleanup completed"
}

