# 坦克大战联机对战服务器配置指南

## 服务器信息
- **域名**: deceric.site
- **端口**: 8727
- **协议**: TCP (Winsock)

## 网络架构

### 1. 对等连接模式 (P2P)
游戏使用点对点连接，一个玩家作为主机(Host)，另一个玩家作为客户端(Client)连接。

```
┌─────────────┐                    ┌─────────────┐
│  玩家 1     │◄──────TCP──────────►│  玩家 2     │
│  (主机)     │   deceric.site:8727 │  (客户端)   │
└─────────────┘                    └─────────────┘
```

### 2. 服务器要求

#### 防火墙配置
在服务器上打开端口 8727 的 TCP 访问：

**Linux (iptables):**
```bash
sudo iptables -A INPUT -p tcp --dport 8727 -j ACCEPT
sudo iptables-save
```

**Linux (firewalld):**
```bash
sudo firewall-cmd --permanent --add-port=8727/tcp
sudo firewall-cmd --reload
```

**Windows:**
```powershell
New-NetFirewallRule -DisplayName "Tank Game Server" -Direction Inbound -Protocol TCP -LocalPort 8727 -Action Allow
```

#### 端口转发
如果使用路由器，需要配置端口转发将 8727 转发到服务器内网IP。

## 游戏网络协议

### 消息类型
| 类型 | 值 | 说明 |
|------|----|----|
| MSG_CONNECT | 1 | 连接握手 |
| MSG_TANK_UPDATE | 2 | 坦克状态同步 |
| MSG_FIRE_BULLET | 3 | 子弹发射事件 |
| MSG_GAME_STATE | 4 | 游戏状态同步 |
| MSG_DISCONNECT | 5 | 断开连接 |

### 数据包结构

#### 通用消息格式
```c
struct NET_MSG {
    DWORD msgType;      // 消息类型
    DWORD dataLen;      // 数据长度
    BYTE data[512];     // 数据内容
}
```

#### 坦克状态数据包
```c
struct TANK_PACKET {
    DWORD pos_x;        // X坐标 (定点数 * 256)
    DWORD pos_y;        // Y坐标 (定点数 * 256)
    DWORD angle;        // 角度 (0-359)
    DWORD active;       // 是否存活
}
```

#### 子弹发射数据包
```c
struct BULLET_PACKET {
    DWORD pos_x;        // 发射位置 X
    DWORD pos_y;        // 发射位置 Y
    DWORD angle;        // 发射角度
}
```

## 使用说明

### 主机模式 (Host Game)
1. 在主菜单选择 "NETWORK GAME"
2. 按 'H' 键作为主机
3. 游戏会在本机启动服务器并等待连接
4. 显示 "Waiting for opponent..."
5. 当客户端连接后自动开始游戏

### 客户端模式 (Join Game)
1. 在主菜单选择 "NETWORK GAME"
2. 按 'J' 键作为客户端
3. 输入服务器地址 (默认: deceric.site)
4. 显示 "Connecting to server..."
5. 连接成功后显示 "Connected!" 并开始游戏

### 网络同步机制

#### 发送频率
- 坦克状态: 每帧发送 (60Hz)
- 子弹发射: 事件触发时立即发送
- 游戏状态: 按需发送

#### 延迟补偿
- 使用非阻塞套接字避免游戏卡顿
- 客户端预测本地玩家动作
- 服务器权威确认游戏状态

## 服务器部署示例

### 使用 Node.js 中继服务器 (可选)
如果需要 NAT 穿透或中继连接，可以部署中继服务器：

```javascript
// relay-server.js
const net = require('net');

const PORT = 8727;
const clients = new Map();

const server = net.createServer((socket) => {
    console.log('New connection');
    
    let playerId = clients.size;
    clients.set(playerId, socket);
    
    socket.on('data', (data) => {
        // 转发给其他玩家
        clients.forEach((client, id) => {
            if (id !== playerId) {
                client.write(data);
            }
        });
    });
    
    socket.on('close', () => {
        clients.delete(playerId);
        console.log('Client disconnected');
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Tank Game Relay Server running on port ${PORT}`);
});
```

运行服务器：
```bash
node relay-server.js
```

### 使用 systemd 自动启动 (Linux)

创建服务文件 `/etc/systemd/system/tankgame-relay.service`:

```ini
[Unit]
Description=Tank Game Relay Server
After=network.target

[Service]
Type=simple
User=tankgame
WorkingDirectory=/opt/tankgame
ExecStart=/usr/bin/node /opt/tankgame/relay-server.js
Restart=always

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
sudo systemctl enable tankgame-relay
sudo systemctl start tankgame-relay
```

## 测试连接

### 测试端口是否开放
```bash
# Linux/Mac
nc -zv deceric.site 8727

# Windows PowerShell
Test-NetConnection -ComputerName deceric.site -Port 8727
```

### 监听连接日志
```bash
# Linux
sudo tcpdump -i any port 8727

# 或使用 ss
ss -tulpn | grep 8727
```

## 故障排除

### 连接失败
1. 检查防火墙设置
2. 确认端口未被占用
3. 检查服务器网络可达性
4. 查看 DNS 解析是否正确

```bash
# 测试 DNS
nslookup deceric.site

# 测试连通性
ping deceric.site
```

### 游戏延迟过高
1. 使用 ping 测试网络延迟
2. 检查服务器带宽
3. 考虑使用地理位置更近的服务器

### 连接中断
1. 检查网络稳定性
2. 确认防火墙未中断长连接
3. 考虑实现心跳包机制

## 安全建议

1. **限制连接数**: 每个主机只允许一个客户端连接
2. **数据验证**: 验证接收到的数据包格式
3. **防DDoS**: 使用 iptables 限制连接速率
4. **加密通信**: 考虑使用 TLS/SSL (需要修改代码)

```bash
# 限制连接速率
sudo iptables -A INPUT -p tcp --dport 8727 -m state --state NEW -m limit --limit 5/min -j ACCEPT
```

## 性能优化

1. **批量发送**: 合并多个小消息减少网络开销
2. **差异更新**: 只发送变化的数据
3. **压缩**: 对大数据包进行压缩
4. **优先级队列**: 关键消息优先发送

## 扩展功能建议

- [ ] 房间匹配系统
- [ ] 排行榜记录
- [ ] 聊天功能
- [ ] 观战模式
- [ ] 录像回放
- [ ] 多人对战 (4人模式)

## 联系方式

如有问题或建议，请联系开发团队。

---
**最后更新**: 2025年12月30日
