; ========================================
; Menu.asm - 菜单和游戏状态管理
; ========================================

; --- 菜单输入处理 ---
HandleMenuInput proc
    invoke GetAsyncKeyState, VK_UP
    test ax, 8000h
    jz @CheckDown
    
    ; 防止重复触发
    mov eax, menuAnimTick
    .if eax == 0
        dec menuSelection
        .if SDWORD PTR menuSelection < 0
            mov menuSelection, 1
        .endif
        mov menuAnimTick, 10
    .endif

@CheckDown:
    invoke GetAsyncKeyState, VK_DOWN
    test ax, 8000h
    jz @CheckEnter
    
    mov eax, menuAnimTick
    .if eax == 0
        inc menuSelection
        .if menuSelection > MENU_QUIT
            mov menuSelection, 0
        .endif
        mov menuAnimTick, 10
    .endif

@CheckEnter:
    invoke GetAsyncKeyState, VK_RETURN
    test ax, 8000h
    jz @UpdateAnim
    
    mov eax, menuAnimTick
    .if eax == 0
        mov eax, menuSelection
        .if eax == MENU_START
            ; 开始本地对战游戏
            mov gameState, STATE_PLAYING
            mov networkMode, NET_MODE_OFFLINE
            call InitGame
            mov menuAnimTick, 30
            jmp @UpdateAnim
        .elseif eax == MENU_NETWORK
            ; 进入联机模式菜单
            mov gameState, STATE_NETWORK_MENU
            mov menuSelection, 0
            ; 初始化网络
            call InitNetwork
            mov networkInitOK, eax
            mov wsaStartupError, 0
            mov menuAnimTick, 30
            jmp @UpdateAnim
        .elseif eax == MENU_QUIT
            ; 退出游戏
            invoke PostQuitMessage, 0
        .endif
        mov menuAnimTick, 20
    .endif

@UpdateAnim:
    ; 更新动画计数器
    mov eax, menuAnimTick
    .if eax > 0
        dec menuAnimTick
    .endif
    
    ; 心跳动画
    inc heartBeat
    mov eax, heartBeat
    .if eax >= 60
        mov heartBeat, 0
    .endif
    
    ret
HandleMenuInput endp

; --- 暂停菜单输入处理 ---
HandlePauseInput proc
    invoke GetAsyncKeyState, VK_UP
    test ax, 8000h
    jz @CheckDown
    
    mov eax, menuAnimTick
    .if eax == 0
        dec pauseSelection
        .if SDWORD PTR pauseSelection < 0
            mov pauseSelection, 2
        .endif
        mov menuAnimTick, 10
    .endif

@CheckDown:
    invoke GetAsyncKeyState, VK_DOWN
    test ax, 8000h
    jz @CheckEnter
    
    mov eax, menuAnimTick
    .if eax == 0
        inc pauseSelection
        .if pauseSelection > 2
            mov pauseSelection, 0
        .endif
        mov menuAnimTick, 10
    .endif

@CheckEnter:
    invoke GetAsyncKeyState, VK_RETURN
    test ax, 8000h
    jz @CheckPause
    
    mov eax, menuAnimTick
    .if eax == 0
        mov eax, pauseSelection
        .if eax == 0
            ; 继续游戏
            mov gameState, STATE_PLAYING
            mov menuAnimTick, 30
            jmp @CheckPause
        .elseif eax == 1
            ; 重新开始
            call InitGame
            mov gameState, STATE_PLAYING
            mov menuAnimTick, 30
            jmp @CheckPause
        .elseif eax == 2
            ; 返回菜单
            mov gameState, STATE_MENU
            mov menuSelection, MENU_START
        .endif
        mov menuAnimTick, 20
    .endif

@CheckPause:
    ; 按P继续游戏
    invoke GetAsyncKeyState, 'P'
    test ax, 8000h
    jz @UpdateAnim
    
    mov eax, menuAnimTick
    .if eax == 0
        mov gameState, STATE_PLAYING
        mov menuAnimTick, 20
    .endif

@UpdateAnim:
    mov eax, menuAnimTick
    .if eax > 0
        dec menuAnimTick
    .endif
    
    inc heartBeat
    mov eax, heartBeat
    .if eax >= 60
        mov heartBeat, 0
    .endif
    
    ret
HandlePauseInput endp

; --- 游戏中输入处理 ---
HandleGameInput proc
    ; 检查暂停键
    invoke GetAsyncKeyState, 'P'
    test ax, 8000h
    jz @Continue
    
    mov eax, menuAnimTick
    .if eax == 0
        mov gameState, STATE_PAUSED
        mov pauseSelection, 0
        mov menuAnimTick, 20
    .endif

@Continue:
    ; 检查游戏结束
    .if p1.active == 0 || p2.active == 0
        mov gameState, STATE_GAME_OVER
    .endif
    
    mov eax, menuAnimTick
    .if eax > 0
        dec menuAnimTick
    .endif
    
    ret
HandleGameInput endp

; --- 网络菜单输入处理 ---
HandleNetworkMenuInput proc
    ; 先检查是否已经连接成功，如果是则检查消息
    mov eax, lastNetworkResult
    cmp eax, 1
    jne @CheckKeys
    
    ; 已连接，持续检查是否收到MSG_CONNECT（不打印调试信息）
    call ReceiveNetworkData
    test eax, eax  ; 检查是否收到任何消息
    jz @CheckKeys  ; 没收到消息，继续检查按键
    
    cmp eax, MSG_CONNECT
    jne @CheckKeys
    
    ; 收到MSG_CONNECT，开始游戏！
    invoke crt_printf, ADDR szDbgGameStart
    mov gameState, STATE_PLAYING
    call InitGame
    ret
    
@CheckKeys:
    invoke GetAsyncKeyState, 'H'
    test ax, 8000h
    jz @CheckJ
    
    mov eax, menuAnimTick
    test eax, eax
    jnz @CheckJ
    
    ; 检查是否已经在连接
    mov eax, lastNetworkResult
    cmp eax, 1
    je @HostDone
    
    ; 检查网络是否已初始化
    mov eax, networkInitOK
    test eax, eax
    jnz @DoHost
    
    call InitNetwork
    mov networkInitOK, eax
    mov lastNetworkResult, eax
    
@DoHost:
    mov eax, networkInitOK
    cmp eax, 1
    jne @HostDone
    
    ; 作为主机连接到服务器
    mov networkMode, NET_MODE_HOST
    call HostGame
    mov lastNetworkResult, eax
    
    ; eax: 0=失败, 1=连接成功
    ; 连接成功后保持在网络菜单等待对方玩家
    
@HostDone:
    mov menuAnimTick, 20

@CheckJ:
    invoke GetAsyncKeyState, 'J'
    test ax, 8000h
    jz @CheckESC
    
    mov eax, menuAnimTick
    test eax, eax
    jnz @CheckESC
    
    ; 检查是否已经在连接
    mov eax, lastNetworkResult
    cmp eax, 1
    je @JoinDone
    
    ; 检查网络是否已初始化
    mov eax, networkInitOK
    test eax, eax
    jnz @DoJoin
    
    call InitNetwork
    mov networkInitOK, eax
    mov lastNetworkResult, eax
    
@DoJoin:
    mov eax, networkInitOK
    cmp eax, 1
    jne @JoinDone
    
    ; 作为客户端连接到服务器
    mov networkMode, NET_MODE_CLIENT
    invoke JoinGame, 0  ; 使用默认服务器地址
    mov lastNetworkResult, eax
    
    cmp eax, 1
    jne @JoinDone
    
    ; 连接成功，保持在网络菜单等待对方
    ; TODO: 监听服务器的MSG_CONNECT消息
    
@JoinDone:
    mov menuAnimTick, 20

@CheckESC:
    invoke GetAsyncKeyState, VK_ESCAPE
    test ax, 8000h
    jz @CheckNetworkReady
    
    mov eax, menuAnimTick
    test eax, eax
    jnz @CheckNetworkReady
    
    ; 返回主菜单，清理网络状态
    call DisconnectNetwork
    mov networkMode, NET_MODE_OFFLINE
    mov networkInitOK, 0
    mov lastNetworkResult, 0
    mov gameState, STATE_MENU
    mov menuAnimTick, 20
    jmp @UpdateAnim

@CheckNetworkReady:
    ; 如果已经连接成功，检查是否收到MSG_CONNECT（对方玩家连接）
    mov eax, lastNetworkResult
    cmp eax, 1
    jne @UpdateAnim
    
    ; 尝试接收数据
    call ReceiveNetworkData
    cmp eax, 1  ; MSG_CONNECT
    jne @UpdateAnim
    
    ; 收到MSG_CONNECT，两个玩家都连接了，开始游戏！
    mov gameState, STATE_PLAYING
    call InitGame

@UpdateAnim:
    mov eax, menuAnimTick
    .if eax > 0
        dec menuAnimTick
    .endif
    
    inc heartBeat
    mov eax, heartBeat
    .if eax >= 60
        mov heartBeat, 0
    .endif
    
    ret
HandleNetworkMenuInput endp

; --- 游戏结束输入处理 ---
HandleGameOverInput proc
    invoke GetAsyncKeyState, VK_RETURN
    test ax, 8000h
    jz @Done
    
    mov eax, menuAnimTick
    .if eax == 0
        ; 返回菜单
        mov gameState, STATE_MENU
        mov menuSelection, MENU_START
        mov menuAnimTick, 20
    .endif

@Done:
    mov eax, menuAnimTick
    .if eax > 0
        dec menuAnimTick
    .endif
    ret
HandleGameOverInput endp

; --- 绘制菜单 ---
DrawMenu proc hDC:DWORD
    LOCAL hFont:DWORD
    LOCAL hOldFont:DWORD
    LOCAL rect:RECT
    LOCAL hBrush:DWORD
    LOCAL hPen:DWORD
    LOCAL hOldPen:DWORD
    LOCAL textY:DWORD
    LOCAL heartX:DWORD
    LOCAL heartY:DWORD
    LOCAL i:DWORD
    LOCAL xPos:DWORD
    LOCAL flashColor:DWORD
    
    ; 渐变背景效果 (深蓝到黑)
    mov i, 0
    .while i < WINDOW_H
        mov eax, i
        imul eax, 20
        mov ecx, WINDOW_H
        cdq
        idiv ecx
        shl eax, 16
        invoke CreateSolidBrush, eax
        mov hBrush, eax
        mov eax, i
        mov rect.left, 0
        mov rect.top, eax
        mov rect.right, WINDOW_W
        add eax, 2
        mov rect.bottom, eax
        invoke FillRect, hDC, addr rect, hBrush
        invoke DeleteObject, hBrush
        add i, 2
    .endw
    
    invoke SetBkMode, hDC, TRANSPARENT
    
    ; === 绘制装饰边框 ===
    invoke CreatePen, PS_SOLID, 3, COLOR_MENU_HL
    mov hPen, eax
    invoke SelectObject, hDC, hPen
    mov hOldPen, eax
    
    ; 顶部装饰线
    invoke MoveToEx, hDC, 50, 70, NULL
    invoke LineTo, hDC, 750, 70
    invoke MoveToEx, hDC, 50, 75, NULL
    invoke LineTo, hDC, 750, 75
    
    ; 标题区域边框
    invoke MoveToEx, hDC, 80, 90, NULL
    invoke LineTo, hDC, 720, 90
    invoke LineTo, hDC, 720, 180
    invoke LineTo, hDC, 80, 180
    invoke LineTo, hDC, 80, 90
    
    invoke SelectObject, hDC, hOldPen
    invoke DeleteObject, hPen
    
    ; === 标题阴影效果 ===
    invoke CreateFont, 64, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    mov hOldFont, eax
    
    ; 阴影 (深红)
    invoke SetTextColor, hDC, 00000080h
    invoke TextOut, hDC, 103, 108, addr szMenuTitle, 18
    
    ; 主标题 (金色带闪烁)
    mov eax, heartBeat
    .if eax < 20
        mov flashColor, 0000D7FFh  ; 亮金色
    .elseif eax < 40
        mov flashColor, COLOR_MENU_HL  ; 标准金色
    .else
        mov flashColor, 0000A0D0h  ; 暗金色
    .endif
    invoke SetTextColor, hDC, flashColor
    invoke TextOut, hDC, 100, 105, addr szMenuTitle, 18
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; 副标题
    invoke CreateFont, 18, 0, 0, 0, FW_NORMAL, 1, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, 00C0C0C0h
    invoke TextOut, hDC, 220, 155, addr szSubTitle, 28
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; === 绘制装饰符号 ===
    invoke CreateFont, 24, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, COLOR_MENU_HL
    
    ; 顶部装饰
    mov xPos, 60
    mov i, 0
    .while i < 16
        invoke TextOut, hDC, xPos, 48, addr szBorder1, 1
        add xPos, 45
        inc i
    .endw
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; === 菜单项字体 ===
    ; 1. 绘制高亮边框 (跟随选中项)
    ; 使用金色画笔
    invoke CreatePen, PS_SOLID, 2, 0000D7FFh  ; 金色
    mov hPen, eax
    invoke SelectObject, hDC, hPen
    mov hOldPen, eax
    
    ; 使用空心画刷 (透明内部)
    invoke GetStockObject, NULL_BRUSH
    invoke SelectObject, hDC, eax
    
    ; 根据当前选择绘制边框
    .if menuSelection == MENU_START
        ; 包裹 "START GAME" 的矩形
        invoke Rectangle, hDC, 280, 260, 520, 310
    .elseif menuSelection == MENU_NETWORK
        ; 包裹 "NETWORK GAME" 的矩形
        invoke Rectangle, hDC, 280, 315, 520, 365
    .else
        ; 包裹 "QUIT GAME" 的矩形
        invoke Rectangle, hDC, 280, 370, 520, 420
    .endif
    
    ; 恢复画笔
    invoke SelectObject, hDC, hOldPen
    invoke DeleteObject, hPen
    
    ; 2. 绘制文字
    invoke SetBkMode, hDC, TRANSPARENT
    mov textY, 265
    
    ; START GAME
    .if menuSelection == MENU_START
        ; 选中：亮金色
        invoke SetTextColor, hDC, 0000D7FFh
    .else
        ; 未选中：暗灰色
        invoke SetTextColor, hDC, 00606060h
    .endif
    invoke TextOut, hDC, 300, textY, addr szMenuItem1, 13
    
    ; NETWORK GAME
    add textY, 55
    .if menuSelection == MENU_NETWORK
        invoke SetTextColor, hDC, 0000D7FFh
    .else
        invoke SetTextColor, hDC, 00606060h
    .endif
    invoke TextOut, hDC, 300, textY, addr szMenuItem2, 15
    
    ; QUIT
    add textY, 55
    .if menuSelection == MENU_QUIT
        ; 选中：亮金色
        invoke SetTextColor, hDC, 0000D7FFh
    .else
        ; 未选中：暗灰色
        invoke SetTextColor, hDC, 00606060h
    .endif
    invoke TextOut, hDC, 300, textY, addr szMenuItem3, 7
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; === 绘制选择光标 ===
    invoke CreateFont, 44, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, 000000FFh  ; 红色
    
    mov heartX, 250
    mov eax, menuSelection
    imul eax, 55
    add eax, 265
    mov heartY, eax
    
    ; 心跳动画
    mov eax, heartBeat
    .if eax < 30
        sub heartX, 5
    .endif
    
    invoke TextOut, hDC, heartX, heartY, addr szMenuHeart, 1
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; === 底部提示信息 ===
    invoke CreateFont, 20, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    
    ; 闪烁提示
    mov eax, heartBeat
    .if eax < 40
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, 00808080h
    .endif
    invoke TextOut, hDC, 270, 420, addr szPressKey, 21
    
    ; 控制说明
    invoke SetTextColor, hDC, 00C0C0C0h
    invoke TextOut, hDC, 270, 480, addr szControls1, 19
    invoke TextOut, hDC, 230, 505, addr szControls2, 25
    
    ; 版本信息
    invoke SetTextColor, hDC, 00606060h
    invoke TextOut, hDC, 10, 570, addr szVersion, 12
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ret
DrawMenu endp

; --- 绘制网络菜单 ---
DrawNetworkMenu proc hDC:DWORD
    LOCAL hFont:DWORD
    LOCAL hOldFont:DWORD
    LOCAL rect:RECT
    LOCAL hBrush:DWORD
    LOCAL hPen:DWORD
    LOCAL hOldPen:DWORD
    LOCAL textY:DWORD
    LOCAL i:DWORD
    LOCAL statusMsg:DWORD
    
    ; 渐变背景
    mov i, 0
    .while i < WINDOW_H
        mov eax, i
        imul eax, 20
        mov ecx, WINDOW_H
        cdq
        idiv ecx
        shl eax, 16
        invoke CreateSolidBrush, eax
        mov hBrush, eax
        mov eax, i
        mov rect.left, 0
        mov rect.top, eax
        mov rect.right, WINDOW_W
        add eax, 2
        mov rect.bottom, eax
        invoke FillRect, hDC, addr rect, hBrush
        invoke DeleteObject, hBrush
        add i, 2
    .endw
    
    invoke SetBkMode, hDC, TRANSPARENT
    
    ; 标题
    invoke CreateFont, 72, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, \
           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
           DEFAULT_PITCH or FF_SWISS, ADDR szArialFont
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    mov hOldFont, eax
    invoke SetTextColor, hDC, COLOR_MENU_HL
    
    mov rect.left, 0
    mov rect.top, 100
    mov rect.right, WINDOW_W
    mov rect.bottom, 200
    invoke DrawText, hDC, ADDR szNetworkTitle, -1, ADDR rect, \
           DT_CENTER or DT_VCENTER or DT_SINGLELINE
    invoke DeleteObject, hFont
    
    ; 选项文字
    invoke CreateFont, 36, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, \
           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
           DEFAULT_PITCH or FF_SWISS, ADDR szArialFont
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, 00FFFFFFh
    
    ; H - Host Game
    mov rect.left, 0
    mov rect.top, 250
    mov rect.right, WINDOW_W
    mov rect.bottom, 290
    invoke DrawText, hDC, ADDR szHostOption, -1, ADDR rect, \
           DT_CENTER or DT_VCENTER or DT_SINGLELINE
    
    ; J - Join Game  
    mov rect.top, 310
    mov rect.bottom, 350
    invoke DrawText, hDC, ADDR szJoinOption, -1, ADDR rect, \
           DT_CENTER or DT_VCENTER or DT_SINGLELINE
    
    ; ESC - Back
    mov rect.top, 370
    mov rect.bottom, 410
    invoke DrawText, hDC, ADDR szBackOption, -1, ADDR rect, \
           DT_CENTER or DT_VCENTER or DT_SINGLELINE
    
    ; 状态信息
    invoke CreateFont, 24, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, \
           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
           DEFAULT_PITCH or FF_SWISS, ADDR szArialFont
    invoke SelectObject, hDC, hFont
    invoke DeleteObject, hOldFont
    
    ; 根据网络初始化和模式显示状态
    mov eax, networkInitOK
    test eax, eax
    jnz @CheckMode
    
    ; 初始化失败
    mov statusMsg, OFFSET szInitFailed
    invoke SetTextColor, hDC, 000000FFh  ; 红色
    jmp @DrawStatus
    
@CheckMode:
    mov eax, networkMode
    cmp eax, NET_MODE_HOST
    je @HostMode
    cmp eax, NET_MODE_CLIENT
    je @ClientMode
    
    ; 离线模式
    mov statusMsg, OFFSET szOfflineStatus
    invoke SetTextColor, hDC, 00808080h
    jmp @DrawStatus
    
@HostMode:
    mov eax, lastNetworkResult
    cmp eax, 2
    je @HostWaiting
    cmp eax, 1
    je @Connected
    
    ; 主机连接失败
    mov statusMsg, OFFSET szConnectFailed
    invoke SetTextColor, hDC, 000000FFh  ; 红色
    jmp @DrawStatus
    
@HostWaiting:
    mov statusMsg, OFFSET szHostWaiting
    invoke SetTextColor, hDC, COLOR_MENU_HL
    jmp @DrawStatus
    
@ClientMode:
    mov eax, lastNetworkResult
    cmp eax, 1
    je @Connected
    
    ; 客户端连接失败
    mov statusMsg, OFFSET szConnectFailed
    invoke SetTextColor, hDC, 000000FFh  ; 红色
    jmp @DrawStatus
    
@Connected:
    mov statusMsg, OFFSET szConnectSuccess
    invoke SetTextColor, hDC, 0000FF00h  ; 绿色
    
@DrawStatus:
    mov rect.top, 450
    mov rect.bottom, 490
    invoke DrawText, hDC, statusMsg, -1, ADDR rect, \
           DT_CENTER or DT_VCENTER or DT_SINGLELINE
    
    ; 调试信息
    invoke CreateFont, 18, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, \
           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, \
           DEFAULT_PITCH or FF_SWISS, ADDR szArialFont
    invoke SelectObject, hDC, hFont
    invoke DeleteObject, hOldFont
    invoke SetTextColor, hDC, 00FFFFFFh
    
    invoke wsprintf, ADDR szDebugBuffer, ADDR szDebugFormat, \
           networkMode, networkInitOK, lastNetworkResult, wsaStartupError
    mov rect.top, 510
    mov rect.bottom, 540
    invoke DrawText, hDC, ADDR szDebugBuffer, -1, ADDR rect, \
           DT_CENTER or DT_VCENTER or DT_SINGLELINE
    
    invoke DeleteObject, hFont
    ret
DrawNetworkMenu endp

; --- 绘制暂停菜单 ---
DrawPauseMenu proc hDC:DWORD
    LOCAL hFont:DWORD
    LOCAL hOldFont:DWORD
    LOCAL rect:RECT
    LOCAL hBrush:DWORD
    LOCAL textY:DWORD
    LOCAL heartY:DWORD
    
    ; 半透明背景效果（使用暗灰色遮罩）
    invoke CreateSolidBrush, 00202020h
    mov hBrush, eax
    mov rect.left, 150
    mov rect.top, 150
    mov rect.right, 650
    mov rect.bottom, 450
    invoke FillRect, hDC, addr rect, hBrush
    invoke DeleteObject, hBrush
    
    invoke SetBkMode, hDC, TRANSPARENT
    
    ; 标题
    invoke CreateFont, 48, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    mov hOldFont, eax
    
    invoke SetTextColor, hDC, COLOR_MENU_HL
    invoke TextOut, hDC, 300, 180, addr szPaused, 10
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; 菜单项
    invoke CreateFont, 28, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    
    mov textY, 260
    
    ; RESUME
    .if pauseSelection == 0
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, COLOR_TEXT
    .endif
    invoke TextOut, hDC, 320, textY, addr szResume, 9
    
    ; RESTART
    add textY, 45
    .if pauseSelection == 1
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, COLOR_TEXT
    .endif
    invoke TextOut, hDC, 320, textY, addr szRestart, 10
    
    ; QUIT TO MENU
    add textY, 45
    .if pauseSelection == 2
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, COLOR_TEXT
    .endif
    invoke TextOut, hDC, 320, textY, addr szQuitGame, 15
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; 光标
    invoke CreateFont, 36, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, 00FF0000h
    
    mov eax, pauseSelection
    imul eax, 45
    add eax, 260
    mov heartY, eax
    
    invoke TextOut, hDC, 280, heartY, addr szMenuHeart, 1
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ret
DrawPauseMenu endp

; --- 绘制游戏结束画面 ---
DrawGameOver proc hDC:DWORD
    LOCAL hFont:DWORD
    LOCAL hOldFont:DWORD
    LOCAL pWinText:DWORD
    LOCAL textLen:DWORD
    
    invoke SetBkMode, hDC, TRANSPARENT
    
    ; 大字体显示获胜者
    invoke CreateFont, 56, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    mov hOldFont, eax
    
    .if p1.active == 0
        invoke SetTextColor, hDC, COLOR_P2
        lea eax, szP2Win
        mov pWinText, eax
        mov textLen, 14
    .else
        invoke SetTextColor, hDC, COLOR_P1
        lea eax, szP1Win
        mov pWinText, eax
        mov textLen, 14
    .endif
    
    invoke TextOut, hDC, 220, 250, pWinText, textLen
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; 提示按Enter返回
    invoke CreateFont, 24, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, COLOR_TEXT
    
    invoke TextOut, hDC, 250, 350, addr szPressKey, 21
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ret
DrawGameOver endp
