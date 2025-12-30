const net = require('net');

const PORT = 8727;
const clients = new Map();

console.log('Tank Game Relay Server v1.0');
console.log('==============================');

const server = net.createServer((socket) => {
    const clientAddr = `${socket.remoteAddress}:${socket.remotePort}`;
    console.log(`\n[${new Date().toISOString()}] ==================== NEW CONNECTION ====================`);
    console.log(`[CONN] Client address: ${clientAddr}`);
    console.log(`[CONN] Current clients before: ${clients.size}`);
    
    let playerId = clients.size;
    clients.set(playerId, {
        socket: socket,
        address: clientAddr,
        connectedAt: new Date()
    });
    
    console.log(`[CONN] Assigned Player ID: ${playerId}`);
    console.log(`[INFO] Total clients: ${clients.size}`);
    
    // 限制最多2个客户端
    if (clients.size > 2) {
        console.log(`[REJECT] Too many clients (${clients.size}), rejecting ${clientAddr}`);
        socket.write('Server full');
        socket.end();
        clients.delete(playerId);
        return;
    }
    
    console.log(`[ACCEPT] Client ${playerId} accepted`);
    
    // 如果达到2个玩家，通知双方游戏开始
    if (clients.size === 2) {
        console.log(`[GAME] Both players connected! Starting game...`);
        clients.forEach((client, id) => {
            console.log(`[NOTIFY] Sending MSG_CONNECT to player ${id}`);
            client.socket.write(Buffer.from([1, 0, 0, 0])); // MSG_CONNECT
        });
    }
    
    socket.on('data', (data) => {
        const msgType = data.length > 0 ? data[0] : -1;
        const msgTypeStr = ['UNKNOWN', 'CONNECT', 'TANK_UPDATE', 'FIRE_BULLET', 'GAME_STATE', 'DISCONNECT', 'MAP_DATA'][msgType] || 'INVALID';
        console.log(`[RECV] Player ${playerId} sent ${data.length} bytes, MsgType=${msgType}(${msgTypeStr})`);
        
        // 转发给其他玩家
        let forwardCount = 0;
        clients.forEach((client, id) => {
            if (id !== playerId) {
                try {
                    client.socket.write(data);
                    forwardCount++;
                    console.log(`[FORWARD] Sent ${data.length} bytes from Player ${playerId} to Player ${id}`);
                } catch (err) {
                    console.error(`[ERROR] Failed to forward to client ${id}: ${err.message}`);
                }
            }
        });
        
        if (forwardCount === 0) {
            console.log(`[WARN] No other clients to forward to`);
        }
    });
    
    socket.on('error', (err) => {
        console.error(`[ERROR] Socket error for Player ${playerId} (${clientAddr}): ${err.message}`);
    });
    
    socket.on('close', () => {
        console.log(`\n[${new Date().toISOString()}] ==================== DISCONNECTION ====================`);
        console.log(`[DISC] Player ${playerId} (${clientAddr}) disconnected`);
        clients.delete(playerId);
        console.log(`[INFO] Total clients: ${clients.size}`);
        
        // 通知其他玩家
        clients.forEach((client, id) => {
            try {
                console.log(`[NOTIFY] Sending MSG_DISCONNECT to player ${id}`);
                client.socket.write(Buffer.from([5, 0, 0, 0])); // MSG_DISCONNECT
            } catch (err) {
                console.error(`[ERROR] Failed to notify disconnect: ${err.message}`);
            }
        });
    });
    
    socket.setTimeout(300000); // 5分钟超时
    socket.on('timeout', () => {
        console.log(`[TIMEOUT] Player ${playerId} (${clientAddr}) timeout after 5 minutes`);
        socket.end();
    });
});

// 每30秒显示状态
setInterval(() => {
    if (clients.size > 0) {
        console.log(`\n[STATUS] ==================== Server Status ====================`);
        console.log(`[STATUS] Active connections: ${clients.size}`);
        clients.forEach((client, id) => {
            const duration = Math.floor((new Date() - client.connectedAt) / 1000);
            console.log(`[STATUS]   - Player ${id}: ${client.address} (${duration}s)`);
        });
        console.log(`=============================================================\n`);
    }
}, 30000);

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`\n[FATAL] Port ${PORT} is already in use`);
        console.error(`[FATAL] Please close the other application or change the port`);
    } else {
        console.error(`\n[FATAL] Server error: ${err.message}`);
    }
    process.exit(1);
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n[${new Date().toISOString()}] ===============================================`);
    console.log(`[START] Tank Game Relay Server started`);
    console.log(`[START] Listening on 0.0.0.0:${PORT}`);
    console.log(`[START] Ready to accept up to 2 clients`);
    console.log(`===============================================\n`);
});

// 优雅退出
process.on('SIGINT', () => {
    console.log('\n[SHUTDOWN] Received SIGINT, shutting down server...');
    clients.forEach((client, id) => {
        try {
            console.log(`[SHUTDOWN] Disconnecting player ${id}`);
            client.socket.write(Buffer.from([5, 0, 0, 0])); // MSG_DISCONNECT
            client.socket.end();
        } catch (err) {
            console.error(`[SHUTDOWN] Error disconnecting player ${id}: ${err.message}`);
        }
    });
    server.close(() => {
        console.log('[SHUTDOWN] Server closed gracefully');
        process.exit(0);
    });
});

// 状态报告
setInterval(() => {
    if (clients.size > 0) {
        console.log(`[STATUS] Active connections: ${clients.size}`);
        clients.forEach((client, id) => {
            const uptime = Math.floor((Date.now() - client.connectedAt) / 1000);
            console.log(`  - Client ${id}: ${client.address} (${uptime}s)`);
        });
    }
}, 60000); // 每分钟报告一次
