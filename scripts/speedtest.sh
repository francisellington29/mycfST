#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - Speedtest Main Script

set -e

# 从容器主进程继承环境变量（用于cron任务）
if [ -f /proc/1/environ ]; then
    while IFS= read -r -d '' env_var; do
        if [[ "$env_var" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            export "$env_var"
        fi
    done < /proc/1/environ
fi

# Script directory（从constants.sh继承SCRIPT_DIR和PROJECT_DIR）

# Import utils
source "$(dirname "$0")/utils.sh"

# Load configuration
load_config() {
    local config_paths=(
        "$(dirname "$(dirname "$0")")/config.conf"  # 项目根目录
        "$(dirname "$0")/config.conf"               # scripts目录
        "./config.conf"                             # 当前目录
    )
    
    for config_file in "${config_paths[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_debug "Loading configuration: $config_file"
            if source "$config_file" 2>/dev/null; then
                log_debug "Configuration loaded successfully"
                return 0
            else
                log_error "Failed to load configuration: $config_file"
                return 1
            fi
        fi
    done
    
    log_warn "Configuration file not found, using defaults"
    return 0
}

# Load config at startup
load_config

# Script start time
START_TIME=$(date +%s)

# Check CloudflareST files
check_cloudflare_st() {
    local cloudflare_st_dir="./CloudflareST"
    local ip_file="$cloudflare_st_dir/ip.txt"

    # Check if CloudflareST binary exists
    if [[ ! -f "$cloudflare_st_dir/CloudflareST" ]]; then
        log_error "CloudflareST binary not found at: $cloudflare_st_dir/CloudflareST"
        return 1
    fi

    # Check if ip.txt exists (should be extracted from archive)
    if [[ ! -f "$ip_file" ]]; then
        log_error "ip.txt not found at: $ip_file"
        log_error "This file should be extracted from CloudflareST archive"
        return 1
    fi

    return 0
}

# Build CloudflareSpeedTest command
build_speedtest_command() {
    local cloudflare_st_path="./CloudflareST/CloudflareST"

    if [[ ! -f "$cloudflare_st_path" ]]; then
        log_error "CloudflareST not found at: $cloudflare_st_path"
        return 1
    fi

    # CloudflareST must be executed from its own directory to find ip.txt
    # Build command with relative paths from CloudflareST directory
    local cmd="./CloudflareST"

    # Speedtest parameters
    # 测速连接URL（必须指定，否则速度测试结果为0）
    if [[ -n "${SPEEDTEST_URL:-}" ]]; then
        cmd+=" -url ${SPEEDTEST_URL}"
    else
        log_error "SPEEDTEST_URL测速链接未设置，无法进行速度测试"
        return 1
    fi
    cmd+=" ${SPEEDTEST_MODE:-tcping}"
    cmd+=" -n ${SPEEDTEST_THREADS:-200}"
    cmd+=" -t ${SPEEDTEST_COUNT:-4}"
    cmd+=" -dt ${SPEEDTEST_TIMEOUT:-10}"

    # Filter conditions
    cmd+=" -tll ${SPEEDTEST_LATENCY_MIN:-0}"
    cmd+=" -tl ${SPEEDTEST_LATENCY_MAX:-200}"
    cmd+=" -tlr ${SPEEDTEST_LOSS_MAX:-0.1}"
    cmd+=" -sl ${SPEEDTEST_SPEED_MIN:-5}"

    # Region selection
    if [[ -n "${SPEEDTEST_REGIONS:-}" ]]; then
        cmd+=" -cfcolo ${SPEEDTEST_REGIONS}"
    fi

    # Result count
    cmd+=" -dn ${SPEEDTEST_RESULT_COUNT:-10}"

    # IP file path (relative to CloudflareST directory)
    cmd+=" -f ip.txt"

    # Output file (relative to CloudflareST directory)
    cmd+=" -o result.csv"

    # Debug mode
    if [[ "${SPEEDTEST_DEBUG:-false}" == "true" ]]; then
        cmd+=" -debug"
    fi

    echo "$cmd"
}

# Run speedtest
run_speedtest() {
    local cmd
    if ! cmd=$(build_speedtest_command); then
        log_error "构建测速命令失败"
        return 1
    fi

    # Change to CloudflareST directory to execute the command
    local original_dir=$(pwd)

    if cd CloudflareST; then
        # 直接执行，让CloudflareSpeedTest的原始输出显示
        if eval "$cmd"; then
            cd "$original_dir"
            return 0
        else
            local exit_code=$?
            log_error "测速失败，退出码: $exit_code"
            cd "$original_dir"
            return 1
        fi
    else
        log_error "无法进入CloudflareST目录"
        return 1
    fi
}

# Parse speedtest results
parse_speedtest_results() {
    local result_file="CloudflareST/result.csv"

    if [[ ! -f "$result_file" ]]; then
        log_error "Result file not found: $result_file"
        return 1
    fi
    
    local line_count=$(wc -l < "$result_file")
    if [[ "$line_count" -le 1 ]]; then
        log_error "No valid IPs found in results"
        return 1
    fi
    
    log_info "Speedtest results:"
    log_info "Found $((line_count - 1)) valid IPs"
    
    log_info "Top 5 IPs:"
    head -6 "$result_file" | tail -5 | while IFS=',' read -r ip sent recv loss time speed region; do
        log_info "  $ip - Latency:${time}ms Speed:${speed}MB/s Region:${region:-N/A}"
    done
    
    return 0
}

# Check network connectivity
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    if ! check_network; then
        log_error "Network connectivity check failed"
        return 1
    fi
    
    log_info "Network connectivity OK"
    return 0
}

# Download qqwry.dat for IP location
download_qqwry_dat() {
    log_info "下载IP地理位置数据库..."
    
    local qqwry_file="CloudflareST/qqwry.dat"
    local download_url="https://github.com/metowolf/qqwry.dat/releases/latest/download/qqwry.dat"
    
    # 构建下载URL，支持代理
    local final_url="$download_url"
    if [[ -n "$GITHUB_PROXY" ]]; then
        local proxy_url="${GITHUB_PROXY%/}"
        final_url="${proxy_url}/${download_url}"
        log_debug "使用GitHub代理下载qqwry.dat: $final_url"
    else
        log_debug "直接下载qqwry.dat: $final_url"
    fi
    
    # 下载文件
    if command_exists wget; then
        if wget -O "$qqwry_file" "$final_url"; then
            log_info "qqwry.dat下载成功"
            return 0
        fi
    elif command_exists curl; then
        if curl -L -o "$qqwry_file" "$final_url"; then
            log_info "qqwry.dat下载成功"
            return 0
        fi
    fi
    
    log_warn "qqwry.dat下载失败，将使用默认地理位置信息"
    return 1
}

# Clean old results (simplified - no backup needed with MCP tools)
clean_old_results() {
    local result_file="CloudflareST/result.csv"

    if [[ -f "$result_file" ]]; then
        rm -f "$result_file"
        log_debug "Removed old result file: $result_file"
    fi
}

# Calculate next cron execution time
get_next_cron_time() {
    local cron_expr="$1"
    
    # 解析cron表达式的分钟部分
    local minute_part=$(echo "$cron_expr" | cut -d' ' -f1)
    local current_minute=$(date +%M)
    local current_hour=$(date +%H)
    
    # 处理不同的分钟表达式
    if [[ "$minute_part" == "*/15" ]]; then
        # 每15分钟执行一次
        local next_minute=$(( (current_minute / 15 + 1) * 15 ))
        if [[ $next_minute -ge 60 ]]; then
            next_minute=0
            date -d "+1 hour" +"%Y-%m-%d %H:$(printf "%02d" $next_minute):00"
        else
            date +"%Y-%m-%d %H:$(printf "%02d" $next_minute):00"
        fi
    elif [[ "$minute_part" == "0" ]]; then
        # 每小时的0分执行
        if [[ $current_minute -eq 0 ]]; then
            date -d "+1 hour" +"%Y-%m-%d %H:00:00"
        else
            date -d "+1 hour" +"%Y-%m-%d %H:00:00"
        fi
    elif [[ "$minute_part" =~ ^[0-9]+$ ]]; then
        # 固定分钟数
        local target_minute=$minute_part
        if [[ $current_minute -lt $target_minute ]]; then
            date +"%Y-%m-%d %H:$(printf "%02d" $target_minute):00"
        else
            date -d "+1 hour" +"%Y-%m-%d %H:$(printf "%02d" $target_minute):00"
        fi
    else
        echo "$(date -d "+15 minutes" +"%Y-%m-%d %H:%M:00")"
    fi
}

# Detect execution type
detect_execution_type() {
    # 检查是否由cron执行（通过环境变量或进程信息）
    if [[ "${CRON_EXECUTION:-}" == "true" ]] || [[ "$(ps -o comm= -p $PPID 2>/dev/null)" == "crond" ]]; then
        echo "⏰ 定时任务执行"
    else
        echo "🖱️ 手动执行"
    fi
}

# Display configuration summary
show_config_summary() {
    echo "📋 配置信息:"
    echo "  域名: ${DDNS_DOMAIN:-未配置}"
    echo "  IP数量: ${DDNS_IP_COUNT:-5}"
    echo "  测速模式: ${SPEEDTEST_MODE:-tcping}"
    echo "  测速线程: ${SPEEDTEST_THREADS:-200}"
    echo "  测速次数: ${SPEEDTEST_COUNT:-4}"
    echo "  测速超时: ${SPEEDTEST_TIMEOUT:-10}秒"
    echo "  延迟范围: ${SPEEDTEST_LATENCY_MIN:-0}-${SPEEDTEST_LATENCY_MAX:-200}ms"
    echo "  速度阈值: >${SPEEDTEST_SPEED_MIN:-5}MB/s"
    echo "  丢包阈值: <${SPEEDTEST_LOSS_MAX:-0.1}"
    echo "  结果数量: ${SPEEDTEST_RESULT_COUNT:-10}"
    echo "  测速URL: ${SPEEDTEST_URL:-未配置}"
    if [[ -n "${SPEEDTEST_REGIONS:-}" ]]; then
        echo "  指定地区: ${SPEEDTEST_REGIONS}"
    fi
    echo "  定时任务: ${SCHEDULE_CRON:-*/15 * * * *}"
    echo "  时区: ${SCHEDULE_TIMEZONE:-Asia/Shanghai}"
    
    # 计算下次执行时间
    local next_run=$(get_next_cron_time "${SCHEDULE_CRON:-*/15 * * * *}")
    if [[ -n "$next_run" ]]; then
        echo "  下次执行: $next_run"
    fi
    
    # 通知配置
    echo ""
    echo "📢 通知配置:"
    if [[ "${NOTIFICATION_TELEGRAM_ENABLED:-false}" == "true" ]]; then
        echo "  Telegram: 已启用"
        if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
            echo "    Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
        fi
        if [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
            echo "    Chat ID: ${TELEGRAM_CHAT_ID}"
        fi
        if [[ -n "${TELEGRAM_PROXY_URL:-}" ]]; then
            echo "    代理: ${TELEGRAM_PROXY_URL}"
        fi
    else
        echo "  Telegram: 未启用"
    fi
    
    if [[ "${NOTIFICATION_EMAIL_ENABLED:-false}" == "true" ]]; then
        echo "  Email: 已启用"
    else
        echo "  Email: 未启用"
    fi
    
    if [[ "${NOTIFICATION_WEBHOOK_ENABLED:-false}" == "true" ]]; then
        echo "  Webhook: 已启用"
    else
        echo "  Webhook: 未启用"
    fi
    echo ""
}

# Display speedtest results summary
show_speedtest_summary() {
    local result_file="CloudflareST/result.csv"
    
    if [[ ! -f "$result_file" ]]; then
        echo "❌ 测速结果文件不存在"
        return 1
    fi
    
    local line_count=$(wc -l < "$result_file")
    local valid_count=$((line_count - 1))
    
    if [[ $valid_count -le 0 ]]; then
        echo "❌ 测速失败: 未找到可用IP"
        return 1
    fi
    
    echo "📊 测速结果:"
    while IFS=',' read -r ip sent recv loss latency speed region; do
        echo "  $ip - ${latency}ms - ${speed}MB/s - 丢包${loss}% - ${region:-N/A}"
    done < <(tail -n +2 "$result_file")
    echo ""
}

# Main function
main() {
    local execution_type=$(detect_execution_type)
    echo "$(get_formatted_time) 开始CloudflareSpeedTest DDNS ($execution_type)"
    echo ""
    
    if [[ "${SPEEDTEST_ENABLED:-true}" != "true" ]]; then
        echo "测速已禁用，跳过执行"
        exit 0
    fi
    
    # 显示配置信息
    show_config_summary
    
    # 1. 环境检查
    echo "🔍 1. 环境检查"
    if ! check_network >/dev/null 2>&1; then
        echo "  ❌ 网络连接检查失败"
        exit 1
    fi
    echo "  ✅ 网络连接正常"

    if ! check_cloudflare_st >/dev/null 2>&1; then
        echo "  ❌ CloudflareST文件检查失败"
        exit 1
    fi
    echo "  ✅ CloudflareST文件检查通过"
    echo ""

    # 2. 准备工作
    echo "🛠️ 2. 准备工作"
    if [[ "${QQWRY_INIT:-true}" == "true" ]] || [[ ! -f "CloudflareST/qqwry.dat" ]]; then
        echo "  📥 下载IP地理位置数据库..."
        if download_qqwry_dat >/dev/null 2>&1; then
            echo "  ✅ qqwry.dat下载成功"
        else
            echo "  ⚠️ qqwry.dat下载失败，使用默认地理位置"
        fi
    else
        echo "  ✅ IP地理位置数据库已存在"
    fi

    clean_old_results >/dev/null 2>&1
    echo "  ✅ 清理旧结果文件"
    echo ""

    # 3. 执行测速
    echo "⚡ 3. 执行测速"
    if ! run_speedtest; then
        echo "  ❌ 测速执行失败"
        exit 1
    fi
    echo ""

    # 4. 显示测速结果
    echo "📈 4. 测速结果"
    if ! show_speedtest_summary; then
        echo "  ❌ 结果解析失败"
        exit 1
    fi
    
    # 5. DDNS更新
    echo "🌐 5. DNS更新"
    local ddns_result="unknown"
    if [[ "${DDNS_DOMAIN:-}" != "" ]]; then
        echo "  🔄 开始更新DNS记录: ${DDNS_DOMAIN}"
        if bash "$(dirname "$0")/ddns-update.sh"; then
            ddns_result="success"
            echo "  ✅ DNS更新完成"
            
            # 显示详细的DNS操作统计
            if [[ -n "${DNS_CREATE_SUCCESS:-}" ]] || [[ -n "${DNS_CREATE_FAIL:-}" ]] || [[ -n "${DNS_DELETE_SUCCESS:-}" ]] || [[ -n "${DNS_DELETE_FAIL:-}" ]] || [[ -n "${DNS_SKIPPED:-}" ]]; then
                echo "  📊 DNS操作汇总:"
                if [[ "${DNS_CREATE_SUCCESS:-0}" -gt 0 ]]; then
                    echo "    ✅ ${DNS_CREATE_SUCCESS} 个创建成功"
                fi
                if [[ "${DNS_CREATE_FAIL:-0}" -gt 0 ]]; then
                    echo "    ❌ ${DNS_CREATE_FAIL} 个创建失败"
                fi
                if [[ "${DNS_DELETE_SUCCESS:-0}" -gt 0 ]]; then
                    echo "    🗑️ ${DNS_DELETE_SUCCESS} 个删除成功"
                fi
                if [[ "${DNS_DELETE_FAIL:-0}" -gt 0 ]]; then
                    echo "    ❌ ${DNS_DELETE_FAIL} 个删除失败"
                fi
                if [[ "${DNS_SKIPPED:-0}" -gt 0 ]]; then
                    echo "    ⏭️ ${DNS_SKIPPED} 个跳过"
                fi
                local total_operations=$((${DNS_CREATE_SUCCESS:-0} + ${DNS_CREATE_FAIL:-0} + ${DNS_DELETE_SUCCESS:-0} + ${DNS_DELETE_FAIL:-0} + ${DNS_SKIPPED:-0}))
                if [[ $total_operations -eq 0 ]]; then
                    echo "    ℹ️ 无操作"
                fi
            else
                echo "    ℹ️ 无操作"
            fi
        else
            ddns_result="failed"
            echo "  ❌ DNS更新失败"
        fi
    else
        echo "  ⏭️ 跳过DNS更新 (未配置域名)"
        ddns_result="no_change"
    fi
    echo ""
    
    # 6. 发送通知
    echo "📢 6. 发送通知"
    if bash "$(dirname "$0")/notification.sh" "$ddns_result" >/dev/null 2>&1; then
        echo "  ✅ 通知发送成功"
    else
        echo "  ❌ 通知发送失败"
    fi
    echo ""
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo "$(get_formatted_time) 完成，总耗时 ${duration} 秒"
}

main "$@"