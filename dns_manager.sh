#!/bin/bash

# DNS 管理模块
# 专门处理 Cloudflare DNS 相关操作

# 加载常量定义
source /app/constants.sh

# ============= DNS 管理函数 =============

# 通用Cloudflare API调用函数
call_cloudflare_api() {
    local method="$1"
    local url="$2"
    local data="$3"
    local api_timeout=${API_TIMEOUT:-30}
    
    local response
    if [[ "$method" == "GET" ]]; then
        if [[ -n "$api_timeout" ]]; then
            response=$(curl -s -X GET "$url" \
                -m "$api_timeout" \
                -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json")
        else
            response=$(curl -s -X GET "$url" \
                -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json")
        fi
    elif [[ "$method" == "POST" ]]; then
        if [[ -n "$api_timeout" ]]; then
            response=$(curl -s -X POST "$url" \
                -m "$api_timeout" \
                -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json" \
                --data "$data")
        else
            response=$(curl -s -X POST "$url" \
                -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json" \
                --data "$data")
        fi
    elif [[ "$method" == "DELETE" ]]; then
        if [[ -n "$api_timeout" ]]; then
            response=$(curl -s -X DELETE "$url" \
                -m "$api_timeout" \
                -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json")
        else
            response=$(curl -s -X DELETE "$url" \
                -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                -H "Content-Type: application/json")
        fi
    fi
    
    echo "$response"
    
    # 检查API调用是否成功
    if [[ $? -eq 0 ]] && echo "$response" | grep -q '"success":true'; then
        return $EXIT_SUCCESS
    else
        return $EXIT_DNS_ERROR
    fi
}

# 获取当前DNS记录的IP列表
get_current_dns_ips() {
    # get_current_dns_records已经返回IP地址列表，直接使用
    get_current_dns_records
}

# 获取当前所有DNS记录
get_current_dns_records() {
    if ! check_required_env "CLOUDFLARE_ZONE_ID" "CLOUDFLARE_API_TOKEN" "CLOUDFLARE_DOMAIN"; then
        return $EXIT_CONFIG_ERROR
    fi
    
    local api_url="${CLOUDFLARE_API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${CLOUDFLARE_DOMAIN}&type=A"
    local response=$(call_cloudflare_api "GET" "$api_url")
    
    if [[ $? -eq 0 ]]; then
        # 提取所有A记录的IP地址
        echo "$response" | grep -o '"content":"[^"]*"' | cut -d'"' -f4
        return $EXIT_SUCCESS
    else
        log_message "ERROR" "获取DNS记录失败: $response"
        return $EXIT_DNS_ERROR
    fi
}

# 获取DNS记录ID
get_dns_record_id() {
    local ip_address="$1"
    
    if ! check_required_env "CLOUDFLARE_ZONE_ID" "CLOUDFLARE_API_TOKEN" "CLOUDFLARE_DOMAIN"; then
        return $EXIT_CONFIG_ERROR
    fi
    
    local api_url="${CLOUDFLARE_API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${CLOUDFLARE_DOMAIN}&type=A&content=${ip_address}"
    local response=$(call_cloudflare_api "GET" "$api_url")
    
    if [[ $? -eq 0 ]]; then
        # 提取记录ID
        echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
        return $EXIT_SUCCESS
    else
        return $EXIT_DNS_ERROR
    fi
}

# 添加DNS记录
add_dns_record() {
    local ip_address="$1"
    
    if ! check_required_env "CLOUDFLARE_ZONE_ID" "CLOUDFLARE_API_TOKEN" "CLOUDFLARE_DOMAIN"; then
        return $EXIT_CONFIG_ERROR
    fi
    
    local api_url="${CLOUDFLARE_API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records"
    local json_data="{\"type\":\"A\",\"name\":\"${CLOUDFLARE_DOMAIN}\",\"content\":\"${ip_address}\",\"ttl\":1,\"proxied\":false}"
    
    local response=$(call_cloudflare_api "POST" "$api_url" "$json_data")
    
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "成功添加DNS记录: $ip_address"
        return $EXIT_SUCCESS
    else
        log_message "ERROR" "添加DNS记录失败: $response"
        return $EXIT_DNS_ERROR
    fi
}

# 删除DNS记录
delete_dns_record() {
    local ip_address="$1"
    
    if ! check_required_env "CLOUDFLARE_ZONE_ID" "CLOUDFLARE_API_TOKEN" "CLOUDFLARE_DOMAIN"; then
        return $EXIT_CONFIG_ERROR
    fi
    
    # 获取记录ID
    local record_id=$(get_dns_record_id "$ip_address")
    if [[ -z "$record_id" ]]; then
        log_message "WARN" "未找到DNS记录: $ip_address"
        return $EXIT_DNS_ERROR
    fi
    
    local api_url="${CLOUDFLARE_API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}"
    
    local response=$(call_cloudflare_api "DELETE" "$api_url")
    
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "成功删除DNS记录: $ip_address"
        return $EXIT_SUCCESS
    else
        log_message "ERROR" "删除DNS记录失败: $response"
        return $EXIT_DNS_ERROR
    fi
}

# 检查IP是否已存在于DNS记录中
ip_exists_in_dns() {
    local ip_address="$1"
    local current_ips="$2"
    
    echo "$current_ips" | grep -q "^${ip_address}$"
}

# 全局变量用于返回统计信息
DNS_ADDED_COUNT=0
DNS_DELETED_COUNT=0
DNS_ADD_FAILED_COUNT=0
DNS_DELETE_FAILED_COUNT=0
DNS_ADD_FAILED_IPS=""
DNS_DELETE_FAILED_IPS=""

# 主要的DNS更新函数 - 实现先增后删策略
update_dns_records() {
    local best_ips_file="$1"
    
    # 重置全局计数器
    DNS_ADDED_COUNT=0
    DNS_DELETED_COUNT=0
    DNS_ADD_FAILED_COUNT=0
    DNS_DELETE_FAILED_COUNT=0
    DNS_ADD_FAILED_IPS=""
    DNS_DELETE_FAILED_IPS=""
    
    if ! validate_file "$best_ips_file"; then
        log_message "ERROR" "最优IP文件不存在或为空: $best_ips_file"
        return $EXIT_SPEEDTEST_ERROR
    fi
    
    log_message "INFO" "开始更新DNS记录..."
    
    # 获取当前DNS记录
    local current_ips=$(get_current_dns_ips)
    if [[ $? -ne $EXIT_SUCCESS ]]; then
        log_message "ERROR" "无法获取当前DNS记录"
        return $EXIT_DNS_ERROR
    fi
    
    log_message "INFO" "当前DNS记录:"
    if [[ -n "$current_ips" ]]; then
        echo "$current_ips" | while read -r ip; do
            log_message "INFO" "  - $ip"
        done
    else
        log_message "INFO" "  (无记录)"
    fi
    
    # 读取最优IP列表
    local best_ips=()
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && best_ips+=("$ip")
    done < "$best_ips_file"
    
    log_message "INFO" "最优IP列表:"
    for ip in "${best_ips[@]}"; do
        log_message "INFO" "  - $ip"
    done
    
    # 第一步：添加新的最优IP（如果不存在）
    log_message "INFO" "第一步：添加新的DNS记录..."
    for ip in "${best_ips[@]}"; do
        if ! ip_exists_in_dns "$ip" "$current_ips"; then
            if add_dns_record "$ip"; then
                ((DNS_ADDED_COUNT++))
            else
                ((DNS_ADD_FAILED_COUNT++))
                DNS_ADD_FAILED_IPS="${DNS_ADD_FAILED_IPS}${ip}\n"
                log_message "ERROR" "添加DNS记录失败: $ip"
            fi
        else
            log_message "INFO" "DNS记录已存在，跳过: $ip"
        fi
    done
    
    # 第二步：删除不在最优列表中的旧记录
    log_message "INFO" "第二步：删除旧的DNS记录..."
    if [[ -n "$current_ips" ]]; then
        while read -r ip; do
            local should_keep=false
            for best_ip in "${best_ips[@]}"; do
                if [[ "$ip" == "$best_ip" ]]; then
                    should_keep=true
                    break
                fi
            done
            
            if [[ "$should_keep" == "false" ]]; then
                if delete_dns_record "$ip"; then
                    ((DNS_DELETED_COUNT++))
                else
                    ((DNS_DELETE_FAILED_COUNT++))
                    DNS_DELETE_FAILED_IPS="${DNS_DELETE_FAILED_IPS}${ip}\n"
                    log_message "ERROR" "删除DNS记录失败: $ip"
                fi
            fi
        done <<< "$current_ips"
    fi
    
    log_message "INFO" "DNS更新完成 - 添加: $DNS_ADDED_COUNT 条, 删除: $DNS_DELETED_COUNT 条"
    
    return $EXIT_SUCCESS
}

# 导出函数
export -f call_cloudflare_api
export -f get_current_dns_ips
export -f get_current_dns_records
export -f get_dns_record_id
export -f add_dns_record
export -f delete_dns_record
export -f ip_exists_in_dns
export -f update_dns_records
