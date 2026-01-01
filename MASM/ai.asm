; ========================================
; AI.asm - AI对手逻辑
; ========================================

; --- AI卡死检测 ---
.data
aiStuckCounter dd 0
aiLastX dd 0
aiLastY dd 0

.code

; --- 更新 AI 行为 ---
UpdateAI proc
    LOCAL delta_x:SDWORD, delta_y:SDWORD
    LOCAL distance:DWORD
    LOCAL targetAngle:DWORD
    LOCAL angleDiff:SDWORD
    LOCAL speed:SDWORD
    LOCAL nextX:DWORD, nextY:DWORD
    LOCAL shouldFire:DWORD
    LOCAL posChanged:DWORD
    LOCAL moveSuccess:DWORD
    
    .if aiEnabled == 0 || p2.active == 0 || p1.active == 0
        ret
    .endif
    
    ; ========== 检测是否卡死 ==========
    mov posChanged, 0
    mov eax, p2.pos_x
    mov ebx, aiLastX
    sub eax, ebx
    test eax, eax
    .if SIGN?
        neg eax
    .endif
    .if eax > 5 * SCALE
        mov posChanged, 1
    .endif
    
    .if posChanged == 0
        mov eax, p2.pos_y
        mov ebx, aiLastY
        sub eax, ebx
        test eax, eax
        .if SIGN?
            neg eax
        .endif
        .if eax > 5 * SCALE
            mov posChanged, 1
        .endif
    .endif
    
    .if posChanged == 1
        ; 位置改变了，重置卡死计数器
        mov aiStuckCounter, 0
    .else
        ; 位置没变，增加卡死计数
        inc aiStuckCounter
        .if aiStuckCounter > 30
            ; 卡死超过30帧，强制随机转向并尝试移动
            invoke crt_rand
            xor edx, edx
            mov ecx, 360
            div ecx
            mov p2.angle, edx
            mov aiStuckCounter, 0
        .endif
    .endif
    
    ; 保存当前位置
    mov eax, p2.pos_x
    mov aiLastX, eax
    mov eax, p2.pos_y
    mov aiLastY, eax
    
    ; ========== 计算到玩家的距离和方向 ==========
    mov eax, p1.pos_x
    sub eax, p2.pos_x
    sar eax, 8                  ; 转换为实际像素
    mov delta_x, eax
    
    mov eax, p1.pos_y
    sub eax, p2.pos_y
    sar eax, 8
    mov delta_y, eax
    
    ; 计算距离（曼哈顿距离）
    mov eax, delta_x
    test eax, eax
    .if SIGN?
        neg eax
    .endif
    mov ebx, delta_y
    test ebx, ebx
    .if SIGN?
        neg ebx
    .endif
    add eax, ebx
    mov distance, eax
    
    ; ========== 检查是否需要躲避子弹 ==========
    invoke CheckDangerousBullets
    .if eax == 1
        invoke EvadeBullet
        jmp @FireCheck
    .endif
    
    ; ========== 根据难度决定行为 ==========
    mov eax, aiDifficulty
    .if eax == AI_EASY
        ; 简单AI：40%概率随机移动
        invoke crt_rand
        xor edx, edx
        mov ecx, 10
        div ecx
        .if edx < 4
            invoke RandomMove
            jmp @FireCheck
        .endif
    .endif
    
    ; ========== 计算目标角度 ==========
    invoke CalculateAngleToTarget, delta_x, delta_y
    mov targetAngle, eax
    
    ; ========== 转向目标 ==========
    mov eax, targetAngle
    mov ebx, p2.angle
    sub eax, ebx
    
    ; 标准化角度差 (-180 到 180) - 简化逻辑
    cmp eax, 180
    jle @@check_neg_turn
    sub eax, 360
    jmp @@norm_done_turn
@@check_neg_turn:
    cmp eax, -180
    jge @@norm_done_turn
    add eax, 360
@@norm_done_turn:
    mov angleDiff, eax
    
    ; 根据角度差决定旋转方向
    .if angleDiff > 5
        mov eax, p2.angle
        add eax, ROT_SPEED
        cmp eax, 360
        jl @@angle_ok1
        sub eax, 360
@@angle_ok1:
        mov p2.angle, eax
    .elseif angleDiff < -5
        mov eax, p2.angle
        sub eax, ROT_SPEED
        cmp eax, 0
        jge @@angle_ok2
        add eax, 360
@@angle_ok2:
        mov p2.angle, eax
    .endif
    
    ; ========== 移动策略 ==========
    mov speed, 0
    
    mov eax, aiDifficulty
    .if eax == AI_EASY
        ; 简单：距离太近就后退（<50），否则前进
        .if distance < 50
            mov speed, -TANK_SPEED
        .else
            mov speed, TANK_SPEED
        .endif
    .elseif eax == AI_MEDIUM
        ; 中等：稍微灵活，距离很近后退，否则前进
        .if distance < 60
            mov speed, -TANK_SPEED
        .else
            ; 70%概率前进，30%概率停止
            invoke crt_rand
            xor edx, edx
            mov ecx, 10
            div ecx
            .if edx < 7
                mov speed, TANK_SPEED
            .endif
        .endif
    .else
        ; 困难：主动进攻，距离非常近才后退
        .if distance < 40
            mov speed, -TANK_SPEED
        .else
            ; 80%概率前进，20%概率停止
            invoke crt_rand
            xor edx, edx
            mov ecx, 10
            div ecx
            .if edx < 8
                mov speed, TANK_SPEED
            .endif
        .endif
    .endif
    
    ; ========== 执行移动 ==========
    .if speed != 0
        mov moveSuccess, 0  ; 标记变量：记录是否至少有一个方向移动成功

        ; --- 尝试 X 轴移动 ---
        mov edx, p2.angle
        mov eax, cosTable[edx*4]
        imul eax, speed
        sar eax, 8
        add eax, p2.pos_x
        mov nextX, eax
        
        invoke CheckTankMove, nextX, p2.pos_y, p2.angle
        .if eax == 1
            mov eax, nextX
            mov p2.pos_x, eax
            mov moveSuccess, 1  ; X轴移动成功
        .endif
        
        ; --- 尝试 Y 轴移动 ---
        mov edx, p2.angle
        mov eax, sinTable[edx*4]
        imul eax, speed
        sar eax, 8
        add eax, p2.pos_y
        mov nextY, eax
        
        invoke CheckTankMove, p2.pos_x, nextY, p2.angle
        .if eax == 1
            mov eax, nextY
            mov p2.pos_y, eax
            mov moveSuccess, 1  ; Y轴移动成功
        .endif
        
        ; --- 卡死检测补充 ---
        ; 如果 X 和 Y 都没动（moveSuccess == 0），说明完全卡死了
        ; 此时才执行随机转向，防止 AI 对着墙发呆
        .if moveSuccess == 0
            invoke crt_rand
            and eax, 1
            .if eax == 0
                mov eax, p2.angle
                add eax, 45
            .else
                mov eax, p2.angle
                sub eax, 45
                add eax, 360
            .endif
            xor edx, edx
            mov ecx, 360
            div ecx
            mov p2.angle, edx
        .endif
    .endif
    
@FireCheck:
    ; ========== 射击逻辑 ==========
    .if p2.cooldown > 0
        dec p2.cooldown
    .endif
    
    .if p2.cooldown > 0
        ret
    .endif
    
    ; ========== 视线检查：只在能直接看到玩家时射击 ==========
    invoke CheckLineOfSight
    .if eax == 0
        ; 视线被遮挡，不射击（避免需要反弹）
        ret
    .endif
    
    ; ========== 视线清晰时的安全检查 ==========
    ; 视线清晰说明中间没有墙，但还要检查前方4格是否安全
    invoke CheckWallAhead
    .if eax == 1
        ; 前方有近距离墙壁，不射击
        ret
    .endif
    
    ; ========== 视线清晰时不需要检查正方向角度限制，可以直接瞄准 ==========
    ; （如果视线清晰，说明子弹不需要反弹就能击中目标）
    
    ; 重新计算当前角度与目标角度的差值用于射击判断
    mov eax, targetAngle
    mov ebx, p2.angle
    sub eax, ebx
    
    ; 标准化角度差 (-180 到 180)
    cmp eax, 180
    jle @@check_negative
    sub eax, 360
    jmp @@norm_done
@@check_negative:
    cmp eax, -180
    jge @@norm_done
    add eax, 360
@@norm_done:
    mov angleDiff, eax
    
    mov shouldFire, 0
    
    ; 根据难度决定射击频率（更主动，放宽角度要求）
    mov eax, aiDifficulty
    .if eax == AI_EASY
        ; 简单：角度容差大（30度），低频率（10%）
        mov eax, angleDiff
        test eax, eax
        .if SIGN?
            neg eax
        .endif
        .if eax < 30
            invoke crt_rand
            xor edx, edx
            mov ecx, 30
            div ecx
            .if edx < 3
                mov shouldFire, 1
            .endif
        .endif
    .elseif eax == AI_MEDIUM
        ; 中等：角度容差中（20度），中频率（20%）
        mov eax, angleDiff
        test eax, eax
        .if SIGN?
            neg eax
        .endif
        .if eax < 20
            invoke crt_rand
            xor edx, edx
            mov ecx, 25
            div ecx
            .if edx < 5
                mov shouldFire, 1
            .endif
        .endif
    .else
        ; 困难：角度容差小（15度），高频率（35%）
        mov eax, angleDiff
        test eax, eax
        .if SIGN?
            neg eax
        .endif
        .if eax < 15
            invoke crt_rand
            xor edx, edx
            mov ecx, 20
            div ecx
            .if edx < 7
                mov shouldFire, 1
            .endif
        .endif
    .endif
    
    .if shouldFire == 1
        invoke FireBullet, addr p2
    .endif
    
    ret
UpdateAI endp

; --- 计算到目标的角度 ---
CalculateAngleToTarget proc delta_x:SDWORD, delta_y:SDWORD
    LOCAL bestAngle:DWORD
    LOCAL i:DWORD
    LOCAL maxDot:SDWORD
    LOCAL currentDot:SDWORD
    
    mov maxDot, -999999
    mov bestAngle, 0
    mov i, 0
    
    .while i < 360
        ; 计算点积：cos(angle)*delta_x + sin(angle)*delta_y
        mov ecx, i
        mov eax, cosTable[ecx*4]
        sar eax, 8
        imul delta_x
        mov currentDot, eax
        
        mov ecx, i
        mov eax, sinTable[ecx*4]
        sar eax, 8
        imul delta_y
        add currentDot, eax
        
        ; 找最大点积
        mov eax, currentDot
        cmp eax, maxDot
        jle @@skip
        mov maxDot, eax
        mov eax, i
        mov bestAngle, eax
@@skip:
        
        add i, 5
    .endw
    
    mov eax, bestAngle
    ret
CalculateAngleToTarget endp

; --- 检查危险子弹 ---
CheckDangerousBullets proc uses esi
    LOCAL i:DWORD
    LOCAL delta_x:SDWORD, delta_y:SDWORD
    LOCAL dist:DWORD
    
    mov i, 0
    .while i < MAX_BULLETS
        mov ebx, i
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]
        
        mov eax, (BULLET PTR [esi]).active
        .if eax != 0
            ; 检查是否是玩家1的子弹
            lea edx, p1
            mov eax, (BULLET PTR [esi]).owner
            .if eax == edx
                ; 计算距离
                mov eax, (BULLET PTR [esi]).pos_x
                sub eax, p2.pos_x
                sar eax, 8
                mov delta_x, eax
                test eax, eax
                .if SIGN?
                    neg eax
                .endif
                mov dist, eax
                
                mov eax, (BULLET PTR [esi]).pos_y
                sub eax, p2.pos_y
                sar eax, 8
                test eax, eax
                .if SIGN?
                    neg eax
                .endif
                add dist, eax
                
                ; 危险距离阈值（根据难度）
                mov ecx, aiDifficulty
                .if ecx == AI_EASY
                    mov ecx, 60
                .elseif ecx == AI_MEDIUM
                    mov ecx, 90
                .else
                    mov ecx, 120
                .endif
                
                .if dist < ecx
                    mov eax, 1
                    ret
                .endif
            .endif
        .endif
        
        inc i
    .endw
    
    xor eax, eax
    ret
CheckDangerousBullets endp

; --- 规避子弹 ---
EvadeBullet proc
    LOCAL nextX:DWORD, nextY:DWORD
    LOCAL dodgeAngle:DWORD
    
    ; 随机选择左转或右转90度
    invoke crt_rand
    and eax, 1
    .if eax == 0
        mov eax, p2.angle
        add eax, 90
    .else
        mov eax, p2.angle
        sub eax, 90
        add eax, 360
    .endif
    xor edx, edx
    mov ecx, 360
    div ecx
    mov dodgeAngle, edx
    
    ; 向选定方向移动
    mov edx, dodgeAngle
    mov eax, cosTable[edx*4]
    imul eax, TANK_SPEED
    sar eax, 8
    add eax, p2.pos_x
    mov nextX, eax
    
    mov edx, dodgeAngle
    mov eax, sinTable[edx*4]
    imul eax, TANK_SPEED
    sar eax, 8
    add eax, p2.pos_y
    mov nextY, eax
    
    invoke CheckTankMove, nextX, nextY, p2.angle
    .if eax == 1
        mov eax, nextX
        mov p2.pos_x, eax
        mov eax, nextY
        mov p2.pos_y, eax
    .else
        ; 这个方向不行，试试反方向
        mov eax, dodgeAngle
        add eax, 180
        xor edx, edx
        mov ecx, 360
        div ecx
        mov dodgeAngle, edx
        
        mov edx, dodgeAngle
        mov eax, cosTable[edx*4]
        imul eax, TANK_SPEED
        sar eax, 8
        add eax, p2.pos_x
        mov nextX, eax
        
        mov edx, dodgeAngle
        mov eax, sinTable[edx*4]
        imul eax, TANK_SPEED
        sar eax, 8
        add eax, p2.pos_y
        mov nextY, eax
        
        invoke CheckTankMove, nextX, nextY, p2.angle
        .if eax == 1
            mov eax, nextX
            mov p2.pos_x, eax
            mov eax, nextY
            mov p2.pos_y, eax
        .endif
    .endif
    
    ret
EvadeBullet endp

; --- 随机移动 ---
RandomMove proc
    LOCAL nextX:DWORD, nextY:DWORD
    LOCAL speed:SDWORD
    
    invoke crt_rand
    xor edx, edx
    mov ecx, 5
    div ecx
    
    .if edx == 0
        ; 前进
        mov speed, TANK_SPEED
    .elseif edx == 1
        ; 后退
        mov speed, -TANK_SPEED
    .elseif edx == 2
        ; 左转
        mov eax, p2.angle
        sub eax, ROT_SPEED * 2
        add eax, 360
        xor edx, edx
        mov ecx, 360
        div ecx
        mov p2.angle, edx
        ret
    .elseif edx == 3
        ; 右转
        mov eax, p2.angle
        add eax, ROT_SPEED * 2
        xor edx, edx
        mov ecx, 360
        div ecx
        mov p2.angle, edx
        ret
    .else
        ; 停留
        ret
    .endif
    
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
    
    invoke CheckTankMove, nextX, nextY, p2.angle
    .if eax == 1
        mov eax, nextX
        mov p2.pos_x, eax
        mov eax, nextY
        mov p2.pos_y, eax
    .endif
    
    ret
RandomMove endp

; --- 检查前方是否有近距离墙壁 ---
CheckWallAhead proc
    LOCAL checkX:DWORD, checkY:DWORD
    LOCAL wallX:DWORD, wallY:DWORD
    LOCAL checkDist:DWORD
    LOCAL step:DWORD
    
    ; 检查前方4个格子（4 * BLOCK_SIZE）
    mov checkDist, BLOCK_SIZE * 4
    
    ; 分4步检查，每格子检查一次
    mov step, 1
@@check_loop:
    cmp step, 5
    jae @@no_wall
    
    ; 计算检查点位置
    mov eax, step
    imul eax, BLOCK_SIZE
    mov checkDist, eax
    
    mov edx, p2.angle
    mov eax, cosTable[edx*4]
    imul eax, checkDist
    add eax, p2.pos_x
    mov checkX, eax
    
    mov edx, p2.angle
    mov eax, sinTable[edx*4]
    imul eax, checkDist
    add eax, p2.pos_y
    mov checkY, eax
    
    ; 转换为地图坐标
    mov eax, checkX
    sar eax, 8
    xor edx, edx
    mov ecx, BLOCK_SIZE
    div ecx
    mov wallX, eax
    
    mov eax, checkY
    sar eax, 8
    xor edx, edx
    mov ecx, BLOCK_SIZE
    div ecx
    mov wallY, eax
    
    ; 边界检查
    cmp wallX, MAP_COLS
    jae @@has_wall
    cmp wallY, MAP_ROWS
    jae @@has_wall
    
    ; 检查该位置是否是墙
    mov eax, wallY
    imul eax, MAP_COLS
    add eax, wallX
    shl eax, 2
    lea edi, map
    add edi, eax
    mov eax, DWORD PTR [edi]
    test eax, eax
    jnz @@has_wall
    
    ; 继续检查下一个格子
    inc step
    jmp @@check_loop
    
@@has_wall:
    mov eax, 1
    ret
    
@@no_wall:
    xor eax, eax
    ret
CheckWallAhead endp

; --- 检查到玩家的视线是否清晰（无墙壁遮挡） ---
CheckLineOfSight proc
    LOCAL x1:SDWORD, y1:SDWORD
    LOCAL x2:SDWORD, y2:SDWORD
    LOCAL delta_x:SDWORD, delta_y:SDWORD
    LOCAL steps:DWORD, i:DWORD
    LOCAL currentX:SDWORD, currentY:SDWORD
    LOCAL gridX:DWORD, gridY:DWORD
    
    ; 获取AI位置（像素）
    mov eax, p2.pos_x
    sar eax, 8
    mov x1, eax
    mov eax, p2.pos_y
    sar eax, 8
    mov y1, eax
    
    ; 获取玩家位置（像素）
    mov eax, p1.pos_x
    sar eax, 8
    mov x2, eax
    mov eax, p1.pos_y
    sar eax, 8
    mov y2, eax
    
    ; 计算方向向量
    mov eax, x2
    sub eax, x1
    mov delta_x, eax
    mov eax, y2
    sub eax, y1
    mov delta_y, eax
    
    ; 计算步数（使用曼哈顿距离）
    mov eax, delta_x
    test eax, eax
    .if SIGN?
        neg eax
    .endif
    mov ebx, delta_y
    test ebx, ebx
    .if SIGN?
        neg ebx
    .endif
    add eax, ebx
    mov steps, eax
    
    ; 如果距离太近，直接返回视线清晰
    .if steps < 20
        mov eax, 1
        ret
    .endif
    
    ; 每10像素检查一次
    xor edx, edx
    mov ecx, 10
    div ecx
    mov steps, eax
    
    ; 限制最大检查步数
    .if steps > 50
        mov steps, 50
    .endif
    
    ; 使用低级循环代替.while
    mov i, 1
@@loop_start:
    mov eax, i
    cmp eax, steps
    jae @@loop_end
    
    ; 计算当前检查点位置
    mov eax, delta_x
    mov ebx, i
    imul ebx
    mov ebx, steps
    cdq
    idiv ebx
    add eax, x1
    mov currentX, eax
    
    mov eax, delta_y
    mov ebx, i
    imul ebx
    mov ebx, steps
    cdq
    idiv ebx
    add eax, y1
    mov currentY, eax
    
    ; 转换为地图格子坐标
    mov eax, currentX
    cdq
    mov ecx, BLOCK_SIZE
    idiv ecx
    mov gridX, eax
    
    mov eax, currentY
    cdq
    mov ecx, BLOCK_SIZE
    idiv ecx
    mov gridY, eax
    
    ; 边界检查（检查是否为负数或超出范围）
    mov eax, gridX
    test eax, eax
    js @@out_of_bounds
    cmp eax, MAP_COLS
    jae @@out_of_bounds
    
    mov eax, gridY
    test eax, eax
    js @@out_of_bounds
    cmp eax, MAP_ROWS
    jae @@out_of_bounds
    
    ; 检查是否有墙
    mov eax, gridY
    imul eax, MAP_COLS
    add eax, gridX
    shl eax, 2
    lea edi, map
    add edi, eax
    mov eax, DWORD PTR [edi]
    test eax, eax
    jnz @@out_of_bounds
    
    ; 继续下一个检查点
    inc i
    jmp @@loop_start

@@out_of_bounds:
    xor eax, eax
    ret

@@loop_end:
    
    ; 视线清晰
    mov eax, 1
    ret
CheckLineOfSight endp
