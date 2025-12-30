; ========================================
; Network.asm - 网络联机通信模块
; 服务器: deceric.site:8727
; ========================================

.data
    szServerAddr    db "deceric.site", 0
    
    ; 调试信息字符串
    szDbgInitStart  db "[NET] InitNetwork start...", 13, 10, 0
    szDbgInitOK     db "[NET] InitNetwork OK, return 1", 13, 10, 0
    szDbgInitFail   db "[NET] InitNetwork FAILED, WSAStartup error: %d", 13, 10, 0
    szDbgHostStart  db "[NET] HostGame: Connecting to relay server as Host...", 13, 10, 0
    szDbgJoinStart  db "[NET] JoinGame: Connecting to relay server as Client...", 13, 10, 0
    szDbgJoinSocket db "[NET] Socket created: %d", 13, 10, 0
    szDbgJoinAddr   db "[NET] Resolving %s...", 13, 10, 0
    szDbgJoinAddrOK db "[NET] Resolved to: %d.%d.%d.%d (0x%08X)", 13, 10, 0
    szDbgJoinAddrFail db "[NET] DNS resolution failed for %s", 13, 10, 0
    szDbgJoinConn   db "[NET] Connecting to %d.%d.%d.%d:%d...", 13, 10, 0
    szDbgJoinConnRes db "[NET] Connect result: %d, WSAError: %d", 13, 10, 0
    szDbgJoinOK     db "[NET] Connected to relay server! (return 1)", 13, 10, 0
    szDbgJoinFail   db "[NET] Connection failed! (return 0)", 13, 10, 0

.data?
    wsaData         db 400 dup(?)
    serverSocket    dd ?
    clientSocket    dd ?
    serverAddr      db 16 dup(?)
    recvBuffer      db NET_BUFFER_SIZE dup(?)
    sendBuffer      db NET_BUFFER_SIZE dup(?)
    nonBlockMode    dd ?
    tempAddrSize    dd ?

.code

; ========================================
; InitNetwork - 初始化 Winsock
; ========================================
InitNetwork proc
    invoke crt_printf, ADDR szDbgInitStart
    
    ; 初始化套接字变量
    mov serverSocket, INVALID_SOCKET
    mov clientSocket, INVALID_SOCKET
    
    ; 初始化 Winsock
    invoke WSAStartup, 0202h, addr wsaData
    mov wsaStartupError, eax
    test eax, eax
    jnz short InitFailed
    
    invoke crt_printf, ADDR szDbgInitOK
    mov eax, 1
    ret
    
InitFailed:
    invoke crt_printf, ADDR szDbgInitFail, eax
    xor eax, eax
    ret
InitNetwork endp

; ========================================
; CleanupNetwork - 清理网络资源
; ========================================
CleanupNetwork proc
    cmp serverSocket, 0
    je short CleanClient
    cmp serverSocket, -1
    je short CleanClient
    invoke closesocket, serverSocket
    mov serverSocket, -1
CleanClient:
    cmp clientSocket, 0
    je short DoWSACleanup
    cmp clientSocket, -1
    je short DoWSACleanup
    invoke closesocket, clientSocket
    mov clientSocket, -1
DoWSACleanup:
    invoke WSACleanup
    ret
CleanupNetwork endp

; ========================================
; HostGame - 作为主机启动游戏（连接到中继服务器）
; ========================================
HostGame proc
    invoke crt_printf, ADDR szDbgHostStart
    
    ; 直接调用JoinGame连接到服务器
    invoke JoinGame, 0
    ret
HostGame endp

; ========================================
; JoinGame - 作为客户端加入游戏
; ========================================
JoinGame proc serverIP:DWORD
    LOCAL sock:DWORD
    
    invoke crt_printf, ADDR szDbgJoinStart
    
    invoke socket, 2, 1, 6
    mov sock, eax
    push eax
    invoke crt_printf, ADDR szDbgJoinSocket, eax
    pop eax
    cmp eax, -1
    je JoinFailed
    
    lea edi, serverAddr
    mov word ptr [edi], 2
    invoke htons, NET_PORT
    mov word ptr [edi+2], ax
    
    mov eax, serverIP
    test eax, eax
    jnz short JoinParseAddr
    lea eax, szServerAddr
    
JoinParseAddr:
    push eax
    invoke crt_printf, ADDR szDbgJoinAddr, eax
    pop eax
    
    ; 先尝试用gethostbyname解析域名
    invoke gethostbyname, eax
    test eax, eax
    jz JoinAddrFailed
    
    ; 从hostent结构获取IP地址
    mov esi, eax
    mov esi, [esi+12]  ; h_addr_list
    mov esi, [esi]     ; 第一个地址
    test esi, esi
    jz JoinAddrFailed
    mov eax, [esi]     ; 获取IP地址（已经是网络字节序）
    
    ; 显示解析的IP地址
    push eax
    mov ebx, eax
    movzx ecx, bl
    push ecx
    shr ebx, 8
    movzx ecx, bl
    push ecx
    shr ebx, 8
    movzx ecx, bl
    push ecx
    shr ebx, 8
    movzx ecx, bl
    push ecx
    push eax
    invoke crt_printf, ADDR szDbgJoinAddrOK
    add esp, 20
    pop eax
    
    lea edi, serverAddr
    mov dword ptr [edi+4], eax
    
    ; 显示正在连接的地址
    push eax
    mov ebx, eax
    push NET_PORT
    movzx ecx, bl
    push ecx
    shr ebx, 8
    movzx ecx, bl
    push ecx
    shr ebx, 8
    movzx ecx, bl
    push ecx
    shr ebx, 8
    movzx ecx, bl
    push ecx
    invoke crt_printf, ADDR szDbgJoinConn
    add esp, 20
    pop eax
    
    invoke connect, sock, addr serverAddr, 16
    mov ecx, eax  ; 保存connect结果
    push ecx
    invoke WSAGetLastError
    invoke crt_printf, ADDR szDbgJoinConnRes, ecx, eax
    pop ecx
    cmp ecx, -1
    je JoinConnFailed
    
    mov eax, sock
    mov clientSocket, eax
    mov nonBlockMode, 1
    invoke ioctlsocket, clientSocket, 8004667Eh, addr nonBlockMode
    invoke crt_printf, ADDR szDbgJoinOK
    mov eax, 1
    ret
    
JoinConnFailed:
    invoke closesocket, sock
    invoke crt_printf, ADDR szDbgJoinFail
    xor eax, eax
    ret
    
JoinAddrFailed:
    push eax
    invoke crt_printf, ADDR szDbgJoinAddrFail, ADDR szServerAddr
    pop eax
    invoke closesocket, sock
    invoke crt_printf, ADDR szDbgJoinFail
    xor eax, eax
    ret
    
JoinFailed:
    invoke crt_printf, ADDR szDbgJoinFail
    xor eax, eax
    ret
JoinGame endp

; ========================================
; SendTankUpdate - 发送坦克状态更新
; ========================================
SendTankUpdate proc uses esi edi pTank:DWORD
    LOCAL msgBuf[520]:BYTE
    LOCAL packet[16]:BYTE
    
    mov eax, clientSocket
    test eax, eax
    jz short SendTankFailed
    cmp eax, -1
    je short SendTankFailed
    
    mov esi, pTank
    mov eax, [esi]
    lea edi, packet
    mov [edi], eax
    mov eax, [esi+4]
    mov [edi+4], eax
    mov eax, [esi+8]
    mov [edi+8], eax
    mov eax, [esi+20]
    mov [edi+12], eax
    
    lea edi, msgBuf
    mov dword ptr [edi], MSG_TANK_UPDATE
    mov dword ptr [edi+4], 16
    
    lea esi, packet
    add edi, 8
    mov ecx, 16
    rep movsb
    
    invoke send, clientSocket, addr msgBuf, 24, 0
    cmp eax, -1
    je short SendTankFailed
    mov eax, 1
    ret
    
SendTankFailed:
    xor eax, eax
    ret
SendTankUpdate endp

; ========================================
; ReceiveNetworkData - 接收网络数据
; ========================================
ReceiveNetworkData proc
    LOCAL msgBuf[520]:BYTE
    LOCAL bytesRead:DWORD
    
    mov eax, clientSocket
    test eax, eax
    jz short RecvFailed
    cmp eax, -1
    je short RecvFailed
    
    invoke recv, clientSocket, addr msgBuf, 520, 0
    mov bytesRead, eax
    cmp eax, -1
    je short RecvFailed
    test eax, eax
    jz short RecvClosed
    
    lea esi, msgBuf
    mov eax, [esi]
    cmp eax, MSG_DISCONNECT
    jne short RecvReturn
    call DisconnectNetwork
    
RecvReturn:
    lea esi, msgBuf
    mov eax, [esi]
    ret
    
RecvClosed:
    mov eax, -1
    ret
    
RecvFailed:
    xor eax, eax
    ret
ReceiveNetworkData endp

; ========================================
; SendBulletFired - 发送子弹发射信息
; ========================================
SendBulletFired proc uses esi edi posX:DWORD, posY:DWORD, angle:DWORD
    LOCAL msgBuf[520]:BYTE
    
    mov eax, clientSocket
    test eax, eax
    jz short SendBulletFailed
    cmp eax, -1
    je short SendBulletFailed
    
    lea edi, msgBuf
    mov dword ptr [edi], MSG_FIRE_BULLET
    mov dword ptr [edi+4], 12
    mov eax, posX
    mov [edi+8], eax
    mov eax, posY
    mov [edi+12], eax
    mov eax, angle
    mov [edi+16], eax
    
    invoke send, clientSocket, addr msgBuf, 20, 0
    cmp eax, -1
    je short SendBulletFailed
    mov eax, 1
    ret
    
SendBulletFailed:
    xor eax, eax
    ret
SendBulletFired endp

; ========================================
; DisconnectNetwork - 断开网络连接
; ========================================
DisconnectNetwork proc
    LOCAL msgBuf[520]:BYTE
    
    mov eax, clientSocket
    test eax, eax
    jz short DisconnCleanup
    cmp eax, -1
    je short DisconnCleanup
    
    lea edi, msgBuf
    mov dword ptr [edi], MSG_DISCONNECT
    mov dword ptr [edi+4], 0
    invoke send, clientSocket, addr msgBuf, 8, 0
    
DisconnCleanup:
    call CleanupNetwork
    ret
DisconnectNetwork endp
