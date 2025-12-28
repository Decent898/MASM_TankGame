.386
.model flat, stdcall
option casemap :none

; --- Includes ---
include C:\masm32\include\windows.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\gdi32.inc
include C:\masm32\include\msvcrt.inc

includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\gdi32.lib
includelib C:\masm32\lib\msvcrt.lib

; --- Constants ---
WINDOW_W        equ 800
WINDOW_H        equ 600
MAP_COLS        equ 20
MAP_ROWS        equ 15
BLOCK_SIZE      equ 40
SCALE           equ 256
TANK_SPEED      equ (2 * SCALE)
ROT_SPEED       equ 4
BULLET_SPEED    equ (6 * SCALE)
MAX_BULLETS     equ 20
TANK_RADIUS     equ 15
TIMER_ID        equ 1

; --- Structs ---
TANK STRUCT
    pos_x       dd ?
    pos_y       dd ?
    angle       dd ?
    color       dd ?
    cooldown    dd ?
    active      dd ?
TANK ENDS

BULLET STRUCT
    active      dd ?
    pos_x       dd ?
    pos_y       dd ?
    vel_x       dd ?
    vel_y       dd ?
    bounces     dd ?
BULLET ENDS

; --- Data ---
.data
    szClassName db "TankClass", 0
    szAppName   db "MASM Tank Battle", 0
    szP1Win     db "PLAYER 1 WINS!", 0
    szP2Win     db "PLAYER 2 WINS!", 0
    szNoBullet  db "No Active Bullets", 0
    
    ; 调试文字格式 (虽然界面关了，但数据留着不报错)
    szFmtP1     db "P1 Pos: (%d, %d) Angle: %d", 0
    szFmtBullet db "Bullet[%d]: (%d, %d)", 0
    szFmtDist   db "Distance to P1: %d px (Safe > 15)", 0

    double_PI   dq 3.141592653589793
    double_180  dq 180.0
    double_256  dq 256.0

    map         dd MAP_ROWS * MAP_COLS dup(0)
    sinTable    dd 360 dup(0)
    cosTable    dd 360 dup(0)
    bullets     BULLET MAX_BULLETS dup(<0,0,0,0,0,0>)

    p1          TANK <0,0,0,0,0,0>
    p2          TANK <0,0,0,0,0,0>

.data?
    hInstance   dd ?
    hWnd        dd ?
    buffer      db 128 dup(?)

; --- Code ---
.code

; Forward declarations
InitGame        PROTO
InitMap         PROTO
Update          PROTO
Draw            PROTO :DWORD
DrawOneTank     PROTO :DWORD, :DWORD
FireBullet      PROTO :DWORD
IsWall          PROTO :DWORD, :DWORD
CanMove         PROTO :DWORD, :DWORD
WinMain         PROTO :DWORD, :DWORD, :DWORD, :DWORD

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, 0

WinMain proc hInst:DWORD, hPrevInst:DWORD, CmdLine:DWORD, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hWindow:DWORD

    mov eax, hPrevInst
    mov eax, CmdLine

    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    push hInst
    pop wc.hInstance
    mov wc.hIcon, NULL
    mov wc.hCursor, NULL
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.hbrBackground, COLOR_WINDOW+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset szClassName
    mov wc.hIconSm, NULL

    invoke RegisterClassEx, addr wc
    invoke CreateWindowEx, 0, addr szClassName, addr szAppName, \
           WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, \
           WINDOW_W, WINDOW_H, NULL, NULL, hInst, NULL
    mov hWindow, eax

    invoke ShowWindow, hWindow, CmdShow
    invoke UpdateWindow, hWindow

    .while TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw
    mov eax, msg.wParam
    ret
WinMain endp

WndProc proc hWin:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL ps:PAINTSTRUCT
    LOCAL hDC:DWORD
    LOCAL hMemDC:DWORD
    LOCAL hBm:DWORD
    LOCAL hOldBm:DWORD

    .if uMsg == WM_CREATE
        invoke SetTimer, hWin, TIMER_ID, 16, NULL
        invoke InitGame

    .elseif uMsg == WM_TIMER
        invoke Update
        invoke InvalidateRect, hWin, NULL, FALSE

    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWin, addr ps
        mov hDC, eax
        invoke CreateCompatibleDC, hDC
        mov hMemDC, eax
        invoke CreateCompatibleBitmap, hDC, WINDOW_W, WINDOW_H
        mov hBm, eax
        invoke SelectObject, hMemDC, hBm
        mov hOldBm, eax

        invoke Draw, hMemDC
        invoke BitBlt, hDC, 0, 0, WINDOW_W, WINDOW_H, hMemDC, 0, 0, SRCCOPY

        invoke SelectObject, hMemDC, hOldBm
        invoke DeleteObject, hBm
        invoke DeleteDC, hMemDC
        invoke EndPaint, hWin, addr ps

    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage, 0

    .else
        invoke DefWindowProc, hWin, uMsg, wParam, lParam
        ret
    .endif
    xor eax, eax
    ret
WndProc endp

InitGame proc
    LOCAL i:DWORD
    LOCAL rad:REAL8
    LOCAL temp:DWORD

    invoke crt_time, NULL
    invoke crt_srand, eax

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

    invoke InitMap

    mov eax, BLOCK_SIZE
    add eax, BLOCK_SIZE / 2
    shl eax, 8
    mov p1.pos_x, eax
    mov p1.pos_y, eax
    mov p1.angle, 90
    mov p1.color, 00FF0000h
    mov p1.active, 1
    mov p1.cooldown, 0

    mov eax, 18 * BLOCK_SIZE + BLOCK_SIZE / 2
    shl eax, 8
    mov p2.pos_x, eax
    mov eax, 13 * BLOCK_SIZE + BLOCK_SIZE / 2
    shl eax, 8
    mov p2.pos_y, eax
    mov p2.angle, 270
    mov p2.color, 000000FFh
    mov p2.active, 1
    mov p2.cooldown, 0

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

            .if x == 0 || x == MAP_COLS-1 || y == 0 || y == MAP_ROWS-1
                mov DWORD PTR [edi], 1
            .else
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
    
    mov eax, 1 * MAP_COLS + 1
    mov map[eax*4], 0
    mov eax, 13 * MAP_COLS + 18
    mov map[eax*4], 0
    ret
InitMap endp

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

CanMove proc targetX:DWORD, targetY:DWORD
    LOCAL r:DWORD
    mov r, 14 * SCALE
    
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

Update proc
    LOCAL speed:DWORD
    LOCAL nextX:DWORD, nextY:DWORD

    .if p1.active == 0 || p2.active == 0
        ret
    .endif

    ; --- Player 1 ---
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

    ; --- Player 2 ---
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
    invoke GetAsyncKeyState, VK_RETURN
    test ax, 8000h
    .if !ZERO? && p2.cooldown == 0
        invoke FireBullet, addr p2
    .endif

    ; --- Bullet Logic ---
    mov ecx, 0
    .while ecx < MAX_BULLETS
        push ecx
        mov ebx, ecx
        imul ebx, sizeof BULLET
        lea esi, bullets[ebx]

        mov eax, (BULLET PTR [esi]).active
        .if eax != 0
            ; Move X
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

            ; Move Y
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

            ; Hit P1
            mov eax, (BULLET PTR [esi]).pos_x
            sub eax, p1.pos_x
            test eax, eax
            .if SIGN?
                neg eax
            .endif
            .if eax < 15 * SCALE
                mov eax, (BULLET PTR [esi]).pos_y
                sub eax, p1.pos_y
                test eax, eax
                .if SIGN?
                    neg eax
                .endif
                .if eax < 15 * SCALE
                    mov p1.active, 0
                    mov (BULLET PTR [esi]).active, 0
                .endif
            .endif

            ; Hit P2
            mov eax, (BULLET PTR [esi]).pos_x
            sub eax, p2.pos_x
            test eax, eax
            .if SIGN?
                neg eax
            .endif
            .if eax < 15 * SCALE
                mov eax, (BULLET PTR [esi]).pos_y
                sub eax, p2.pos_y
                test eax, eax
                .if SIGN?
                    neg eax
                .endif
                .if eax < 15 * SCALE
                    mov p2.active, 0
                    mov (BULLET PTR [esi]).active, 0
                .endif
            .endif

            ; Check Bounces
            cmp (BULLET PTR [esi]).bounces, 0
            .if SIGN?
                mov (BULLET PTR [esi]).active, 0
            .endif
        .endif

        pop ecx
        inc ecx
    .endw
    ret
Update endp

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
            
            mov (BULLET PTR [esi]).bounces, 5
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

DrawOneTank proc hDC:DWORD, pTank:DWORD
    LOCAL sx:DWORD, sy:DWORD
    LOCAL ex:DWORD, ey:DWORD
    LOCAL hBrush:DWORD, hOld:DWORD

    mov esi, pTank
    ASSUME esi:PTR TANK

    .if [esi].active == 0
        ret
    .endif

    mov eax, [esi].pos_x
    sar eax, 8
    mov sx, eax

    mov eax, [esi].pos_y
    sar eax, 8
    mov sy, eax

    invoke CreateSolidBrush, [esi].color
    mov hBrush, eax
    invoke SelectObject, hDC, hBrush
    mov hOld, eax

    mov eax, sx
    sub eax, 15
    mov ecx, sy
    sub ecx, 15
    mov edx, sx
    add edx, 15
    push edx
    mov edx, sy
    add edx, 15
    pop ebx
    invoke Ellipse, hDC, eax, ecx, ebx, edx

    invoke SelectObject, hDC, hOld
    invoke DeleteObject, hBrush

    mov edx, [esi].angle
    mov eax, cosTable[edx*4]
    imul eax, 25
    sar eax, 8
    add eax, sx
    mov ex, eax

    mov edx, [esi].angle
    mov eax, sinTable[edx*4]
    imul eax, 25
    sar eax, 8
    add eax, sy
    mov ey, eax

    invoke MoveToEx, hDC, sx, sy, NULL
    invoke LineTo, hDC, ex, ey

    ASSUME esi:nothing
    ret
DrawOneTank endp

Draw proc hDC:DWORD
    LOCAL hBg:DWORD, hWall:DWORD
    LOCAL rect:RECT
    LOCAL x:DWORD, y:DWORD
    LOCAL px:DWORD, py:DWORD
    LOCAL bulletIdx:DWORD
    LOCAL dist:DWORD
    LOCAL tempX:DWORD, tempY:DWORD
    LOCAL hPen:DWORD, hOldPen:DWORD

    invoke CreateSolidBrush, 00323232h
    mov hBg, eax
    mov rect.left, 0
    mov rect.top, 0
    mov rect.right, WINDOW_W
    mov rect.bottom, WINDOW_H
    invoke FillRect, hDC, addr rect, hBg
    invoke DeleteObject, hBg

    invoke CreateSolidBrush, 00969696h
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

    invoke DrawOneTank, hDC, addr p1
    invoke DrawOneTank, hDC, addr p2

    invoke CreateSolidBrush, 0000FFFFh
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

    invoke SetBkMode, hDC, TRANSPARENT
    invoke SetTextColor, hDC, 00FFFFFFh
    
    .if p1.active == 0
        invoke TextOut, hDC, 350, 280, addr szP2Win, 14
    .endif
    .if p2.active == 0
        invoke TextOut, hDC, 350, 280, addr szP1Win, 14
    .endif

    ; --- DEBUG OVERLAY (注释掉下面这部分) ---
    ; mov rect.left, 10
    ; mov rect.top, 10
    ; mov rect.right, 300
    ; mov rect.bottom, 150
    ; invoke CreateSolidBrush, 0
    ; mov hBg, eax
    ; invoke FillRect, hDC, addr rect, hBg
    ; invoke DeleteObject, hBg

    ; invoke SetTextColor, hDC, 0000FF00h

    ; mov eax, p1.pos_x
    ; sar eax, 8
    ; mov px, eax
    ; mov eax, p1.pos_y
    ; sar eax, 8
    ; mov py, eax
    ; invoke wsprintf, addr buffer, addr szFmtP1, px, py, p1.angle
    ; invoke crt_strlen, addr buffer
    ; invoke TextOut, hDC, 20, 20, addr buffer, eax

    ; mov bulletIdx, -1
    ; mov ecx, 0
    ; .while ecx < MAX_BULLETS
    ;     mov ebx, ecx
    ;     imul ebx, sizeof BULLET
    ;     lea esi, bullets[ebx]
    ;     mov eax, (BULLET PTR [esi]).active
    ;     .if eax != 0
    ;         mov bulletIdx, ecx
    ;         .break
    ;     .endif
    ;     inc ecx
    ; .endw

    ; .if bulletIdx != -1
    ;     mov ebx, bulletIdx
    ;     imul ebx, sizeof BULLET
    ;     lea esi, bullets[ebx]
        
    ;     mov eax, (BULLET PTR [esi]).pos_x
    ;     sar eax, 8
    ;     mov px, eax
    ;     mov eax, (BULLET PTR [esi]).pos_y
    ;     sar eax, 8
    ;     mov py, eax
        
    ;     invoke wsprintf, addr buffer, addr szFmtBullet, bulletIdx, px, py
    ;     invoke crt_strlen, addr buffer
    ;     invoke TextOut, hDC, 20, 40, addr buffer, eax
        
    ;     finit
    ;     mov eax, (BULLET PTR [esi]).pos_x
    ;     sub eax, p1.pos_x
    ;     sar eax, 8
    ;     mov tempX, eax
        
    ;     mov eax, (BULLET PTR [esi]).pos_y
    ;     sub eax, p1.pos_y
    ;     sar eax, 8
    ;     mov tempY, eax
        
    ;     fild tempX
    ;     fmul st(0), st(0)
    ;     fild tempY
    ;     fmul st(0), st(0)
    ;     faddp st(1), st(0)
    ;     fsqrt
    ;     fistp dist
        
    ;     invoke wsprintf, addr buffer, addr szFmtDist, dist
        
    ;     .if dist < 15
    ;         invoke SetTextColor, hDC, 000000FFh
    ;     .endif
        
    ;     invoke crt_strlen, addr buffer
    ;     invoke TextOut, hDC, 20, 60, addr buffer, eax
    ; .else
    ;     invoke TextOut, hDC, 20, 40, addr szNoBullet, 17
    ; .endif

    ; .if p1.active != 0
    ;     invoke CreatePen, PS_DOT, 1, 00FFFFFFh
    ;     mov hPen, eax
    ;     invoke SelectObject, hDC, hPen
    ;     mov hOldPen, eax
    ;     invoke GetStockObject, NULL_BRUSH
    ;     invoke SelectObject, hDC, eax
        
    ;     mov eax, p1.pos_x
    ;     sar eax, 8
    ;     mov px, eax
    ;     mov eax, p1.pos_y
    ;     sar eax, 8
    ;     mov py, eax
        
    ;     mov eax, px
    ;     sub eax, 15
    ;     mov ecx, py
    ;     sub ecx, 15
    ;     mov edx, px
    ;     add edx, 15
    ;     push edx
    ;     mov edx, py
    ;     add edx, 15
    ;     pop ebx
    ;     invoke Ellipse, hDC, eax, ecx, ebx, edx
        
    ;     invoke SelectObject, hDC, hOldPen
    ;     invoke DeleteObject, hPen
    ; .endif


    ret
Draw endp

end start