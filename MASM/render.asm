; ========================================
; Render.asm - 渲染模块
; ========================================

; --- 绘制单个坦克 ---
DrawOneTank proc hDC:DWORD, pTank:DWORD
    LOCAL centerX:SDWORD
    LOCAL centerY:SDWORD
    LOCAL x1:SDWORD, y1:SDWORD
    LOCAL x2:SDWORD, y2:SDWORD
    LOCAL x3:SDWORD, y3:SDWORD
    LOCAL x4:SDWORD, y4:SDWORD
    LOCAL endX:SDWORD, endY:SDWORD
    LOCAL hBrush:DWORD
    LOCAL hOld:DWORD
    LOCAL pts[4]:POINT
    LOCAL hOldPen:DWORD

    mov esi, pTank
    ASSUME esi:PTR TANK

    .if [esi].active == 0
        ret
    .endif

    ; 计算中心坐标
    mov eax, [esi].pos_x
    sar eax, 8
    mov centerX, eax

    mov eax, [esi].pos_y
    sar eax, 8
    mov centerY, eax

    ; 获取sin/cos值
    mov edx, [esi].angle
    mov ebx, cosTable[edx*4]
    mov edi, sinTable[edx*4]

    ; 计算四个角点
    ; corner1 (-w,-h)
    mov eax, -TANK_HALF_W
    imul eax, ebx
    mov ecx, -TANK_HALF_H
    imul ecx, edi
    sub eax, ecx
    sar eax, 8
    add eax, centerX
    mov x1, eax

    mov eax, -TANK_HALF_W
    imul eax, edi
    mov ecx, -TANK_HALF_H
    imul ecx, ebx
    add eax, ecx
    sar eax, 8
    add eax, centerY
    mov y1, eax

    ; corner2 (w,-h)
    mov eax, TANK_HALF_W
    imul eax, ebx
    mov ecx, -TANK_HALF_H
    imul ecx, edi
    sub eax, ecx
    sar eax, 8
    add eax, centerX
    mov x2, eax

    mov eax, TANK_HALF_W
    imul eax, edi
    mov ecx, -TANK_HALF_H
    imul ecx, ebx
    add eax, ecx
    sar eax, 8
    add eax, centerY
    mov y2, eax

    ; corner3 (w,h)
    mov eax, TANK_HALF_W
    imul eax, ebx
    mov ecx, TANK_HALF_H
    imul ecx, edi
    sub eax, ecx
    sar eax, 8
    add eax, centerX
    mov x3, eax

    mov eax, TANK_HALF_W
    imul eax, edi
    mov ecx, TANK_HALF_H
    imul ecx, ebx
    add eax, ecx
    sar eax, 8
    add eax, centerY
    mov y3, eax

    ; corner4 (-w,h)
    mov eax, -TANK_HALF_W
    imul eax, ebx
    mov ecx, TANK_HALF_H
    imul ecx, edi
    sub eax, ecx
    sar eax, 8
    add eax, centerX
    mov x4, eax

    mov eax, -TANK_HALF_W
    imul eax, edi
    mov ecx, TANK_HALF_H
    imul ecx, ebx
    add eax, ecx
    sar eax, 8
    add eax, centerY
    mov y4, eax

    ; 填充POINT数组
    mov eax, x1
    mov pts[0].x, eax
    mov eax, y1
    mov pts[0].y, eax

    mov eax, x2
    mov pts[8].x, eax
    mov eax, y2
    mov pts[8].y, eax

    mov eax, x3
    mov pts[16].x, eax
    mov eax, y3
    mov pts[16].y, eax

    mov eax, x4
    mov pts[24].x, eax
    mov eax, y4
    mov pts[24].y, eax

    ; 绘制坦克主体
    invoke CreateSolidBrush, [esi].color
    mov hBrush, eax
    invoke SelectObject, hDC, hBrush
    mov hOld, eax

    invoke GetStockObject, NULL_PEN
    invoke SelectObject, hDC, eax
    mov hOldPen, eax

    invoke Polygon, hDC, addr pts, 4

    invoke SelectObject, hDC, hOld
    invoke DeleteObject, hBrush

    ; 绘制炮管
    invoke GetStockObject, BLACK_PEN
    invoke SelectObject, hDC, eax

    mov edx, [esi].angle
    mov ebx, cosTable[edx*4]
    mov edi, sinTable[edx*4]

    mov eax, ebx
    imul eax, BARREL_LEN
    sar eax, 8
    add eax, centerX
    mov endX, eax

    mov eax, edi
    imul eax, BARREL_LEN
    sar eax, 8
    add eax, centerY
    mov endY, eax

    invoke MoveToEx, hDC, centerX, centerY, NULL
    invoke LineTo, hDC, endX, endY

    ASSUME esi:nothing
    ret
DrawOneTank endp

; --- 绘制游戏场景 ---
DrawGameScene proc hDC:DWORD
    LOCAL hBg:DWORD, hWall:DWORD
    LOCAL rect:RECT
    LOCAL x:DWORD, y:DWORD
    LOCAL px:DWORD, py:DWORD
    LOCAL hFont:DWORD
    LOCAL hOldFont:DWORD

    ; 背景
    invoke CreateSolidBrush, 00323232h
    mov hBg, eax
    mov rect.left, 0
    mov rect.top, 0
    mov rect.right, WINDOW_W
    mov rect.bottom, WINDOW_H
    invoke FillRect, hDC, addr rect, hBg
    invoke DeleteObject, hBg

    ; 绘制地图
    invoke CreateSolidBrush, COLOR_WALL
    mov hWall, eax
    
    mov y, 0
    .while y < MAP_ROWS
        mov x, 0
        .while x < MAP_COLS
            mov eax, y
            imul eax, MAP_COLS
            add eax, x
            mov edx, map[eax*4]
            .if edx == 1
                mov eax, x
                imul eax, BLOCK_SIZE
                mov rect.left, eax
                add eax, BLOCK_SIZE
                mov rect.right, eax
                
                mov eax, y
                imul eax, BLOCK_SIZE
                mov rect.top, eax
                add eax, BLOCK_SIZE
                mov rect.bottom, eax
                
                invoke FillRect, hDC, addr rect, hWall
            .endif
            inc x
        .endw
        inc y
    .endw
    invoke DeleteObject, hWall

    ; 绘制坦克
    invoke DrawOneTank, hDC, addr p1
    invoke DrawOneTank, hDC, addr p2

    ; 绘制子弹
    invoke CreateSolidBrush, COLOR_BULLET
    mov hBg, eax
    invoke SelectObject, hDC, hBg
    mov hWall, eax

    mov ecx, 0
    .while ecx < MAX_BULLETS
        push ecx
        mov ebx, ecx
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]
        
        mov eax, (BULLET PTR [esi]).active
        .if eax != 0
            mov eax, (BULLET PTR [esi]).pos_x
            sar eax, 8
            mov px, eax
            
            mov eax, (BULLET PTR [esi]).pos_y
            sar eax, 8
            mov py, eax
            
            mov eax, px
            sub eax, 3
            mov ecx, py
            sub ecx, 3
            mov edx, px
            add edx, 3
            push edx
            mov edx, py
            add edx, 3
            pop ebx
            invoke Ellipse, hDC, eax, ecx, ebx, edx
        .endif
        
        pop ecx
        inc ecx
    .endw
    invoke SelectObject, hDC, hWall
    invoke DeleteObject, hBg

    ; 显示暂停提示 (Updated: 使用醒目的金色)
    invoke SetBkMode, hDC, TRANSPARENT
    invoke CreateFont, 16, 0, 0, 0, FW_NORMAL, 0, 0, 0, \
           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
           DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, NULL
    mov hFont, eax
    invoke SelectObject, hDC, hFont
    mov hOldFont, eax
    
    ; 修改颜色为 COLOR_MENU_HL (金色)
    invoke SetTextColor, hDC, COLOR_MENU_HL
    invoke TextOut, hDC, 650, 10, addr szPauseInfo, 16
    
    invoke SelectObject, hDC, hOldFont
    invoke DeleteObject, hFont

    ret
DrawGameScene endp

; --- 主绘制函数 ---
DrawGame proc hDC:DWORD
    mov eax, gameState
    
    .if eax == STATE_MENU
        invoke DrawMenu, hDC
    .elseif eax == STATE_PLAYING
        invoke DrawGameScene, hDC
    .elseif eax == STATE_PAUSED
        invoke DrawGameScene, hDC
        invoke DrawPauseMenu, hDC
    .elseif eax == STATE_GAME_OVER
        invoke DrawGameScene, hDC
        invoke DrawGameOver, hDC
    .endif
    
    ret
DrawGame endp