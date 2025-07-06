#!/bin/bash

# 设置错误时退出（但允许某些命令失败）
set -e

# 加载常量定义
source /app/constants.sh

log_message "INFO" "CloudflareSpeedTest Docker 容器启动"
log_message "INFO" "时区: $TZ"
log_message "INFO" "架构: $(uname -m)"

# 获取定时任务配置
CRON_SCHEDULE=${CRON_SCHEDULE:-"*/15 * * * *"}

# 更新crontab配置
log_message "INFO" "配置定时任务: $CRON_SCHEDULE"
echo "$CRON_SCHEDULE /app/start.sh >> $CRON_LOG_FILE 2>&1" > /etc/crontabs/root

# 确保cron日志文件存在
touch "$CRON_LOG_FILE"

# 启动cron服务（降低日志级别减少输出）
log_message "INFO" "启动cron服务..."
crond -f -d 0 &

# 执行一次初始测试（允许失败，不影响容器运行）
log_message "INFO" "执行初始测试..."
set +e  # 临时允许命令失败
if /app/start.sh; then
    log_message "INFO" "初始测试成功完成"
else
    log_message "WARN" "初始测试失败，但容器将继续运行等待定时任务"
fi
set -e  # 恢复错误时退出

# 容器启动完成
log_message "INFO" "容器启动完成，定时任务: $CRON_SCHEDULE"

# 确保日志文件存在
if [[ ! -f "$CRON_LOG_FILE" ]]; then
    touch "$CRON_LOG_FILE"
fi

# 保持容器运行并显示日志
log_message "INFO" "开始监控日志文件..."
tail -f "$CRON_LOG_FILE"
