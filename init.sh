#!/bin/bash

# CloudflareSpeedTest 初始化脚本
# 负责下载 CloudflareSpeedTest 二进制文件和 IP 地理位置数据库

set -e

# 加载常量定义
source /app/constants.sh

log_message "INFO" "CloudflareSpeedTest 初始化开始"

# 切换到工作目录
cd "$APP_DIR"

# 确保CloudflareST目录存在
ensure_directory "$CLOUDFLARE_ST_DIR"
cd "$CLOUDFLARE_ST_DIR"

# 获取配置参数
CLOUDFLARE_ST_VERSION_ENV=${CLOUDFLARE_ST_VERSION_ENV:-"$CLOUDFLARE_ST_VERSION"}
GITHUB_PROXY_URL=${GITHUB_PROXY_URL}
FORCE_REDOWNLOAD_LOCATION=${FORCE_REDOWNLOAD_LOCATION:-"false"}

# 构建下载地址
CLOUDFLARE_ST_DOWNLOAD_URL=$(build_download_url "$CLOUDFLARE_ST_VERSION_ENV")
QQWRY_DOWNLOAD_URL="$QQWRY_DOWNLOAD_URL_BASE"

# 如果设置了GitHub代理，应用代理
if [[ -n "$GITHUB_PROXY_URL" ]]; then
    log_message "INFO" "使用GitHub代理: $GITHUB_PROXY_URL"
    CLOUDFLARE_ST_DOWNLOAD_URL=$(apply_github_proxy "$CLOUDFLARE_ST_DOWNLOAD_URL" "$GITHUB_PROXY_URL")
    QQWRY_DOWNLOAD_URL=$(apply_github_proxy "$QQWRY_DOWNLOAD_URL" "$GITHUB_PROXY_URL")
fi

log_message "INFO" "1. 检查 CloudflareSpeedTest 二进制文件"

# 检查CloudflareSpeedTest二进制文件是否存在
if ! validate_file "$CLOUDFLARE_ST_BINARY"; then
    log_message "INFO" "CloudflareSpeedTest二进制文件不存在，正在下载..."

    # 检查架构支持
    if ! is_arch_supported; then
        log_message "ERROR" "不支持的架构: $(uname -m)"
        exit $EXIT_DOWNLOAD_ERROR
    fi

    arch=$(uname -m)
    arch_id=$(get_arch_identifier)
    log_message "INFO" "检测到架构: $arch ($arch_id)"
    log_message "INFO" "下载地址: $CLOUDFLARE_ST_DOWNLOAD_URL"

    # 下载并解压
    temp_file="CloudflareST.tar.gz"
    if wget -q -O "$temp_file" "$CLOUDFLARE_ST_DOWNLOAD_URL"; then
        log_message "INFO" "下载成功，正在解压..."
        if tar -xzf "$temp_file"; then
            chmod +x CloudflareST
            cleanup_temp_files "$temp_file"
            log_message "INFO" "CloudflareSpeedTest 安装完成"

            # 验证二进制文件
            if "$CLOUDFLARE_ST_BINARY" -v >/dev/null 2>&1; then
                log_message "INFO" "CloudflareSpeedTest 验证成功"
            else
                log_message "ERROR" "CloudflareSpeedTest 验证失败"
                exit $EXIT_DOWNLOAD_ERROR
            fi
        else
            log_message "ERROR" "解压失败"
            cleanup_temp_files "$temp_file"
            exit $EXIT_DOWNLOAD_ERROR
        fi
    else
        log_message "ERROR" "下载失败"
        cleanup_temp_files "$temp_file"
        exit $EXIT_DOWNLOAD_ERROR
    fi
else
    log_message "INFO" "CloudflareSpeedTest 已存在，跳过下载"
    # 验证现有文件
    if "$CLOUDFLARE_ST_BINARY" -v >/dev/null 2>&1; then
        log_message "INFO" "现有 CloudflareSpeedTest 验证成功"
    else
        log_message "WARN" "现有 CloudflareSpeedTest 验证失败，重新下载..."
        rm -f "$CLOUDFLARE_ST_BINARY"
        exec "$0" "$@"  # 重新执行脚本
    fi
fi

log_message "INFO" "2. 检查 IP 地理位置数据库"

# 检查IP数据库是否存在或是否需要强制重新下载
if [[ "$FORCE_REDOWNLOAD_LOCATION" == "true" ]] || ! validate_file "$QQWRY_DATABASE" "$MIN_QQWRY_SIZE"; then
    if [[ "$FORCE_REDOWNLOAD_LOCATION" == "true" ]]; then
        log_message "INFO" "强制重新下载IP地理位置数据库..."
        rm -f "$QQWRY_DATABASE"
    fi
    log_message "INFO" "IP地理位置数据库不存在，正在下载..."
    log_message "INFO" "下载地址: $QQWRY_DOWNLOAD_URL"

    if wget -q -O "$QQWRY_DATABASE" "$QQWRY_DOWNLOAD_URL"; then
        log_message "INFO" "IP地理位置数据库下载完成"

        # 验证文件大小
        if validate_file "$QQWRY_DATABASE" "$MIN_QQWRY_SIZE"; then
            file_size=$(stat -c%s "$QQWRY_DATABASE" 2>/dev/null || echo "0")
            log_message "INFO" "IP地理位置数据库验证成功 (大小: ${file_size} 字节)"
        else
            file_size=$(stat -c%s "$QQWRY_DATABASE" 2>/dev/null || echo "0")
            log_message "ERROR" "IP地理位置数据库文件异常，大小: ${file_size} 字节"
            rm -f "$QQWRY_DATABASE"
            exit $EXIT_DOWNLOAD_ERROR
        fi
    else
        log_message "ERROR" "IP地理位置数据库下载失败"
        exit $EXIT_DOWNLOAD_ERROR
    fi
else
    log_message "INFO" "IP地理位置数据库已存在，跳过下载"

    # 验证现有文件
    if validate_file "$QQWRY_DATABASE" "$MIN_QQWRY_SIZE"; then
        file_size=$(stat -c%s "$QQWRY_DATABASE" 2>/dev/null || echo "0")
        log_message "INFO" "现有IP地理位置数据库验证成功 (大小: ${file_size} 字节)"
    else
        log_message "WARN" "现有IP地理位置数据库文件异常，重新下载..."
        rm -f "$QQWRY_DATABASE"
        exec "$0" "$@"  # 重新执行脚本
    fi
fi

log_message "INFO" "3. 检查 IP 段数据文件"

# 检查IP数据文件状态
if [[ -f "$IPV4_DATA_FILE" ]]; then
    log_message "INFO" "IPv4 数据文件已存在: $IPV4_DATA_FILE"
else
    log_message "INFO" "IPv4 数据文件不存在: $IPV4_DATA_FILE"
fi

if [[ -f "$IPV6_DATA_FILE" ]]; then
    log_message "INFO" "IPv6 数据文件已存在: $IPV6_DATA_FILE"
else
    log_message "INFO" "IPv6 数据文件不存在: $IPV6_DATA_FILE"
fi

echo ""
echo "🎉 CloudflareSpeedTest 初始化完成"
echo "📋 组件状态:"
echo "  🔧 CloudflareST: $(validate_file "$CLOUDFLARE_ST_BINARY" && echo '✅ 已安装' || echo '❌ 未安装')"
echo "  📍 qqwry.dat: $(validate_file "$QQWRY_DATABASE" "$MIN_QQWRY_SIZE" && echo '✅ 已安装' || echo '❌ 未安装')"
echo "  📊 IPv4数据: $(validate_file "$IPV4_DATA_FILE" && echo '✅ 已存在' || echo '❌ 不存在')"
echo "  📊 IPv6数据: $(validate_file "$IPV6_DATA_FILE" && echo '✅ 已存在' || echo '❌ 不存在')"
echo ""

exit $EXIT_SUCCESS
