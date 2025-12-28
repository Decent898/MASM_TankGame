; ========================================
; GameLogic.asm - 游戏核心逻辑
; ========================================

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
    ret
InitMap endp

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

; --- 检查坦克是否可以移动 ---
CanMove proc targetX:DWORD, targetY:DWORD
    LOCAL r:DWORD
    mov r, TANK_HALF_W * SCALE

    ; 检查四个角
    mov eax, targetX
    sub eax, r
    mov ecx, targetY
    sub ecx, r
    invoke IsWall, eax, ecx
    .if eax == 1
        mov eax, 0
        ret
    .endif

    mov eax, targetX
    add eax, r
    mov ecx, targetY
    sub ecx, r
    invoke IsWall, eax, ecx
    .if eax == 1
        mov eax, 0
        ret
    .endif

    mov eax, targetX
    sub eax, r
    mov ecx, targetY
    add ecx, r
    invoke IsWall, eax, ecx
    .if eax == 1
        mov eax, 0
        ret
    .endif

    mov eax, targetX
    add eax, r
    mov ecx, targetY
    add ecx, r
    invoke IsWall, eax, ecx
    .if eax == 1
        mov eax, 0
        ret
    .endif

    mov eax, 1
    ret
CanMove endp

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

        invoke CanMove, nextX, nextY
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

        invoke CanMove, nextX, nextY
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
