#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - DDNS更新脚本
# 负责解析测速结果并更新DNS记录

set -e

# 导入工具函数
source "$(dirname "$0")/utils.sh"

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULT_FILE="$PROJECT_DIR/CloudflareST/result.csv"

# 解析测速结果
parse_speedtest_results() {
    log_info "解析测速结果..."
    
    if [[ ! -f "$RESULT_FILE" ]]; then
        log_error "测速结果文件不存在: $RESULT_FILE"
        return 1
    fi
    
    local line_count=$(cat "$RESULT_FILE" | wc -l)
    if [[ $line_count -le 1 ]]; then
        log_error "测速结果文件为空或只有标题行"
        return 1
    fi
    
    log_info "找到 $((line_count - 1)) 个有效IP"
    return 0
}

# 获取最优IP列表
get_best_ips() {
    local count=${1:-${DDNS_IP_COUNT:-5}}
    
    if [[ ! -f "$RESULT_FILE" ]]; then
        log_error "测速结果文件不存在"
        return 1
    fi
    
    log_info "开始筛选最优IP..."
    log_info "筛选条件: 速度>${SPEEDTEST_SPEED_MIN:-0}MB/s, 延迟<${SPEEDTEST_LATENCY_MAX:-300}ms, 丢包率=0%"
    
    # 先尝试筛选符合条件的IP
    local qualified_ips=()
    local all_ips=()
    
    # 跳过标题行，读取所有IP数据
    while IFS=',' read -r ip sent recv loss latency speed region; do
        # 移除可能的空格和引号
        ip=$(echo "$ip" | tr -d ' "')
        loss=$(echo "$loss" | tr -d ' "')
        latency=$(echo "$latency" | tr -d ' "')
        speed=$(echo "$speed" | tr -d ' "')
        
        # 添加到所有IP列表
        all_ips+=("$ip")
        
        # 检查是否符合条件
        # 丢包率必须为0
        if [[ "$loss" != "0.00" ]]; then
            continue
        fi
        
        # 延迟检查
        if (( $(echo "$latency > ${SPEEDTEST_LATENCY_MAX:-300}" | bc -l) )); then
            continue
        fi
        
        # 速度检查
        if (( $(echo "$speed > ${SPEEDTEST_SPEED_MIN:-0}" | bc -l) )); then
            qualified_ips+=("$ip")
            log_debug "符合条件的IP: $ip (延迟:${latency}ms, 速度:${speed}MB/s, 丢包率:${loss}%)"
        fi
    done < <(tail -n +2 "$RESULT_FILE")
    
    # 如果有足够的符合条件的IP，使用它们
    if [[ ${#qualified_ips[@]} -ge $count ]]; then
        log_info "找到 ${#qualified_ips[@]} 个符合条件的IP，使用前 $count 个"
        printf '%s\n' "${qualified_ips[@]:0:$count}"
    else
        log_warn "只找到 ${#qualified_ips[@]} 个符合条件的IP，不足 $count 个"
        log_warn "回退到使用前 $count 个IP（按延迟排序）"
        printf '%s\n' "${all_ips[@]:0:$count}"
    fi
}

# 获取当前DNS记录
get_current_dns_records() {
    local domain="$1"
    
    log_info "获取当前DNS记录: $domain"
    
    local response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${domain}&type=A" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    if [[ $? -ne 0 ]]; then
        log_error "获取DNS记录失败"
        return 1
    fi
    
    # 检查API响应
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    if [[ "$success" != "true" ]]; then
        log_error "Cloudflare API错误: $(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)"
        return 1
    fi
    
    echo "$response"
}

# 删除DNS记录
delete_dns_record() {
    local record_id="$1"
    
    log_info "删除DNS记录: $record_id"
    
    local response=$(curl -s -X DELETE \
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
    if [[ "$success" != "true" ]]; then
        log_error "删除DNS记录失败: $(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)"
        return 1
    fi
    
    log_info "DNS记录删除成功"
}

# 创建DNS记录（异步版本，返回结果文件）
create_dns_record_async() {
    local domain="$1"
    local ip="$2"
    local result_file="$3"
    local ttl="${DDNS_TTL:-300}"
    
    (
        local response=$(curl -s -X POST \
            "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${domain}\",\"content\":\"${ip}\",\"ttl\":${ttl}}")
        
        local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
        if [[ "$success" != "true" ]]; then
            local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
            echo "CREATE_FAIL:$domain:$ip:${error_msg:-Unknown error}" >> "$result_file"
        else
            echo "CREATE_SUCCESS:$domain:$ip" >> "$result_file"
        fi
    ) &
}

# 删除DNS记录（异步版本，返回结果文件）
delete_dns_record_async() {
    local record_id="$1"
    local domain="$2"
    local ip="$3"
    local result_file="$4"
    
    (
        local response=$(curl -s -X DELETE \
            "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json")
        
        local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)
        if [[ "$success" != "true" ]]; then
            local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | head -1)
            echo "DELETE_FAIL:$domain:$ip:${error_msg:-Unknown error}" >> "$result_file"
        else
            echo "DELETE_SUCCESS:$domain:$ip" >> "$result_file"
        fi
    ) &
}

# 获取DNS记录的IP到ID映射
get_ip_to_id_mapping() {
    local records="$1"
    local mapping=""

    # 使用jq解析JSON，获取IP和ID的对应关系
    if command -v jq >/dev/null 2>&1; then
        mapping=$(echo "$records" | jq -r '.result[]? | "\(.content):\(.id)"' 2>/dev/null)
    else
        # 备用方案：使用grep和sed
        local ips=$(echo "$records" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
        local ids=$(echo "$records" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

        # 创建映射
        local ip_array=($ips)
        local id_array=($ids)

        for ((i=0; i<${#ip_array[@]}; i++)); do
            if [[ -n "${ip_array[i]}" && -n "${id_array[i]}" ]]; then
                mapping="$mapping${ip_array[i]}:${id_array[i]}\n"
            fi
        done
    fi

    echo -e "$mapping"
}

# 更新DNS记录
update_dns_records() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        log_error "域名不能为空"
        return 1
    fi

    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        log_error "Cloudflare API Token未配置"
        return 1
    fi

    if [[ -z "$CLOUDFLARE_ZONE_ID" ]]; then
        log_error "Cloudflare Zone ID未配置"
        return 1
    fi

    echo "更新DNS记录: $domain"

    # 获取最优IP列表
    local best_ips
    best_ips=$(get_best_ips "${DDNS_IP_COUNT:-5}")
    if [[ $? -ne 0 ]] || [[ -z "$best_ips" ]]; then
        log_error "获取最优IP失败"
        return 1
    fi

    # 获取当前DNS记录
    local current_records
    current_records=$(get_current_dns_records "$domain")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # 提取当前记录的IP地址
    local current_ips
    current_ips=$(echo "$current_records" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)

    # 提取当前记录的ID
    local record_ids
    record_ids=$(echo "$current_records" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    # 获取IP到ID的映射关系
    local ip_to_id_mapping
    ip_to_id_mapping=$(get_ip_to_id_mapping "$current_records")

    # 创建临时结果文件
    local result_file="/tmp/dns_operations_$$"
    > "$result_file"

    # 第一步：异步创建新记录（跳过已存在的IP）
    local create_jobs=()
    local skipped_count=0

    while read -r ip; do
        if [[ -n "$ip" ]]; then
            # 检查IP是否已存在
            if echo "$current_ips" | grep -q "^$ip$"; then
                ((skipped_count++))
                echo "ℹ️ 跳过已存在的DNS记录: $ip -> $domain"
            else
                create_dns_record_async "$domain" "$ip" "$result_file"
                create_jobs+=($!)
            fi
        fi
    done <<< "$best_ips"

    # 第二步：异步删除过时的DNS记录
    local delete_jobs=()
    if [[ -n "$ip_to_id_mapping" ]]; then
        echo "$ip_to_id_mapping" | while IFS=':' read -r ip record_id; do
            if [[ -n "$ip" && -n "$record_id" ]]; then
                # 检查这个IP是否在最优IP列表中
                if ! echo "$best_ips" | grep -q "^$ip$"; then
                    delete_dns_record_async "$record_id" "$domain" "$ip" "$result_file"
                    delete_jobs+=($!)
                fi
            fi
        done
    fi

    # 等待所有异步操作完成
    for job in "${create_jobs[@]}" "${delete_jobs[@]}"; do
        wait "$job" 2>/dev/null || true
    done

    # 统计和显示结果
    local create_success=0
    local create_fail=0
    local delete_success=0
    local delete_fail=0

    if [[ -f "$result_file" ]]; then
        while IFS=':' read -r operation domain ip error_msg; do
            case "$operation" in
                "CREATE_SUCCESS")
                    ((create_success++))
                    echo "✅ 创建DNS记录: $ip -> $domain"
                    ;;
                "CREATE_FAIL")
                    ((create_fail++))
                    echo "❌ 创建DNS记录失败: $ip -> $domain (${error_msg:-Unknown error})"
                    ;;
                "DELETE_SUCCESS")
                    ((delete_success++))
                    echo "✅ 删除DNS记录: $ip -> $domain"
                    ;;
                "DELETE_FAIL")
                    ((delete_fail++))
                    echo "❌ 删除DNS记录失败: $ip -> $domain (${error_msg:-Unknown error})"
                    ;;
            esac
        done < "$result_file"
        rm -f "$result_file"
    fi

    # 显示跳过的记录
    if [[ $skipped_count -gt 0 ]]; then
        echo "ℹ️ 跳过 $skipped_count 个已存在的DNS记录"
    fi

    # 显示操作汇总
    echo ""
    echo "📊 DNS操作汇总:"
    if [[ $create_success -gt 0 ]]; then
        echo "  ✅ $create_success 个创建成功"
    fi
    if [[ $create_fail -gt 0 ]]; then
        echo "  ❌ $create_fail 个创建失败"
    fi
    if [[ $delete_success -gt 0 ]]; then
        echo "  ✅ $delete_success 个删除成功"
    fi
    if [[ $delete_fail -gt 0 ]]; then
        echo "  ❌ $delete_fail 个删除失败"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo "  ℹ️ $skipped_count 个跳过"
    fi
    if [[ $((create_success + create_fail + delete_success + delete_fail + skipped_count)) -eq 0 ]]; then
        echo "  ℹ️ 无操作"
    fi

    # 导出结果供通知使用
    export DNS_CREATE_SUCCESS=$create_success
    export DNS_CREATE_FAIL=$create_fail
    export DNS_DELETE_SUCCESS=$delete_success
    export DNS_DELETE_FAIL=$delete_fail
    export DNS_SKIPPED=$skipped_count

    # 记录变更日志
    log_change_history "$domain" "$best_ips"
}

# 记录变更历史
log_change_history() {
    local domain="$1"
    local ips="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$PROJECT_DIR/logs/ddns-history.log"
    
    # 确保日志目录存在
    mkdir -p "$(dirname "$log_file")"
    
    echo "[$timestamp] 域名: $domain" >> "$log_file"
    echo "$ips" | while read -r ip; do
        if [[ -n "$ip" ]]; then
            echo "[$timestamp]   -> $ip" >> "$log_file"
        fi
    done
    echo "[$timestamp] ---" >> "$log_file"
    
    log_info "变更历史已记录到: $log_file"
}

# 验证配置
validate_config() {
    local errors=0
    
    if [[ -z "$DDNS_DOMAIN" ]]; then
        log_error "DDNS_DOMAIN 未配置"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        log_error "CLOUDFLARE_API_TOKEN 未配置"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$CLOUDFLARE_ZONE_ID" ]]; then
        log_error "CLOUDFLARE_ZONE_ID 未配置"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "配置验证失败，请检查配置文件"
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    # 静默验证配置
    if ! validate_config >/dev/null 2>&1; then
        echo "❌ 配置验证失败，跳过DDNS更新"
        return 1
    fi
    
    # 静默解析测速结果
    if ! parse_speedtest_results >/dev/null 2>&1; then
        echo "❌ 解析测速结果失败，跳过DDNS更新"
        return 1
    fi
    
    # 更新DNS记录
    if update_dns_records "$DDNS_DOMAIN"; then
        return 0
    else
        echo "❌ DDNS更新失败"
        return 1
    fi
}

# 执行主函数
main "$@"