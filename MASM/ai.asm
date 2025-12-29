; ========================================
; AI.asm - AI对手逻辑
; ========================================

; --- 更新 AI 行为 ---
UpdateAI proc
    LOCAL dx:SDWORD, dy:SDWORD
    LOCAL distance:DWORD
    LOCAL targetAngle:DWORD
    LOCAL angleDiff:SDWORD
    LOCAL speed:SDWORD
    LOCAL nextX:DWORD, nextY:DWORD
    LOCAL shouldFire:DWORD
    
    .if aiEnabled == 0 || p2.active == 0 || p1.active == 0
        ret
    .endif
    
    ; ========== 计算到玩家的距离和方向 ==========
    mov eax, p1.pos_x
    sub eax, p2.pos_x
    sar eax, 8                  ; 转换为实际像素
    mov dx, eax
    
    mov eax, p1.pos_y
    sub eax, p2.pos_y
    sar eax, 8
    mov dy, eax
    
    ; 计算距离（曼哈顿距离）
    mov eax, dx
    test eax, eax
    .if SIGN?
        neg eax
    .endif
    mov ebx, dy
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
    invoke CalculateAngleToTarget, dx, dy
    mov targetAngle, eax
    
    ; ========== 转向目标 ==========
    mov eax, targetAngle
    movsx ebx, WORD PTR p2.angle
    sub eax, ebx
    
    ; 标准化角度差 (-180 到 180)
    .if eax > 180
        sub eax, 360
    .elseif eax < -180
        add eax, 360
    .endif
    mov angleDiff, eax
    
    ; 根据角度差决定旋转方向
    .if angleDiff > 5
        mov eax, p2.angle
        add eax, ROT_SPEED
        .if eax >= 360
            sub eax, 360
        .endif
        mov p2.angle, eax
    .elseif angleDiff < -5
        mov eax, p2.angle
        sub eax, ROT_SPEED
        .if SIGN?
            add eax, 360
        .endif
        mov p2.angle, eax
    .endif
    
    ; ========== 移动策略 ==========
    mov speed, 0
    
    mov eax, aiDifficulty
    .if eax == AI_EASY
        ; 简单：只要距离>100就前进
        .if distance > 100
            mov speed, TANK_SPEED
        .endif
    .elseif eax == AI_MEDIUM
        ; 中等：保持合理距离
        .if distance > 180
            mov speed, TANK_SPEED
        .elseif distance < 80
            mov speed, -TANK_SPEED
        .else
            ; 中等距离，小幅度移动
            invoke crt_rand
            xor edx, edx
            mov ecx, 3
            div ecx
            .if edx == 0
                mov speed, TANK_SPEED / 2
            .endif
        .endif
    .else
        ; 困难：智能走位
        .if distance > 200
            mov speed, TANK_SPEED
        .elseif distance < 60
            mov speed, -TANK_SPEED
        .else
            ; 横向移动策略
            invoke crt_rand
            xor edx, edx
            mov ecx, 4
            div ecx
            .if edx == 0
                mov speed, TANK_SPEED
            .elseif edx == 1
                mov speed, -TANK_SPEED
            .endif
        .endif
    .endif
    
    ; ========== 执行移动 ==========
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
        
        invoke CheckTankMove, nextX, nextY, p2.angle
        .if eax == 1
            mov eax, nextX
            mov p2.pos_x, eax
            mov eax, nextY
            mov p2.pos_y, eax
        .else
            ; 碰墙了，随机转向
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
    
    mov shouldFire, 0
    
    ; 根据难度决定射击频率
    mov eax, aiDifficulty
    .if eax == AI_EASY
        ; 简单：距离近 + 角度大致对准 + 随机因子
        .if distance < 250
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
                .if edx == 0
                    mov shouldFire, 1
                .endif
            .endif
        .endif
    .elseif eax == AI_MEDIUM
        ; 中等：角度较准就射
        .if distance < 300
            mov eax, angleDiff
            test eax, eax
            .if SIGN?
                neg eax
            .endif
            .if eax < 12
                invoke crt_rand
                xor edx, edx
                mov ecx, 8
                div ecx
                .if edx < 2
                    mov shouldFire, 1
                .endif
            .endif
        .endif
    .else
        ; 困难：精确瞄准
        mov eax, angleDiff
        test eax, eax
        .if SIGN?
            neg eax
        .endif
        .if eax < 8
            invoke crt_rand
            xor edx, edx
            mov ecx, 5
            div ecx
            .if edx < 3
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
CalculateAngleToTarget proc dx:SDWORD, dy:SDWORD
    LOCAL bestAngle:DWORD
    LOCAL i:DWORD
    LOCAL maxDot:SDWORD
    LOCAL currentDot:SDWORD
    
    mov maxDot, -999999
    mov bestAngle, 0
    mov i, 0
    
    .while i < 360
        ; 计算点积：cos(angle)*dx + sin(angle)*dy
        mov edx, i
        mov eax, cosTable[edx*4]
        sar eax, 8
        imul eax, dx
        mov currentDot, eax
        
        mov edx, i
        mov eax, sinTable[edx*4]
        sar eax, 8
        imul eax, dy
        add currentDot, eax
        
        ; 找最大点积
        mov eax, currentDot
        .if eax > maxDot
            mov maxDot, eax
            mov eax, i
            mov bestAngle, eax
        .endif
        
        add i, 5
    .endw
    
    mov eax, bestAngle
    ret
CalculateAngleToTarget endp

; --- 检查危险子弹 ---
CheckDangerousBullets proc uses esi
    LOCAL i:DWORD
    LOCAL dx:SDWORD, dy:SDWORD
    LOCAL dist:DWORD
    
    mov i, 0
    .while i < MAX_BULLETS
        mov ebx, i
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]
        
        mov eax, (BULLET PTR [esi]).active
        .if eax != 0
            ; 检查是否是玩家1的子弹
            lea eax, p1
            .if (BULLET PTR [esi]).owner == eax
                ; 计算距离
                mov eax, (BULLET PTR [esi]).pos_x
                sub eax, p2.pos_x
                sar eax, 8
                mov dx, eax
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
