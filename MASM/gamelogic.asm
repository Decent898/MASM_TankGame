; ========================================
; GameLogic.asm - 游戏核心逻辑
; ========================================

; --- 【新增】函数原型声明 ---
; 必须放在任何 Invoke 调用之前
InitMap              PROTO
CheckMapConnectivity PROTO
TryVisit             PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
IsWall               PROTO :DWORD, :DWORD
; 【修改】函数改名为 CheckTankMove，参数名也做了唯一化处理
CheckTankMove        PROTO :DWORD, :DWORD, :DWORD
FireBullet           PROTO :DWORD

; --- 初始化游戏 ---
InitGame proc
    LOCAL i:DWORD
    LOCAL rad:REAL8
    LOCAL temp:DWORD

    ; 初始化随机数种子
    invoke crt_time, NULL
    invoke crt_srand, eax

    ; 初始化sin/cos查找表
    mov i, 0
    .while i < 360
        finit
        fild i
        fmul double_PI
        fdiv double_180
        fst rad
        
        fld rad
        fsin
        fmul double_256
        fistp temp
        mov eax, temp
        mov edx, i
        mov sinTable[edx*4], eax

        fld rad
        fcos
        fmul double_256
        fistp temp
        mov eax, temp
        mov edx, i
        mov cosTable[edx*4], eax

        inc i
    .endw

    ; 初始化地图
    invoke InitMap

    ; 初始化玩家1
    mov eax, BLOCK_SIZE
    add eax, BLOCK_SIZE / 2
    shl eax, 8
    mov p1.pos_x, eax
    mov p1.pos_y, eax
    mov p1.angle, 90
    mov p1.color, COLOR_P1
    mov p1.active, 1
    mov p1.cooldown, 0

    ; 初始化玩家2
    mov eax, 18 * BLOCK_SIZE + BLOCK_SIZE / 2
    shl eax, 8
    mov p2.pos_x, eax
    mov eax, 13 * BLOCK_SIZE + BLOCK_SIZE / 2
    shl eax, 8
    mov p2.pos_y, eax
    mov p2.angle, 270
    mov p2.color, COLOR_P2
    mov p2.active, 1
    mov p2.cooldown, 30

    ; 初始化子弹
    mov ecx, 0
    .while ecx < MAX_BULLETS
        mov ebx, ecx
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]
        mov (BULLET PTR [esi]).active, 0
        inc ecx
    .endw
    ret
InitGame endp

; --- 初始化地图 ---
InitMap proc
    LOCAL x:DWORD, y:DWORD
    mov y, 0
    .while y < MAP_ROWS
        mov x, 0
        .while x < MAP_COLS
            mov eax, y
            imul eax, MAP_COLS
            add eax, x
            shl eax, 2
            lea edi, map
            add edi, eax

            ; 边界墙
            .if x == 0 || x == MAP_COLS-1 || y == 0 || y == MAP_ROWS-1
                mov DWORD PTR [edi], 1
            .else
                ; 随机墙壁
                invoke crt_rand
                xor edx, edx
                mov ecx, 5
                div ecx
                .if edx == 0
                    mov DWORD PTR [edi], 1
                .else
                    mov DWORD PTR [edi], 0
                .endif
            .endif
            inc x
        .endw
        inc y
    .endw
    
    ; 确保玩家起始位置没有墙
    mov eax, 1 * MAP_COLS + 1
    mov map[eax*4], 0
    mov eax, 13 * MAP_COLS + 18
    mov map[eax*4], 0
    
    ; 检查连通性，如果不连通则重新生成
    invoke CheckMapConnectivity
    .if eax == 0
        ; 不连通，递归重新生成
        invoke InitMap
    .endif
    ret
InitMap endp

; --- 检查地图连通性（BFS）---
CheckMapConnectivity proc uses esi edi
    LOCAL queue[400]:DWORD          ; BFS队列
    LOCAL visited[400]:DWORD        ; 访问标记数组
    LOCAL queueFront:DWORD          ; 队列前指针
    LOCAL queueRear:DWORD           ; 队列后指针
    LOCAL current:DWORD             ; 当前位置
    LOCAL row:DWORD, col:DWORD
    LOCAL newRow:DWORD, newCol:DWORD
    ; [已移除] LOCAL newPos:DWORD (未使用)
    LOCAL target:DWORD              ; 目标位置
    ; [已移除] LOCAL i:DWORD (未使用)
    
    ; 初始化visited数组
    lea edi, visited
    mov ecx, 400
    xor eax, eax
    rep stosd
    
    ; 起点：玩家1位置 (1, 1)
    mov eax, 1
    imul eax, MAP_COLS
    add eax, 1
    mov current, eax
    
    ; 终点：玩家2位置 (13, 18)
    mov eax, 13
    imul eax, MAP_COLS
    add eax, 18
    mov target, eax
    
    ; 初始化队列
    mov queueFront, 0
    mov queueRear, 0
    
    ; 将起点加入队列
    mov eax, current
    mov queue[0], eax
    mov visited[eax*4], 1
    inc queueRear
    
    ; BFS循环
    .while TRUE
        ; 检查队列是否为空
        mov eax, queueFront
        cmp eax, queueRear
        jge @NotConnected
        
        ; 取出队首元素
        mov eax, queueFront
        mov edx, queue[eax*4]
        mov current, edx
        inc queueFront
        
        ; 检查是否到达目标
        mov eax, current
        .if eax == target
            mov eax, 1              ; 连通
            ret
        .endif
        
        ; 计算当前行列
        xor edx, edx
        mov eax, current
        mov ecx, MAP_COLS
        div ecx
        mov row, eax
        mov col, edx
        
        ; 尝试四个方向：上、下、左、右
        
        ; 上 (row-1, col)
        mov eax, row
        .if eax > 0
            dec eax
            mov newRow, eax
            mov eax, col
            mov newCol, eax
            invoke TryVisit, newRow, newCol, addr visited, addr queue, addr queueRear
        .endif
        
        ; 下 (row+1, col)
        mov eax, row
        inc eax
        .if eax < MAP_ROWS
            mov newRow, eax
            mov eax, col
            mov newCol, eax
            invoke TryVisit, newRow, newCol, addr visited, addr queue, addr queueRear
        .endif
        
        ; 左 (row, col-1)
        mov eax, col
        .if eax > 0
            dec eax
            mov newCol, eax
            mov eax, row
            mov newRow, eax
            invoke TryVisit, newRow, newCol, addr visited, addr queue, addr queueRear
        .endif
        
        ; 右 (row, col+1)
        mov eax, col
        inc eax
        .if eax < MAP_COLS
            mov newCol, eax
            mov eax, row
            mov newRow, eax
            invoke TryVisit, newRow, newCol, addr visited, addr queue, addr queueRear
        .endif
    .endw
    
@NotConnected:
    xor eax, eax                    ; 不连通
    ret
CheckMapConnectivity endp

; --- BFS辅助函数：尝试访问一个位置 ---
TryVisit proc uses esi row:DWORD, col:DWORD, pVisited:DWORD, pQueue:DWORD, pQueueRear:DWORD
    LOCAL pos:DWORD
    
    ; 计算位置索引
    mov eax, row
    imul eax, MAP_COLS
    add eax, col
    mov pos, eax
    
    ; 检查是否已访问
    mov esi, pVisited
    mov eax, pos
    cmp DWORD PTR [esi + eax*4], 1
    je @Skip
    
    ; 检查是否是墙
    mov eax, pos
    cmp map[eax*4], 1
    je @Skip
    
    ; 标记为已访问
    mov esi, pVisited
    mov eax, pos
    mov DWORD PTR [esi + eax*4], 1
    
    ; 加入队列
    mov esi, pQueueRear
    mov eax, [esi]                  ; queueRear的值
    mov edi, pQueue
    mov edx, pos
    mov [edi + eax*4], edx
    inc DWORD PTR [esi]             ; queueRear++
    
@Skip:
    ret
TryVisit endp

; --- 检查是否是墙 ---
IsWall proc x_fixed:DWORD, y_fixed:DWORD
    LOCAL col:DWORD, row:DWORD

    mov eax, x_fixed
    sar eax, 8
    cdq
    mov ecx, BLOCK_SIZE
    idiv ecx
    mov col, eax

    mov eax, y_fixed
    sar eax, 8
    cdq
    mov ecx, BLOCK_SIZE
    idiv ecx
    mov row, eax

    cmp col, 0
    jl WallHit
    cmp col, MAP_COLS
    jge WallHit
    cmp row, 0
    jl WallHit
    cmp row, MAP_ROWS
    jge WallHit

    mov eax, row
    imul eax, MAP_COLS
    add eax, col
    mov edx, map[eax*4]
    mov eax, edx
    ret

WallHit:
    mov eax, 1
    ret
IsWall endp

; --- 检查坦克是否可以移动（考虑旋转）---
; 【重大修改】函数重命名为 CheckTankMove，参数名 destX, destY, inAngle 避免一切冲突
CheckTankMove proc destX:DWORD, destY:DWORD, inAngle:DWORD
    LOCAL corner_x:DWORD, corner_y:DWORD
    LOCAL cos_val:SDWORD, sin_val:SDWORD
    LOCAL local_x:SDWORD, local_y:SDWORD
    ; [已移除] LOCAL rot_x:SDWORD, rot_y:SDWORD (未使用)
    
    ; 获取旋转角度的sin/cos值
    mov edx, inAngle
    mov eax, cosTable[edx*4]
    mov cos_val, eax
    mov eax, sinTable[edx*4]
    mov sin_val, eax
    
    ; ========== 左上角 (-TANK_HALF_W, -TANK_HALF_H) ==========
    mov local_x, -TANK_HALF_W
    mov local_y, -TANK_HALF_H
    
    ; rot_x = local_x * cos - local_y * sin
    mov eax, local_x
    imul eax, cos_val
    mov ebx, local_y
    imul ebx, sin_val
    sub eax, ebx
    sar eax, 8              ; 除以256
    shl eax, 8              ; 转换为定点数
    add eax, destX          ; 使用 destX
    mov corner_x, eax
    
    ; rot_y = local_x * sin + local_y * cos
    mov eax, local_x
    imul eax, sin_val
    mov ebx, local_y
    imul ebx, cos_val
    add eax, ebx
    sar eax, 8              ; 除以256
    shl eax, 8              ; 转换为定点数
    add eax, destY          ; 使用 destY
    mov corner_y, eax
    
    invoke IsWall, corner_x, corner_y
    .if eax == 1
        mov eax, 0
        ret
    .endif
    
    ; ========== 右上角 (+TANK_HALF_W, -TANK_HALF_H) ==========
    mov local_x, TANK_HALF_W
    mov local_y, -TANK_HALF_H
    
    mov eax, local_x
    imul eax, cos_val
    mov ebx, local_y
    imul ebx, sin_val
    sub eax, ebx
    sar eax, 8
    shl eax, 8
    add eax, destX
    mov corner_x, eax
    
    mov eax, local_x
    imul eax, sin_val
    mov ebx, local_y
    imul ebx, cos_val
    add eax, ebx
    sar eax, 8
    shl eax, 8
    add eax, destY
    mov corner_y, eax
    
    invoke IsWall, corner_x, corner_y
    .if eax == 1
        mov eax, 0
        ret
    .endif
    
    ; ========== 左下角 (-TANK_HALF_W, +TANK_HALF_H) ==========
    mov local_x, -TANK_HALF_W
    mov local_y, TANK_HALF_H
    
    mov eax, local_x
    imul eax, cos_val
    mov ebx, local_y
    imul ebx, sin_val
    sub eax, ebx
    sar eax, 8
    shl eax, 8
    add eax, destX
    mov corner_x, eax
    
    mov eax, local_x
    imul eax, sin_val
    mov ebx, local_y
    imul ebx, cos_val
    add eax, ebx
    sar eax, 8
    shl eax, 8
    add eax, destY
    mov corner_y, eax
    
    invoke IsWall, corner_x, corner_y
    .if eax == 1
        mov eax, 0
        ret
    .endif
    
    ; ========== 右下角 (+TANK_HALF_W, +TANK_HALF_H) ==========
    mov local_x, TANK_HALF_W
    mov local_y, TANK_HALF_H
    
    mov eax, local_x
    imul eax, cos_val
    mov ebx, local_y
    imul ebx, sin_val
    sub eax, ebx
    sar eax, 8
    shl eax, 8
    add eax, destX
    mov corner_x, eax
    
    mov eax, local_x
    imul eax, sin_val
    mov ebx, local_y
    imul ebx, cos_val
    add eax, ebx
    sar eax, 8
    shl eax, 8
    add eax, destY
    mov corner_y, eax
    
    invoke IsWall, corner_x, corner_y
    .if eax == 1
        mov eax, 0
        ret
    .endif
    
    mov eax, 1
    ret
CheckTankMove endp

; --- 更新游戏逻辑 ---
UpdateGame proc
    LOCAL speed:DWORD
    LOCAL nextX:DWORD, nextY:DWORD

    .if p1.active == 0 || p2.active == 0
        ret
    .endif

    ; === 玩家1控制 ===
    invoke GetAsyncKeyState, 'A'
    test ax, 8000h
    .if !ZERO?
        mov eax, p1.angle
        sub eax, ROT_SPEED
        add eax, 360
        xor edx, edx
        mov ecx, 360
        div ecx
        mov p1.angle, edx
    .endif

    invoke GetAsyncKeyState, 'D'
    test ax, 8000h
    .if !ZERO?
        mov eax, p1.angle
        add eax, ROT_SPEED
        xor edx, edx
        mov ecx, 360
        div ecx
        mov p1.angle, edx
    .endif

    mov speed, 0
    invoke GetAsyncKeyState, 'W'
    test ax, 8000h
    .if !ZERO?
        mov speed, TANK_SPEED
    .endif
    invoke GetAsyncKeyState, 'S'
    test ax, 8000h
    .if !ZERO?
        mov speed, -TANK_SPEED
    .endif

    .if speed != 0
        mov edx, p1.angle
        mov eax, cosTable[edx*4]
        imul eax, speed
        sar eax, 8
        add eax, p1.pos_x
        mov nextX, eax

        mov edx, p1.angle
        mov eax, sinTable[edx*4]
        imul eax, speed
        sar eax, 8
        add eax, p1.pos_y
        mov nextY, eax

        ; 【修改】调用新名字函数
        invoke CheckTankMove, nextX, nextY, p1.angle
        .if eax == 1
            mov eax, nextX
            mov p1.pos_x, eax
            mov eax, nextY
            mov p1.pos_y, eax
        .endif
    .endif

    .if p1.cooldown > 0
        dec p1.cooldown
    .endif
    invoke GetAsyncKeyState, 'J'
    test ax, 8000h
    .if !ZERO? && p1.cooldown == 0
        invoke FireBullet, addr p1
    .endif

    ; === 玩家2控制 ===
    invoke GetAsyncKeyState, VK_LEFT
    test ax, 8000h
    .if !ZERO?
        mov eax, p2.angle
        sub eax, ROT_SPEED
        add eax, 360
        xor edx, edx
        mov ecx, 360
        div ecx
        mov p2.angle, edx
    .endif

    invoke GetAsyncKeyState, VK_RIGHT
    test ax, 8000h
    .if !ZERO?
        mov eax, p2.angle
        add eax, ROT_SPEED
        xor edx, edx
        mov ecx, 360
        div ecx
        mov p2.angle, edx
    .endif

    mov speed, 0
    invoke GetAsyncKeyState, VK_UP
    test ax, 8000h
    .if !ZERO?
        mov speed, TANK_SPEED
    .endif
    invoke GetAsyncKeyState, VK_DOWN
    test ax, 8000h
    .if !ZERO?
        mov speed, -TANK_SPEED
    .endif

    .if speed != 0
        mov edx, p2.angle
        mov eax, cosTable[edx*4]
        imul eax, speed
        sar eax, 8
        add eax, p2.pos_x
        mov nextX, eax

        mov edx, p2.angle
        mov eax, sinTable[edx*4]
        imul eax, speed
        sar eax, 8
        add eax, p2.pos_y
        mov nextY, eax

        ; 【修改】调用新名字函数
        invoke CheckTankMove, nextX, nextY, p2.angle
        .if eax == 1
            mov eax, nextX
            mov p2.pos_x, eax
            mov eax, nextY
            mov p2.pos_y, eax
        .endif
    .endif

    .if p2.cooldown > 0
        dec p2.cooldown
    .endif
    
    ; 只在menuAnimTick为0时检测射击，防止菜单Enter键误触发
    mov eax, menuAnimTick
    .if eax == 0
        invoke GetAsyncKeyState, VK_RETURN
        test ax, 8000h
        .if !ZERO? && p2.cooldown == 0
            invoke FireBullet, addr p2
        .endif
    .endif

    ; === 子弹逻辑 ===
    mov ecx, 0
    .while ecx < MAX_BULLETS
        push ecx
        mov ebx, ecx
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]

        mov eax, (BULLET PTR [esi]).active
        .if eax != 0
            ; 移动X
            mov eax, (BULLET PTR [esi]).pos_x
            add eax, (BULLET PTR [esi]).vel_x
            mov nextX, eax
            
            invoke IsWall, nextX, (BULLET PTR [esi]).pos_y
            .if eax == 1
                mov eax, (BULLET PTR [esi]).vel_x
                neg eax
                mov (BULLET PTR [esi]).vel_x, eax
                dec (BULLET PTR [esi]).bounces
            .else
                mov eax, nextX
                mov (BULLET PTR [esi]).pos_x, eax
            .endif

            ; 移动Y
            mov eax, (BULLET PTR [esi]).pos_y
            add eax, (BULLET PTR [esi]).vel_y
            mov nextY, eax
            
            invoke IsWall, (BULLET PTR [esi]).pos_x, nextY
            .if eax == 1
                mov eax, (BULLET PTR [esi]).vel_y
                neg eax
                mov (BULLET PTR [esi]).vel_y, eax
                dec (BULLET PTR [esi]).bounces
            .else
                mov eax, nextY
                mov (BULLET PTR [esi]).pos_y, eax
            .endif

            ; 碰撞检测 - 玩家1
            mov eax, (BULLET PTR [esi]).pos_x
            sub eax, p1.pos_x
            test eax, eax
            .if SIGN?
                neg eax
            .endif
            .if eax < TANK_HALF_W * SCALE
                mov eax, (BULLET PTR [esi]).pos_y
                sub eax, p1.pos_y
                test eax, eax
                .if SIGN?
                    neg eax
                .endif
                .if eax < TANK_HALF_H * SCALE
                    mov p1.active, 0
                    mov (BULLET PTR [esi]).active, 0
                .endif
            .endif

            ; 碰撞检测 - 玩家2
            mov eax, (BULLET PTR [esi]).pos_x
            sub eax, p2.pos_x
            test eax, eax
            .if SIGN?
                neg eax
            .endif
            .if eax < TANK_HALF_W * SCALE
                mov eax, (BULLET PTR [esi]).pos_y
                sub eax, p2.pos_y
                test eax, eax
                .if SIGN?
                    neg eax
                .endif
                .if eax < TANK_HALF_H * SCALE
                    mov p2.active, 0
                    mov (BULLET PTR [esi]).active, 0
                .endif
            .endif

            ; 检查弹跳次数
            cmp (BULLET PTR [esi]).bounces, 0
            .if SIGN?
                mov (BULLET PTR [esi]).active, 0
            .endif
        .endif

        pop ecx
        inc ecx
    .endw
    ret
UpdateGame endp

; --- 发射子弹 ---
FireBullet proc pTank:DWORD
    LOCAL offset_val:DWORD
    
    mov ecx, 0
    .while ecx < MAX_BULLETS
        push ecx
        mov ebx, ecx
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]
        
        mov eax, (BULLET PTR [esi]).active
        .if eax == 0
            mov (BULLET PTR [esi]).active, 1
            
            mov edi, pTank
            ASSUME edi:PTR TANK
            
            mov offset_val, 35
            
            ; 计算子弹初始位置
            mov edx, [edi].angle
            mov eax, cosTable[edx*4]
            imul eax, offset_val
            add eax, [edi].pos_x
            mov (BULLET PTR [esi]).pos_x, eax
            
            mov edx, [edi].angle
            mov eax, sinTable[edx*4]
            imul eax, offset_val
            add eax, [edi].pos_y
            mov (BULLET PTR [esi]).pos_y, eax
            
            ; 计算子弹速度
            mov edx, [edi].angle
            mov eax, cosTable[edx*4]
            imul eax, BULLET_SPEED
            sar eax, 8
            mov (BULLET PTR [esi]).vel_x, eax
            
            mov edx, [edi].angle
            mov eax, sinTable[edx*4]
            imul eax, BULLET_SPEED
            sar eax, 8
            mov (BULLET PTR [esi]).vel_y, eax
            
            mov (BULLET PTR [esi]).bounces, 7
            mov [edi].cooldown, 20
            
            ASSUME edi:nothing
            pop ecx
            ret
        .endif
        
        pop ecx
        inc ecx
    .endw
    ret
FireBullet endp