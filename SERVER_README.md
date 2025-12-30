# Tank Game Online Server

坦克大战联机对战中继服务器

## 快速开始

### 1. 安装 Node.js
确保已安装 Node.js (v14+)

### 2. 启动服务器
```bash
node relay-server.js
```

### 3. 测试连接
```bash
# Windows PowerShell
Test-NetConnection -ComputerName localhost -Port 8727

# Linux/Mac
nc -zv localhost 8727
```

## 服务器配置

编辑 `relay-server.js` 修改配置：
- `PORT`: 服务器端口 (默认 8727)
- 客户端限制: 最多 2 个连接
- 超时时间: 5 分钟

## 部署到 deceric.site

### 方法 1: 直接部署
```bash
# 上传文件到服务器
scp relay-server.js user@deceric.site:/opt/tankgame/

# SSH 连接到服务器
ssh user@deceric.site

# 安装 Node.js (如果还没有)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 运行服务器
cd /opt/tankgame
node relay-server.js
```

### 方法 2: 使用 systemd (推荐)
创建 `/etc/systemd/system/tankgame.service`:

```ini
[Unit]
Description=Tank Game Relay Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/tankgame
ExecStart=/usr/bin/node relay-server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable tankgame
sudo systemctl start tankgame
sudo systemctl status tankgame
```

查看日志：
```bash
sudo journalctl -u tankgame -f
```

### 方法 3: 使用 Docker
创建 `Dockerfile`:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY relay-server.js .
EXPOSE 8727
CMD ["node", "relay-server.js"]
```

构建并运行：
```bash
docker build -t tankgame-server .
docker run -d -p 8727:8727 --name tankgame --restart always tankgame-server
```

## 防火墙配置

### Ubuntu/Debian
```bash
sudo ufw allow 8727/tcp
sudo ufw reload
```

### CentOS/RHEL
```bash
sudo firewall-cmd --permanent --add-port=8727/tcp
sudo firewall-cmd --reload
```

## 监控和维护

### 检查服务状态
```bash
sudo systemctl status tankgame
```

### 查看实时日志
```bash
sudo journalctl -u tankgame -f
```

### 重启服务
```bash
sudo systemctl restart tankgame
```

### 监控端口
```bash
sudo ss -tulpn | grep 8727
```

## 性能优化

### 1. 增加文件描述符限制
编辑 `/etc/security/limits.conf`:
```
* soft nofile 65536
* hard nofile 65536
```

### 2. 调整 TCP 参数
编辑 `/etc/sysctl.conf`:
```
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
```

应用更改：
```bash
sudo sysctl -p
```

## 故障排除

### 端口被占用
```bash
# 查看占用端口的进程
sudo lsof -i :8727
# 或
sudo netstat -tulpn | grep 8727

# 终止进程
sudo kill -9 <PID>
```

### 服务无法启动
检查日志：
```bash
sudo journalctl -u tankgame -n 50
```

检查权限：
```bash
ls -la /opt/tankgame/
```

### 客户端无法连接
1. 检查防火墙
2. 检查服务是否运行
3. 测试端口连通性
4. 检查 DNS 解析

## 安全建议

1. **使用防火墙**: 只开放必要端口
2. **限流**: 防止 DDoS 攻击
3. **监控**: 设置日志监控和告警
4. **备份**: 定期备份配置
5. **更新**: 保持 Node.js 和系统更新

## 高级功能

### 添加 SSL/TLS
使用 `tls` 模块替代 `net` 模块实现加密通信

### 添加认证
实现用户认证机制验证客户端身份

### 负载均衡
使用 Nginx 或 HAProxy 进行负载均衡

## 联系支持

有问题请查看主文档 `server_config.md`
