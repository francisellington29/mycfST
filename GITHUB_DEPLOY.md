# 使用GitHub镜像部署指南

## 📦 可用镜像

CI/CD自动构建并推送到两个注册表：

### GitHub Container Registry
```bash
ghcr.io/francisellington29/cloudflare-speedtest:latest
ghcr.io/francisellington29/cloudflare-speedtest:v1.0.0
```

### Docker Hub
```bash
[dockerhub-username]/cloudflare-speedtest:latest
[dockerhub-username]/cloudflare-speedtest:v1.0.0
```

**注意**：需要在GitHub仓库设置中配置以下Secrets：
- `DOCKERHUB_USERNAME` - Docker Hub用户名
- `DOCKERHUB_TOKEN` - Docker Hub访问令牌

## 🚀 快速部署

### 方式1：使用完整配置文件
```bash
# 下载完整配置文件
wget https://raw.githubusercontent.com/francisellington29/mycfST/main/docker-compose.github.yml

# 编辑配置文件，替换必要的环境变量
nano docker-compose.github.yml

# 启动服务
docker-compose -f docker-compose.github.yml up -d
```

### 方式2：使用简化配置文件
```bash
# 下载简化配置文件
wget https://raw.githubusercontent.com/francisellington29/mycfST/main/docker-compose.simple.yml

# 编辑配置文件
nano docker-compose.simple.yml

# 启动服务
docker-compose -f docker-compose.simple.yml up -d
```

### 方式3：直接运行

使用GitHub Container Registry：
```bash
docker run -d \
  --name cloudflare-speedtest \
  --restart unless-stopped \
  -e TZ=Asia/Shanghai \
  -e CRON_SCHEDULE="*/15 * * * *" \
  -e CLOUDFLARE_DOMAIN="your_domain.com" \
  -e CLOUDFLARE_ZONE_ID="your_zone_id_here" \
  -e CLOUDFLARE_API_TOKEN="your_api_token_here" \
  -e TELEGRAM_BOT_TOKEN="your_bot_token_here" \
  -e TELEGRAM_CHAT_ID="your_chat_id_here" \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  ghcr.io/francisellington29/cloudflare-speedtest:latest
```

使用Docker Hub：
```bash
docker run -d \
  --name cloudflare-speedtest \
  --restart unless-stopped \
  -e TZ=Asia/Shanghai \
  -e CRON_SCHEDULE="*/15 * * * *" \
  -e CLOUDFLARE_DOMAIN="your_domain.com" \
  -e CLOUDFLARE_ZONE_ID="your_zone_id_here" \
  -e CLOUDFLARE_API_TOKEN="your_api_token_here" \
  -e TELEGRAM_BOT_TOKEN="your_bot_token_here" \
  -e TELEGRAM_CHAT_ID="your_chat_id_here" \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  [dockerhub-username]/cloudflare-speedtest:latest
```

## ⚙️ 必须配置的环境变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `CLOUDFLARE_DOMAIN` | 要更新的域名 | `cfip.example.com` |
| `CLOUDFLARE_ZONE_ID` | Cloudflare Zone ID | `1234567890abcdef...` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API Token | `abcdef1234567890...` |
| `TELEGRAM_BOT_TOKEN` | Telegram机器人Token | `123456789:ABC...` |
| `TELEGRAM_CHAT_ID` | Telegram聊天ID | `123456789` |

## 📋 常用命令

```bash
# 查看日志
docker-compose -f docker-compose.github.yml logs -f

# 停止服务
docker-compose -f docker-compose.github.yml down

# 更新镜像
docker-compose -f docker-compose.github.yml pull
docker-compose -f docker-compose.github.yml up -d

# 手动执行一次测试
docker-compose -f docker-compose.github.yml exec cloudflare-speedtest /app/start.sh

# 进入容器
docker-compose -f docker-compose.github.yml exec cloudflare-speedtest /bin/bash
```

## 🔧 高级配置

### 自定义IP段文件
```bash
# 创建自定义IP段文件
echo "104.16.0.0/12" > ./ip.txt
echo "172.64.0.0/13" >> ./ip.txt

# 在docker-compose.yml中添加挂载
volumes:
  - ./ip.txt:/app/ip.txt
```

### 使用环境变量文件
```bash
# 创建.env文件
cat > .env << EOF
CLOUDFLARE_DOMAIN=cfip.example.com
CLOUDFLARE_ZONE_ID=your_zone_id_here
CLOUDFLARE_API_TOKEN=your_api_token_here
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
EOF

# 在docker-compose.yml中引用
env_file:
  - .env
```

## 🏗️ 支持的架构

CI/CD自动构建多平台镜像：
- `linux/amd64` - x86_64 (Intel/AMD 64位)
- `linux/arm64` - ARM 64位 (Apple M1, 树莓派4等)
- `linux/arm/v7` - ARM 32位 v7 (树莓派3等)
- `linux/386` - x86 32位

## 🔧 CI/CD配置

### GitHub Secrets配置
在仓库设置中添加以下Secrets：

| Secret名称 | 说明 | 必需 |
|-----------|------|------|
| `DOCKERHUB_USERNAME` | Docker Hub用户名 | ✅ |
| `DOCKERHUB_TOKEN` | Docker Hub访问令牌 | ✅ |

### 自动构建触发条件
- 推送到main分支 → 构建latest标签
- 推送版本标签 → 构建对应版本标签 + 创建GitHub Release
- Pull Request → 仅构建测试，不推送

### 双注册表推送
每次构建会同时推送到：
1. **Docker Hub**: `[username]/cloudflare-speedtest:tag`
2. **GitHub Container Registry**: `ghcr.io/francisellington29/cloudflare-speedtest:tag`

## 📝 注意事项

1. **首次运行**：容器会自动下载CloudflareSpeedTest二进制文件和IP数据库
2. **数据持久化**：建议挂载`/app/data`和`/app/logs`目录
3. **网络要求**：确保容器能够访问Cloudflare API和Telegram API
4. **资源使用**：测速过程会消耗一定的CPU和网络资源
5. **定时任务**：默认每15分钟执行一次，可通过`CRON_SCHEDULE`调整
