#!/bin/bash

# CloudflareSpeedTest 主控脚本
# 负责协调整个测速和DNS更新流程

# 加载常量定义和模块
source /app/constants.sh
source /app/dns_manager.sh
source /app/notification.sh

# 显示配置信息
show_config_info() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==========================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${EMOJI_ROCKET} CloudflareSpeedTest 详细配置信息${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==========================================${COLOR_RESET}"
    
    # 基本配置
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== 基本配置 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_WORLD} 时区设置: ${COLOR_CYAN}${TZ:-'未设置'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_CALENDAR} 定时任务: ${COLOR_CYAN}${CRON_SCHEDULE:-'*/15 * * * *'}${COLOR_RESET}"
    echo ""
    
    # 下载配置
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== 下载配置 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_DOWNLOAD} CloudflareST版本: ${COLOR_CYAN}${CLOUDFLARE_ST_VERSION:-'v2.2.5'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_LINK} GitHub代理: ${COLOR_CYAN}${GITHUB_PROXY_URL:-'未使用'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_LOCATION} 强制重下位置文件: ${COLOR_CYAN}${FORCE_REDOWNLOAD_LOCATION:-false}${COLOR_RESET}"
    echo ""
    
    # SpeedTest 配置
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== SpeedTest 配置 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_GEAR} 延迟测速线程数: ${COLOR_CYAN}${SPEEDTEST_THREADS:-200}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_TIMER} 延迟测速次数: ${COLOR_CYAN}${SPEEDTEST_LATENCY_TIMES:-4}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_CHART} 下载测速数量: ${COLOR_CYAN}${SPEEDTEST_DOWNLOAD_NUM:-10}个${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_CLOCK} 下载测速时间: ${COLOR_CYAN}${SPEEDTEST_DOWNLOAD_TIME:-10}秒${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_PORT} 测速端口: ${COLOR_CYAN}${SPEEDTEST_PORT:-443}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_SPEED} 测速地址: ${COLOR_CYAN}${SPEEDTEST_URL:-'默认'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_NETWORK} 测速模式: ${COLOR_CYAN}${SPEEDTEST_MODE:-tcping}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_LOCATION} 匹配指定地区: ${COLOR_CYAN}${SPEEDTEST_COLO:-'全部'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_TIMER} 平均延迟上限: ${COLOR_CYAN}${SPEEDTEST_LATENCY_MAX:-9999}ms${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_TIMER} 平均延迟下限: ${COLOR_CYAN}${SPEEDTEST_LATENCY_MIN:-0}ms${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_WARNING} 丢包率上限: ${COLOR_CYAN}${SPEEDTEST_LOSS_RATE:-1.00}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_SPEED} 下载速度下限: ${COLOR_CYAN}${SPEEDTEST_SPEED_MIN:-0.00} MB/s${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_FILE} 显示结果数量: ${COLOR_CYAN}${SPEEDTEST_RESULT_NUM:-10}个${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_DATABASE} IP段数据文件: ${COLOR_CYAN}${SPEEDTEST_IP_FILE:-ip.txt}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_NETWORK} 指定IP段数据: ${COLOR_CYAN}${SPEEDTEST_IP_RANGE:-'未指定'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_SHIELD} 禁用下载测速: ${COLOR_CYAN}${SPEEDTEST_DISABLE_DOWNLOAD:-false}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_TARGET} 测速全部IP: ${COLOR_CYAN}${SPEEDTEST_ALL_IP:-false}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_DEBUG} 调试模式: ${COLOR_CYAN}${SPEEDTEST_DEBUG:-false}${COLOR_RESET}"
    echo ""
    
    # Cloudflare DNS 配置
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== Cloudflare DNS 配置 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_GLOBE} 域名: ${COLOR_CYAN}${CLOUDFLARE_DOMAIN:-'未配置'}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_KEY} Zone ID: ${COLOR_CYAN}${CLOUDFLARE_ZONE_ID:0:20}...${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_KEY} API Token: ${COLOR_CYAN}${CLOUDFLARE_API_TOKEN:0:20}...${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_FILE} DNS记录数量: ${COLOR_CYAN}${CLOUDFLARE_DNS_COUNT:-3}${COLOR_RESET}"
    echo ""
    
    # 通知配置
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== 通知配置 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_BELL} 启用通知: ${COLOR_CYAN}${NOTIFICATION_ENABLE:-true}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_ROBOT} 通知平台: ${COLOR_CYAN}${NOTIFICATION_PLATFORM:-telegram}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_SUCCESS} 成功时通知: ${COLOR_CYAN}${NOTIFICATION_SUCCESS:-true}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_ERROR} 失败时通知: ${COLOR_CYAN}${NOTIFICATION_FAILURE:-true}${COLOR_RESET}"
    echo ""
    
    # Telegram 机器人配置
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== Telegram 机器人配置 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_ROBOT} Bot Token: ${COLOR_CYAN}${TELEGRAM_BOT_TOKEN:0:15}...${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_CHAT} Chat ID: ${COLOR_CYAN}${TELEGRAM_CHAT_ID}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_LINK} 代理URL: ${COLOR_CYAN}${TELEGRAM_PROXY_URL:-'未使用'}${COLOR_RESET}"
    echo ""
    
    # 系统信息
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}#=========== 系统信息 ===========${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_FOLDER} 日志文件: ${COLOR_CYAN}$CRON_LOG_FILE${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_FILE} 结果文件: ${COLOR_CYAN}$RESULT_FILE${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_BUILDING} 架构: ${COLOR_CYAN}$(uname -m)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}${EMOJI_DOCKER} 容器环境: ${COLOR_CYAN}$([ -f /.dockerenv ] && echo "Docker" || echo "本地")${COLOR_RESET}"
    
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==========================================${COLOR_RESET}"
    echo ""
}

# 清理旧日志文件（保留2天）
cleanup_old_logs() {
    local cleaned_files=0
    
    # 清理cron日志文件（如果文件大小超过10MB或修改时间超过2天）
    if [[ -f "$CRON_LOG_FILE" ]]; then
        local file_size=$(stat -c%s "$CRON_LOG_FILE" 2>/dev/null || echo "0")
        local file_age=$(find "$CRON_LOG_FILE" -mtime +2 2>/dev/null | wc -l)
        
        # 如果文件超过10MB或超过2天，则清空
        if [[ $file_size -gt 10485760 ]] || [[ $file_age -gt 0 ]]; then
            > "$CRON_LOG_FILE"
            log_message "INFO" "已清空cron日志文件 (大小: ${file_size}字节, 超过2天: $([[ $file_age -gt 0 ]] && echo "是" || echo "否"))"
            ((cleaned_files++))
        fi
    fi
    
    # 清理其他可能的日志文件
    local old_logs=$(find /app -name "*.log" -mtime +2 -type f 2>/dev/null | wc -l)
    if [[ $old_logs -gt 0 ]]; then
        find /app -name "*.log" -mtime +2 -type f -delete 2>/dev/null || true
        ((cleaned_files += old_logs))
    fi
    
    # 清理临时日志文件
    local temp_logs=$(find /tmp -name "cloudflare_*.log" -mtime +2 -type f 2>/dev/null | wc -l)
    if [[ $temp_logs -gt 0 ]]; then
        find /tmp -name "cloudflare_*.log" -mtime +2 -type f -delete 2>/dev/null || true
        ((cleaned_files += temp_logs))
    fi
    
    if [[ $cleaned_files -gt 0 ]]; then
        log_message "INFO" "日志清理完成，清理了 $cleaned_files 个文件"
    fi
}

# 显示下次运行时间
show_next_run_time() {
    local cron_schedule="${CRON_SCHEDULE:-'*/15 * * * *'}"
    echo ""
    echo "⏰ 定时任务信息:"
    echo "  📅 Cron表达式: $cron_schedule"
    
    # 解析cron表达式并计算下次运行时间
    IFS=' ' read -ra cron_parts <<< "$cron_schedule"
    local minute_part="${cron_parts[0]}"
    
    local current_minute=$(date '+%M')
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "  🕐 当前时间: $current_time"
    
    if [[ "$minute_part" =~ ^\*/([0-9]+)$ ]]; then
        local interval=${BASH_REMATCH[1]}
        local next_minute=$(( (current_minute / interval + 1) * interval ))
        if [[ $next_minute -ge 60 ]]; then
            next_minute=0
            local next_hour=$(( $(date '+%H') + 1 ))
            if [[ $next_hour -ge 24 ]]; then
                next_hour=0
            fi
            local next_time=$(date '+%Y-%m-%d ')$(printf "%02d:%02d:00" $next_hour $next_minute)
        else
            local next_time=$(date '+%Y-%m-%d %H:')$(printf "%02d:00" $next_minute)
        fi
        echo "  ⏰ 下次运行: $next_time (每${interval}分钟执行)"
    else
        echo "  ⏰ 下次运行: 请查看cron配置"
    fi
    echo ""
}

# ============= 初始化检查 =============

# 检查并初始化必要组件
check_and_initialize() {
    log_message "INFO" "检查初始化状态..."
    
    # 检查二进制文件
    if ! validate_file "$CLOUDFLARE_ST_BINARY"; then
        log_message "INFO" "CloudflareST 二进制文件不存在，开始初始化..."
        if ! /app/init.sh; then
            log_message "ERROR" "初始化失败"
            send_init_failure_notification "CloudflareST 二进制文件下载失败"
            exit $EXIT_DOWNLOAD_ERROR
        fi
    fi
    
    # 检查数据库文件
    if ! validate_file "$QQWRY_DATABASE" "$MIN_QQWRY_SIZE"; then
        log_message "INFO" "IP数据库文件不存在或过小，开始下载..."
        if ! /app/init.sh; then
            log_message "ERROR" "IP数据库下载失败"
            send_init_failure_notification "IP数据库文件下载失败"
            exit $EXIT_DOWNLOAD_ERROR
        fi
    fi
    
    # 检查IP数据文件
    if ! validate_file "$IPV4_DATA_FILE" && [[ -z "$SPEEDTEST_IP_RANGE" ]]; then
        log_message "WARN" "IPv4数据文件不存在且未指定IP范围: $IPV4_DATA_FILE"
        log_message "INFO" "请通过环境变量SPEEDTEST_IP_RANGE指定IP范围，或提供IPv4数据文件"
    fi
    
    log_message "INFO" "初始化检查完成"
}

# ============= 配置检查 =============

# 检查必需的环境变量
check_required_config() {
    local required_vars=(
        "CLOUDFLARE_ZONE_ID"
        "CLOUDFLARE_API_TOKEN"
        "CLOUDFLARE_DOMAIN"
    )
    
    if ! check_required_env "${required_vars[@]}"; then
        send_init_failure_notification "缺少必需的环境变量配置"
        exit $EXIT_CONFIG_ERROR
    fi
}

# ============= 主流程 =============

main() {
    # 清理旧日志
    cleanup_old_logs
    
    # 显示配置信息
    show_config_info
    
    # 等待确保配置信息完整显示
    sleep 2
    
    log_message "INFO" "🎯 步骤1/6: CloudflareSpeedTest 主控脚本开始"
    
    # 切换到工作目录
    cd "$APP_DIR"
    
    # 确保CloudflareST目录存在
    ensure_directory "$CLOUDFLARE_ST_DIR"
    
    # 1. 初始化检查
    log_message "INFO" "🎯 步骤2/6: 初始化检查 (CloudflareST二进制、IP数据库、位置文件)"
    check_and_initialize
    
    # 2. 配置检查
    log_message "INFO" "🎯 步骤3/6: 配置检查 (环境变量验证)"
    check_required_config
    
    # 3. 执行测速
    log_message "INFO" "🎯 步骤4/6: 执行速度测试 (延迟测试 → 下载测试)"
    if ! /app/speedtest.sh; then
        log_message "ERROR" "速度测试失败"
        send_speedtest_failure_notification "速度测试执行失败"
        exit $EXIT_SPEEDTEST_ERROR
    fi
    
    # 4. 解析测速结果
    log_message "INFO" "🎯 步骤5/6: 解析测速结果 (选择最优IP)"
    if ! validate_file "$RESULT_FILE"; then
        log_message "ERROR" "测速结果文件不存在"
        send_parse_failure_notification
        exit $EXIT_SPEEDTEST_ERROR
    fi
    
    # 读取最优IP信息
    local best_line=$(head -2 "$RESULT_FILE" | tail -1)
    if [[ -z "$best_line" ]]; then
        log_message "ERROR" "无法解析测速结果"
        send_parse_failure_notification
        exit $EXIT_SPEEDTEST_ERROR
    fi
    
    # 解析最优IP信息
    local best_ip=$(echo "$best_line" | cut -d',' -f1)
    local best_latency=$(echo "$best_line" | cut -d',' -f2)
    local best_speed=$(echo "$best_line" | cut -d',' -f6)
    
    log_message "INFO" "最优IP: $best_ip, 延迟: ${best_latency}ms, 速度: ${best_speed}MB/s"
    
    # 5. 准备DNS更新的IP列表
    local dns_count=${CLOUDFLARE_DNS_COUNT:-1}
    local best_ips_file="/tmp/best_ips.txt"
    
    # 提取前N个最优IP
    tail -n +2 "$RESULT_FILE" | head -n "$dns_count" | cut -d',' -f1 > "$best_ips_file"
    
    log_message "INFO" "🎯 步骤6/6: 更新DNS记录 (添加新记录 → 删除旧记录)"
    
    # 6. 更新DNS记录
    if update_dns_records "$best_ips_file"; then
        log_message "INFO" "DNS记录更新成功"
        
        # 发送成功通知
        local best_ips_content=$(cat "$best_ips_file")
        local speedtest_results=""
        if [[ -f "$RESULT_FILE" ]]; then
            speedtest_results=$(cat "$RESULT_FILE")
        fi
        
        # 获取当前DNS记录数量
        local current_dns_ips=$(get_current_dns_ips)
        local current_dns_count=0
        if [[ -n "$current_dns_ips" ]]; then
            current_dns_count=$(echo "$current_dns_ips" | grep -c '^[0-9]')
        fi
        
        # 计算下次运行时间
        local next_run_time=""
        if [[ "${CRON_SCHEDULE}" =~ ^\*/([0-9]+) ]]; then
            local interval=${BASH_REMATCH[1]}
            local current_minute=$(date '+%M')
            local next_minute=$(( (current_minute / interval + 1) * interval ))
            if [[ $next_minute -ge 60 ]]; then
                next_minute=0
                local next_hour=$(( $(date '+%H') + 1 ))
                if [[ $next_hour -ge 24 ]]; then
                    next_hour=0
                fi
                next_run_time=$(date '+%Y-%m-%d ')$(printf "%02d:%02d" $next_hour $next_minute)
            else
                next_run_time=$(date '+%Y-%m-%d %H:')$(printf "%02d" $next_minute)
            fi
        fi
        
        # 等待DNS API同步（短暂延迟）
        sleep 2
        
        # 获取更新后的DNS记录数量
        log_message "INFO" "验证更新后的DNS记录..."
        local final_dns_ips=$(get_current_dns_ips)
        local final_dns_count=0
        if [[ -n "$final_dns_ips" ]]; then
            final_dns_count=$(echo "$final_dns_ips" | grep -c '^[0-9]')
        fi
        
        log_message "INFO" "最终DNS记录:"
        while IFS= read -r ip; do
            if [[ -n "$ip" ]]; then
                log_message "INFO" "  - $ip"
            fi
        done <<< "$final_dns_ips"
        
        send_dns_update_success_notification "$CLOUDFLARE_DOMAIN" "$DNS_ADDED_COUNT" "$DNS_DELETED_COUNT" "$best_ips_content" \
            "$speedtest_results" "$current_dns_count" "$DNS_ADD_FAILED_COUNT" "$DNS_ADD_FAILED_IPS" \
            "$DNS_DELETE_FAILED_COUNT" "$DNS_DELETE_FAILED_IPS" "$final_dns_count" "$next_run_time"
        
    else
        log_message "ERROR" "DNS记录更新失败"
        send_dns_update_failure_notification "$CLOUDFLARE_DOMAIN" "$best_ip" "DNS更新操作失败"
        exit $EXIT_DNS_ERROR
    fi
    
    # 清理临时文件
    cleanup_temp_files "$best_ips_file"
    
    log_message "INFO" "CloudflareSpeedTest 主控脚本完成"
    
    # 显示下次运行时间
    show_next_run_time
    
    exit $EXIT_SUCCESS
}

# 执行主流程
main "$@"
