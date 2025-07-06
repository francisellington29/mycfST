#!/bin/bash

# 通知模块
# 专门处理各种通知相关操作

# 加载常量定义
source /app/constants.sh

# ============= 通知配置 =============

# 获取通知配置
get_notification_config() {
    NOTIFICATION_ENABLE=${NOTIFICATION_ENABLE:-"true"}
    NOTIFICATION_SUCCESS=${NOTIFICATION_SUCCESS:-"true"}
    NOTIFICATION_FAILURE=${NOTIFICATION_FAILURE:-"true"}
    
    TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
    TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
    TELEGRAM_PROXY_URL=${TELEGRAM_PROXY_URL}
}

# ============= 基础通知函数 =============

# 通用Telegram API调用函数
call_telegram_api() {
    local api_url="$1"
    local message="$2"
    local api_timeout=${API_TIMEOUT}
    
    local response
    if [[ -n "$api_timeout" ]]; then
        response=$(curl -s -m "$api_timeout" -X POST "$api_url" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=HTML")
    else
        response=$(curl -s -X POST "$api_url" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=HTML")
    fi
    
    echo "$response"
    
    # 检查API调用是否成功
    if [[ $? -eq 0 ]] && echo "$response" | grep -q '"ok":true'; then
        return $EXIT_SUCCESS
    else
        return $EXIT_NOTIFICATION_ERROR
    fi
}

# 发送Telegram消息
send_telegram_message() {
    local message="$1"
    local force_send="$2"
    
    # 获取通知配置
    get_notification_config
    
    # 检查是否启用通知
    if [[ "$NOTIFICATION_ENABLE" != "true" ]] && [[ "$force_send" != "force" ]]; then
        log_message "DEBUG" "通知已禁用，跳过发送"
        return $EXIT_SUCCESS
    fi
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        log_message "WARN" "Telegram配置不完整，跳过通知"
        return $EXIT_NOTIFICATION_ERROR
    fi
    
    local api_timeout=${API_TIMEOUT}
    
    # 使用代理服务格式发送消息
    local response
    if [[ -n "$TELEGRAM_PROXY_URL" ]]; then
        # 使用代理服务：POST请求避免URL过长问题
        log_message "INFO" "🔔 Telegram通知调试信息:"
        log_message "INFO" "  代理URL: $TELEGRAM_PROXY_URL"
        log_message "INFO" "  Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
        log_message "INFO" "  Chat ID: $TELEGRAM_CHAT_ID"
        log_message "INFO" "  消息长度: ${#message} 字符"
        
        # 使用POST请求发送数据，避免URL过长
        if [[ -n "$api_timeout" ]]; then
            response=$(curl -s -m "$api_timeout" \
                -X POST \
                -H "User-Agent: Mozilla/5.0 (Linux; CloudflareSpeedTest Bot)" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -H "Accept: application/json" \
                --data-urlencode "token=${TELEGRAM_BOT_TOKEN}" \
                --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
                --data-urlencode "text=${message}" \
                --data-urlencode "parse_mode=HTML" \
                "$TELEGRAM_PROXY_URL")
        else
            response=$(curl -s \
                -X POST \
                -H "User-Agent: Mozilla/5.0 (Linux; CloudflareSpeedTest Bot)" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -H "Accept: application/json" \
                --data-urlencode "token=${TELEGRAM_BOT_TOKEN}" \
                --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
                --data-urlencode "text=${message}" \
                --data-urlencode "parse_mode=HTML" \
                "$TELEGRAM_PROXY_URL")
        fi
        
        # 代理服务的成功响应检查
        local curl_exit_code=$?
        log_message "INFO" "  curl退出码: $curl_exit_code"
        log_message "INFO" "  响应内容: $response"
        
        # 对于代理服务，只要curl成功执行就认为发送成功
        # 因为代理服务可能不返回标准的Telegram API JSON格式
        if [[ $curl_exit_code -eq 0 ]]; then
            # 如果有响应内容，检查是否包含错误信息
            if [[ -n "$response" ]] && echo "$response" | grep -qi "error\|fail\|invalid"; then
                log_message "WARN" "❌ 代理服务返回错误: $response"
                # 尝试备用API
                log_message "INFO" "🔄 尝试使用标准API作为备用..."
                local backup_url="${TELEGRAM_API_BASE}/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
                local backup_response=$(call_telegram_api "$backup_url" "$message")
                
                if [[ $? -eq 0 ]]; then
                    log_message "INFO" "✅ 备用API发送成功"
                    return $EXIT_SUCCESS
                else
                    log_message "WARN" "❌ 备用API也发送失败: $backup_response"
                    return $EXIT_NOTIFICATION_ERROR
                fi
            else
                # 代理服务curl成功，认为发送成功
                log_message "INFO" "✅ Telegram通知发送成功（代理服务）"
                return $EXIT_SUCCESS
            fi
        else
            log_message "WARN" "❌ 代理服务连接失败 (curl退出码: $curl_exit_code)"
            log_message "WARN" "   响应内容: $response"
            
            # 尝试备用API
            log_message "INFO" "🔄 尝试使用标准API作为备用..."
            local backup_url="${TELEGRAM_API_BASE}/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
            local backup_response=$(call_telegram_api "$backup_url" "$message")
            
            if [[ $? -eq 0 ]]; then
                log_message "INFO" "✅ 备用API发送成功"
                return $EXIT_SUCCESS
            else
                log_message "WARN" "❌ 备用API也发送失败: $backup_response"
                return $EXIT_NOTIFICATION_ERROR
            fi
        fi
    else
        # 使用标准Telegram API
        local api_url="${TELEGRAM_API_BASE}/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
        response=$(call_telegram_api "$api_url" "$message")
        
        if [[ $? -eq 0 ]]; then
            log_message "INFO" "Telegram通知发送成功"
            return $EXIT_SUCCESS
        else
            log_message "WARN" "Telegram通知发送失败: $response"
            return $EXIT_NOTIFICATION_ERROR
        fi
    fi
}

# ============= 专用通知函数 =============

# 发送测速成功通知
send_speedtest_success_notification() {
    local best_ip="$1"
    local best_latency="$2"
    local best_speed="$3"
    local domain="$4"
    
    get_notification_config
    
    if [[ "$NOTIFICATION_SUCCESS" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="✅ <b>Cloudflare 速度测试完成</b>

📍 域名: ${domain}
🎯 最优IP: ${best_ip}
⚡ 延迟: ${best_latency} ms
🚀 速度: ${best_speed} MB/s
⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
}

# 发送DNS更新成功通知
send_dns_update_success_notification() {
    local domain="$1"
    local added_count="$2"
    local deleted_count="$3"
    local best_ips="$4"
    local speedtest_results="$5"
    local current_dns_count="$6"
    local add_failed_count="$7"
    local add_failed_ips="$8"
    local delete_failed_count="$9"
    local delete_failed_ips="${10}"
    local final_dns_count="${11}"
    local next_run_time="${12}"
    
    get_notification_config
    
    if [[ "$NOTIFICATION_SUCCESS" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="🚀 <b>Cloudflare DNS 更新成功</b>

🎯 <b>当前测试结果:</b>
"
    
    # 格式化测速结果
    if [[ -n "$speedtest_results" ]]; then
        # 添加表头和分隔线
        message="${message}
===============================================
 IP 地址         已发送  已接收  丢包率  延迟  速度(MB/s)  地区码
==================================================="
        
        # 跳过CSV头部，格式化每一行
        local line_count=0
        while IFS= read -r line; do
            if [[ $line_count -eq 0 ]]; then
                # 跳过CSV头部
                ((line_count++))
                continue
            fi
            if [[ -n "$line" ]]; then
                # 解析CSV行：IP,发送,接收,丢包率,延迟,速度,地区
                IFS=',' read -r ip sent recv loss latency speed region <<< "$line"
                # 格式化为对齐的表格，IP地址高亮
                message="${message}
<b>$(printf "%-15s" "$ip")</b>        $(printf "%4s %7s %7s %9s" "$sent" "$recv" "$loss" "$latency")            <b>$(printf "%4s" "$speed")</b>     $(printf "%4s" "$region")
==============================================="
            fi
            ((line_count++))
        done <<< "$speedtest_results"
    fi
    message="${message}

📍 <b>域名:</b> <code>${domain}</code>
📊 <b>当前DNS记录:</b> <b>${current_dns_count:-0}</b> 条

"
    
    # 新增记录
    message="${message}➕ <b>新增记录:</b> <b>${added_count:-0}</b> 条"
    if [[ "${add_failed_count:-0}" -gt 0 ]]; then
        message="${message}
      - <b>新增失败${add_failed_count}条</b>"
        if [[ -n "$add_failed_ips" ]]; then
            # 处理失败IP，替换\n为真正的换行
            local clean_failed_ips=$(echo "$add_failed_ips" | sed 's/\\n/\n/g')
            while read -r ip; do
                if [[ -n "$ip" ]]; then
                    message="${message}
          - <code>${ip}</code>"
                fi
            done <<< "$clean_failed_ips"
        fi
    fi
    
    # 删除记录
    message="${message}

➖ <b>删除记录:</b> <b>${deleted_count:-0}</b> 条"
    if [[ "${delete_failed_count:-0}" -gt 0 ]]; then
        message="${message}
      - <b>删除失败${delete_failed_count}条</b>"
        if [[ -n "$delete_failed_ips" ]]; then
            # 处理失败IP，替换\n为真正的换行
            local clean_failed_ips=$(echo "$delete_failed_ips" | sed 's/\\n/\n/g')
            while read -r ip; do
                if [[ -n "$ip" ]]; then
                    message="${message}
          - <code>${ip}</code>"
                fi
            done <<< "$clean_failed_ips"
        fi
    fi
    
    # 最终状态
    message="${message}
    
📊 <b>更新DNS后:</b> <b>${final_dns_count:-0}</b> 条
⏰ <b>当前时间:</b> <code>$(date '+%Y-%m-%d %H:%M:%S')</code>"
    if [[ -n "$next_run_time" ]]; then
        message="${message}
⏰ <b>下次测速时间:</b> <code>${next_run_time}</code>"
    fi
    
    send_telegram_message "$message"
}

# 发送DNS无需更新通知
send_dns_no_update_notification() {
    local domain="$1"
    local best_ip="$2"
    local best_latency="$3"
    local best_speed="$4"
    
    get_notification_config
    
    if [[ "$NOTIFICATION_SUCCESS" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="✅ <b>Cloudflare 速度测试完成</b>

📍 域名: ${domain}
🎯 最优IP: ${best_ip}
⚡ 延迟: ${best_latency} ms
🚀 速度: ${best_speed} MB/s
💡 DNS记录无需更新"
    message="${message}⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
}

# 发送测速失败通知
send_speedtest_failure_notification() {
    local error_message="$1"
    
    get_notification_config
    
    if [[ "$NOTIFICATION_FAILURE" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="❌ <b>Cloudflare 速度测试失败</b>

💥 错误信息: ${error_message}"
    message="${message}⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
}

# 发送DNS更新失败通知
send_dns_update_failure_notification() {
    local domain="$1"
    local target_ip="$2"
    local error_message="$3"
    
    get_notification_config
    
    if [[ "$NOTIFICATION_FAILURE" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="❌ <b>Cloudflare DNS 更新失败</b>

📍 域名: ${domain}
🎯 目标IP: ${target_ip}
💥 错误信息: ${error_message}"
    message="${message}⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
}

# 发送初始化失败通知
send_init_failure_notification() {
    local error_message="$1"
    
    get_notification_config
    
    if [[ "$NOTIFICATION_FAILURE" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="⚠️ <b>CloudflareSpeedTest 初始化失败</b>

💥 错误信息: ${error_message}"
    message="${message}⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
}

# 发送结果解析失败通知
send_parse_failure_notification() {
    get_notification_config
    
    if [[ "$NOTIFICATION_FAILURE" != "true" ]]; then
        return $EXIT_SUCCESS
    fi
    
    local message="⚠️ <b>Cloudflare 速度测试异常</b>

❌ 无法解析测试结果"
    message="${message}⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_telegram_message "$message"
}

# ============= 通知测试函数 =============

# 测试通知功能
# 导出函数
export -f call_telegram_api
export -f send_telegram_message
export -f send_speedtest_success_notification
export -f send_dns_update_success_notification
export -f send_dns_no_update_notification
export -f send_speedtest_failure_notification
export -f send_dns_update_failure_notification
export -f send_init_failure_notification
export -f send_parse_failure_notification
export -f get_notification_config
