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
            mov menuSelection, 3  ; 改为3个选项
        .endif
        mov menuAnimTick, 10
    .endif

@CheckDown:
    invoke GetAsyncKeyState, VK_DOWN
    test ax, 8000h
    jz @CheckLeft
    
    mov eax, menuAnimTick
    .if eax == 0
        inc menuSelection
        .if menuSelection > 3  ; 改为3个选项
            mov menuSelection, 0
        .endif
        mov menuAnimTick, 10
    .endif

@CheckLeft:
    invoke GetAsyncKeyState, VK_LEFT
    test ax, 8000h
    jz @CheckRight
    
    mov eax, menuAnimTick
    .if eax == 0
        mov eax, menuSelection
        .if eax == MENU_MODE
            ; 切换模式
            xor gameMode, 1
            mov eax, gameMode
            mov aiEnabled, eax
            mov menuAnimTick, 10
        .elseif eax == MENU_DIFFICULTY
            ; 降低难度
            dec aiDifficulty
            .if SDWORD PTR aiDifficulty < 0
                mov aiDifficulty, 2
            .endif
            mov menuAnimTick, 10
        .endif
    .endif

@CheckRight:
    invoke GetAsyncKeyState, VK_RIGHT
    test ax, 8000h
    jz @CheckEnter
    
    mov eax, menuAnimTick
    .if eax == 0
        mov eax, menuSelection
        .if eax == MENU_MODE
            ; 切换模式
            xor gameMode, 1
            mov eax, gameMode
            mov aiEnabled, eax
            mov menuAnimTick, 10
        .elseif eax == MENU_DIFFICULTY
            ; 提高难度
            inc aiDifficulty
            .if aiDifficulty > 2
                mov aiDifficulty, 0
            .endif
            mov menuAnimTick, 10
        .endif
    .endif

@CheckEnter:
    invoke GetAsyncKeyState, VK_RETURN
    test ax, 8000h
    jz @UpdateAnim
    
    mov eax, menuAnimTick
    .if eax == 0
        mov eax, menuSelection
        .if eax == MENU_START
            ; 开始游戏
            mov gameState, STATE_PLAYING
            call InitGame
            ; 设置更长延迟防止Enter键立即触发射击
            mov menuAnimTick, 30
            jmp @UpdateAnim
        .elseif eax == MENU_MODE
            ; 切换模式
            xor gameMode, 1
            mov eax, gameMode
            mov aiEnabled, eax
            mov menuAnimTick, 10
        .elseif eax == MENU_DIFFICULTY
            ; 循环切换难度
            inc aiDifficulty
            .if aiDifficulty > 2
                mov aiDifficulty, 0
            .endif
            mov menuAnimTick, 10
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
    
    ; 菜单项字体
    invoke CreateFont, 28, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           ANTIALIASED_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    
    ; 菜单项背景框
    invoke CreatePen, PS_SOLID, 4, COLOR_MENU_HL
    mov hPen, eax
    invoke SelectObject, hDC, hPen
    mov hOldPen, eax
    
    invoke CreateSolidBrush, 00000000h
    mov hBrush, eax
    invoke SelectObject, hDC, hBrush
    
    invoke Rectangle, hDC, 200, 220, 600, 440 
    
    invoke DeleteObject, hBrush
    invoke SelectObject, hDC, hOldPen
    invoke DeleteObject, hPen
    
    mov textY, 245
    
    ; START GAME
    .if menuSelection == MENU_START
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, 00808080h
    .endif
    invoke TextOut, hDC, 220, textY, addr szMenuItem1, 12
    
    ; MODE
    add textY, 45
    .if menuSelection == MENU_MODE
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, 00808080h
    .endif
    invoke TextOut, hDC, 220, textY, addr szMenuItem2, 8
    
    ; 显示当前模式
    .if gameMode == MODE_PVP
        invoke TextOut, hDC, 340, textY, addr szModePVP, 3
    .else
        invoke TextOut, hDC, 340, textY, addr szModePVE, 11
    .endif
    
    ; DIFFICULTY (仅在PVE模式显示)
    add textY, 45
    .if gameMode == MODE_PVE
        .if menuSelection == MENU_DIFFICULTY
            invoke SetTextColor, hDC, COLOR_MENU_HL
        .else
            invoke SetTextColor, hDC, 00808080h
        .endif
        invoke TextOut, hDC, 220, textY, addr szMenuItem3, 14
        
        ; 显示当前难度 
        .if aiDifficulty == AI_EASY
            invoke TextOut, hDC, 440, textY, addr szDiffEasy, 4
        .elseif aiDifficulty == AI_MEDIUM
            invoke TextOut, hDC, 440, textY, addr szDiffMedium, 6
        .else
            invoke TextOut, hDC, 440, textY, addr szDiffHard, 4
        .endif
    .endif
    
    ; QUIT
    add textY, 45
    .if menuSelection == MENU_QUIT
        invoke SetTextColor, hDC, COLOR_MENU_HL
    .else
        invoke SetTextColor, hDC, 00808080h
    .endif
    invoke TextOut, hDC, 220, textY, addr szMenuItem4, 6
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; === 绘制选择光标 ===
    invoke CreateFont, 44, 0, 0, 0, FW_BOLD, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, 000000FFh
    
    mov heartX, 180
    mov eax, menuSelection
    imul eax, 45
    add eax, 245
    mov heartY, eax
    
    mov eax, heartBeat
    .if eax < 30
        sub heartX, 5
    .endif
    
    invoke TextOut, hDC, heartX, heartY, addr szMenuHeart, 1
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ; === 底部提示信息 (Updated) ===
    invoke CreateFont, 20, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    
    ; --- 设置统一的闪烁颜色 (用于两行提示) ---
    mov eax, heartBeat
    .if eax < 30
        invoke SetTextColor, hDC, COLOR_MENU_HL  ; 高亮色
    .else
        invoke SetTextColor, hDC, 00606060h      ; 暗灰色
    .endif
    
    ; 1. 绘制方向键提示 (移至方框下方 Y=455)
    invoke TextOut, hDC, 230, 455, addr szHintNav, 36
    
    ; 2. 绘制回车键提示 (移至方框下方 Y=480)
    invoke TextOut, hDC, 275, 480, addr szHintEnter, 26
    
    ; 3. 控制说明 (完善文案并居中)
    invoke SetTextColor, hDC, 00C0C0C0h
    ; PLAYER 1: WASD = MOVE, J = FIRE (31 chars) -> X=245 居中
    invoke TextOut, hDC, 245, 520, addr szControls1, 31
    ; PLAYER 2: ARROWS = MOVE, ENTER = FIRE (37 chars) -> X=215 居中
    invoke TextOut, hDC, 215, 545, addr szControls2, 37
    
    ; 版本信息
    invoke SetTextColor, hDC, 00606060h
    invoke TextOut, hDC, 10, 570, addr szVersion, 12
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ret
DrawMenu endp

; --- 绘制暂停菜单 ---
DrawPauseMenu proc hDC:DWORD
    LOCAL hFont:DWORD
    LOCAL hOldFont:DWORD
    LOCAL rect:RECT
    LOCAL hBrush:DWORD
    LOCAL hPen:DWORD        ; 新增：画笔句柄
    LOCAL hOldPen:DWORD     ; 新增：旧画笔保存
    LOCAL hOldBrush:DWORD   ; 新增：旧画刷保存
    LOCAL textY:DWORD
    LOCAL heartY:DWORD
    
    ; === 绘制带边框的背景 ===
    ; 1. 创建金色边框画笔 (宽度 3)
    invoke CreatePen, PS_SOLID, 3, COLOR_MENU_HL
    mov hPen, eax
    invoke SelectObject, hDC, hPen
    mov hOldPen, eax
    
    ; 2. 创建深色背景画刷
    invoke CreateSolidBrush, 00202020h
    mov hBrush, eax
    invoke SelectObject, hDC, hBrush
    mov hOldBrush, eax
    
    ; 3. 绘制矩形 (自动使用当前选中的画笔画框，画刷填充)
    invoke Rectangle, hDC, 150, 150, 650, 450
    
    ; 4. 清理绘图对象
    invoke SelectObject, hDC, hOldBrush
    invoke SelectObject, hDC, hOldPen
    invoke DeleteObject, hBrush
    invoke DeleteObject, hPen
    
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
    
    ; 提示按Enter返回 (使用 szPressKey, 长度21)
    invoke CreateFont, 24, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    invoke SetTextColor, hDC, COLOR_TEXT
    
    ; szPressKey 已在 data.inc 中定义，长度为 21
    invoke TextOut, hDC, 250, 350, addr szPressKey, 21
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont
    
    ret
DrawGameOver endp