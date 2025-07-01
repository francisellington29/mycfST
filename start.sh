#!/bin/bash

# 从容器主进程继承环境变量（用于cron任务）
if [ -f /proc/1/environ ]; then
    source <(cat /proc/1/environ | tr '\0' '\n')
fi

# 加载配置文件（config.conf中的变量会从环境变量读取值）
source "config.conf"

# 处理hostname格式，将字符串转换为数组
if [[ $hostname =~ ^\(.*\)$ ]]; then
    # 移除括号并转换为数组
    hostname_clean=$(echo "$hostname" | sed 's/^(//' | sed 's/)$//')
    # 将字符串转换为数组
    IFS=' ' read -ra hostname <<< "$hostname_clean"
fi

# DDNS执行脚本
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始执行 CloudflareSpeedTest DDNS"

# remove the result.csv if exists
if [ -f "cf_ddns/result.csv" ]; then
  rm cf_ddns/result.csv
  echo "已删除旧的测速结果文件"
fi

# 执行核心检查脚本
source ./cf_ddns/cf_check.sh

# 根据DNS服务商执行相应脚本 (暂时注释掉用于测试)
case $DNS_PROVIDER in
    1)
        source ./cf_ddns/cf_ddns_cloudflare_multiple.sh
        ;;
    2)
        source ./cf_ddns/cf_ddns_dnspod.sh
        ;;
    *)
        echo "未选择任何DNS服务商"
        ;;
esac

# 执行推送通知
source ./cf_ddns/cf_push.sh

echo "$(date '+%Y-%m-%d %H:%M:%S') - CloudflareSpeedTest DDNS 执行完成"
echo "start.sh 脚本即将结束，返回到 entrypoint.sh"
