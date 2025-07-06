FROM alpine:3.20

# 设置工作目录
WORKDIR /app

# 安装必要的软件包
RUN apk add --no-cache \
    curl \
    wget \
    ca-certificates \
    tzdata \
    bash \
    dcron \
    && rm -rf /var/cache/apk/*

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建必要的目录
RUN mkdir -p /app /var/log/cron

# 注意：CloudflareSpeedTest 和 qqwry.dat 将在容器启动时根据架构动态下载

# 复制脚本
COPY *.sh /app/

# 设置执行权限
RUN chmod +x /app/*.sh

# 创建日志文件
RUN touch /var/log/cron/cron.log

# 启动脚本
ENTRYPOINT ["./entrypoint.sh"]
