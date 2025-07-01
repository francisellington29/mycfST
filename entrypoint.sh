#!/bin/bash

echo "=== CloudflareSpeedTest DDNS 容器启动 ==="

# 加载配置文件
echo "加载配置文件..."
source "config.conf"

# 处理hostname格式，将字符串转换为数组
if [[ $hostname =~ ^\(.*\)$ ]]; then
    # 移除括号并转换为数组
    hostname_clean=$(echo "$hostname" | sed 's/^(//' | sed 's/)$//')
    # 将字符串转换为数组
    IFS=' ' read -ra hostname <<< "$hostname_clean"
fi

echo "初始化完成！"
echo "完整域名: $hostname"

# 检测根域名
if [[ $hostname =~ ^[^.]+\.(.+)$ ]]; then
    root_domain="${BASH_REMATCH[1]}"
    echo "检测到根域名: $root_domain"
else
    echo "无法检测根域名，使用完整域名"
    root_domain="$hostname"
fi

# 显示认证方式
if [ -n "$zone_api_token" ]; then
    echo "使用 Zone API Token 认证"
elif [ -n "$api_token" ] && [ -n "$x_email" ]; then
    echo "使用 Global API Key 认证"
else
    echo "错误：未配置有效的 Cloudflare 认证信息"
    exit 1
fi

# 显示当前配置
echo "当前配置："
echo "  工作模式: $IP_ADDR"
echo "  DNS服务商: $DNS_PROVIDER"
echo "  域名: $hostname"
echo "  定时任务: $ENABLE_CRON ($CRON_SCHEDULE)"

# 启动时执行一次DDNS更新
echo ""
echo "[初次执行] 容器启动，立即执行一次DDNS更新..."
source start.sh
echo "start.sh 执行完成，继续设置定时任务..."

echo ""
echo "=== 设置定时任务 ==="

# 检查是否启用定时任务
if [ "$ENABLE_CRON" = "true" ]; then
    echo "启用定时任务模式，定时间隔: $CRON_SCHEDULE"
    
    # 创建cron任务，start.sh会自己读取容器环境变量
    echo "$CRON_SCHEDULE cd /app && bash start.sh >> /var/log/cron.log 2>&1" > /tmp/crontab
    crontab /tmp/crontab
    
    # 创建日志文件
    touch /var/log/cron.log
    
    echo "定时任务已创建"
    echo "日志文件: /var/log/cron.log"
    
    # 启动cron守护进程（前台模式）
    echo "启动cron守护进程..."
    echo "等待定时任务执行..."
    crond -f
else
    echo "定时任务已禁用，容器将退出"
fi