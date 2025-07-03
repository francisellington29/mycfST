#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - 通知推送脚本
# 负责发送各种通知消息

set -e

# 导入工具函数
source "$(dirname "$0")/utils.sh"

# 导入常量定义
source "$(dirname "$0")/constants.sh"

# 计算下次执行时间（复制自speedtest.sh）
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

# 生成通知消息
generate_notification_message() {
    local message=""
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    message="CloudflareSpeedTest DDNS - $timestamp\n\n"
    
    # 测速配置信息
    message="${message}📋 测速配置:\n"
    message="${message}• 域名: ${DDNS_DOMAIN:-未配置}\n"
    message="${message}• IP数量: ${DDNS_IP_COUNT:-5}\n"
    message="${message}• 测速模式: ${SPEEDTEST_MODE:-tcping}\n"
    message="${message}• 测速URL: ${SPEEDTEST_URL:-未配置}\n"
    message="${message}• 延迟范围: ${SPEEDTEST_LATENCY_MIN:-0}-${SPEEDTEST_LATENCY_MAX:-200}ms\n"
    message="${message}• 速度阈值: >${SPEEDTEST_SPEED_MIN:-5}MB/s\n\n"
    
    # 测速结果 - 显示原始测速数据
    if [[ -f "$RESULT_FILE" ]]; then
        local line_count=$(cat "$RESULT_FILE" | wc -l)
        local valid_count=$((line_count - 1))
        
        if [[ $valid_count -gt 0 ]]; then
            message="${message}📊 测速结果:\n"
            while IFS=',' read -r ip sent recv loss latency speed region; do
                message="${message}$ip - ${latency}ms - ${speed}MB/s - 丢包${loss}% - ${region:-N/A}\n"
            done < <(tail -n +2 "$RESULT_FILE")
            message="${message}\n"
        else
            message="${message}❌ 测速失败: 未找到可用IP\n\n"
        fi
    else
        message="${message}❌ 测速失败: 结果文件不存在\n\n"
    fi
    
    # DNS操作结果 - 显示具体的IP操作
    if [[ "${DDNS_DOMAIN:-}" != "" ]]; then
        local create_success=${DNS_CREATE_SUCCESS:-0}
        local create_fail=${DNS_CREATE_FAIL:-0}
        local delete_success=${DNS_DELETE_SUCCESS:-0}
        local delete_fail=${DNS_DELETE_FAIL:-0}
        local skipped=${DNS_SKIPPED:-0}
        
        message="${message}🌐 DNS操作结果:\n"
        
        if [[ $create_success -gt 0 ]]; then
            message="${message}✅ 创建成功: ${create_success}个DNS记录\n"
        fi
        
        if [[ $create_fail -gt 0 ]]; then
            message="${message}❌ 创建失败: ${create_fail}个DNS记录\n"
        fi
        
        if [[ $delete_success -gt 0 ]]; then
            message="${message}✅ 删除成功: ${delete_success}个DNS记录\n"
        fi
        
        if [[ $delete_fail -gt 0 ]]; then
            message="${message}❌ 删除失败: ${delete_fail}个DNS记录\n"
        fi
        
        if [[ $skipped -gt 0 ]]; then
            message="${message}ℹ️ 跳过: ${skipped}个已存在记录\n"
        fi
        
        if [[ $((create_success + create_fail + delete_success + delete_fail)) -eq 0 && $skipped -eq 0 ]]; then
            message="${message}ℹ️ 无DNS操作\n"
        fi
    else
        message="${message}⏭️ 跳过DNS更新 (未配置域名)\n"
    fi
    
    # 下次任务时间
    local next_run=$(get_next_cron_time "${SCHEDULE_CRON:-*/15 * * * *}")
    if [[ -n "$next_run" ]]; then
        message="${message}\n⏰ 下次执行: $next_run\n"
    fi
    
    echo -e "$message"
}

# 验证Telegram代理配置
validate_telegram_proxy() {
    # 如果配置了代理URL，验证格式并启用代理
    if [[ -n "${TELEGRAM_PROXY_URL:-}" ]]; then
        # 验证代理URL格式
        if [[ ! "$TELEGRAM_PROXY_URL" =~ ^(http|https|socks4|socks5):// ]]; then
            log_warn "Telegram代理URL格式不正确: $TELEGRAM_PROXY_URL，将使用直连"
            return 1
        fi
        
        log_info "Telegram代理配置验证通过: $TELEGRAM_PROXY_URL"
        return 0
    fi
    
    return 1
}

# 发送Telegram通知
send_telegram_notification() {
    local message="$1"
    
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        log_info "Telegram通知未配置，跳过"
        return 0
    fi
    
    # 验证代理配置
    validate_telegram_proxy
    
    log_info "发送Telegram通知..."
    
    # 构建API URL - 如果有代理则使用代理URL，否则使用官方API
    local api_url
    if [[ -n "${TELEGRAM_PROXY_URL:-}" ]]; then
        # 使用代理URL替换官方API（完整URL替换方式）
        api_url="${TELEGRAM_PROXY_URL%/}/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
        log_debug "使用Telegram代理API: $api_url"
    else
        # 使用官方API
        api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
        log_debug "使用官方Telegram API: $api_url"
    fi
    
    # 调试：显示API URL（隐藏token的部分字符）
    local debug_url=$(echo "$api_url" | sed 's/bot[0-9]*:[A-Za-z0-9_-]*/bot***:***/')
    log_info "Telegram API URL: $debug_url"
    
    # 使用POST请求发送消息，避免URL编码问题
    local response=$(curl -s --connect-timeout 10 --max-time 30 \
        -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
            \"text\": $(echo "$message" | jq -R -s .),
            \"parse_mode\": \"HTML\"
        }")
    
    if [[ $? -eq 0 ]]; then
        # 检查响应是否包含成功标识
        if echo "$response" | grep -q '"ok":true'; then
            log_info "Telegram通知发送成功"
            log_debug "API响应: $response"
            return 0
        else
            log_error "Telegram通知发送失败"
            log_error "API响应: $response"
            return 1
        fi
    else
        log_error "Telegram通知发送失败: 网络错误"
        return 1
    fi
}


# 写入本地日志
write_notification_log() {
    local message="$1"
    local date_str=$(date '+%Y-%m-%d')
    local log_file="$PROJECT_DIR/logs/notifications-${date_str}.log"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 确保日志目录存在
    mkdir -p "$(dirname "$log_file")"
    
    echo "[$timestamp] ===== 通知记录 =====" >> "$log_file"
    echo -e "$message" >> "$log_file"
    echo "[$timestamp] ===================" >> "$log_file"
    echo "" >> "$log_file"
    
    log_info "通知已记录到本地日志: $log_file"
}

# 主函数
main() {
    log_info "========================================="
    log_info "开始发送通知"
    log_info "========================================="
    
    # 生成通知消息
    local message
    message=$(generate_notification_message)
    
    if [[ -z "$message" ]]; then
        log_error "生成通知消息失败"
        return 1
    fi
    
    log_info "通知消息内容:"
    echo -e "$message" | while IFS= read -r line; do
        log_info "  $line"
    done
    
    # 写入本地日志
    write_notification_log "$message"
    
    # 发送各种通知
    local success_count=0
    local total_count=0
    
    # Telegram通知
    if [[ "${NOTIFICATION_TELEGRAM_ENABLED:-false}" == "true" ]]; then
        total_count=$((total_count + 1))
        if send_telegram_notification "$message"; then
            success_count=$((success_count + 1))
        fi
    fi   
    
    if [[ $total_count -eq 0 ]]; then
        log_info "未启用任何通知方式"
    else
        log_info "通知发送完成: $success_count/$total_count 成功"
    fi
    
    return 0
}

# 执行主函数
main "$@"