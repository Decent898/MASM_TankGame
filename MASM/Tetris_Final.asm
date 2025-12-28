.386
.model flat, stdcall
option casemap :none

; --- 核心引用 (绝对不可以有 winextra) ---
include C:\masm32\include\windows.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\gdi32.inc
include C:\masm32\include\msvcrt.inc

; --- 库文件 ---
includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\gdi32.lib
includelib C:\masm32\lib\msvcrt.lib

; --- Constants ---
WINDOW_WIDTH    equ 400
WINDOW_HEIGHT   equ 640
BLOCK_SIZE      equ 25
BOARD_COLS      equ 10
BOARD_ROWS      equ 20
OFFSET_X        equ 75
OFFSET_Y        equ 50
TIMER_ID        equ 1
GAME_SPEED      equ 500

STATE_PLAYING   equ 0
STATE_GAMEOVER  equ 1

; --- Data Section ---
.data
    szClassName     db "AsmTetrisClass", 0
    szAppName       db "Tetris MASM32", 0
    szScoreFmt      db "Score: %d", 0
    szGameOver      db "GAME OVER", 0
    szRestart       db "Press SPACE", 0

    hInstance       dd ?
    hWnd            dd ?
    
    gameState       dd STATE_PLAYING
    score           dd 0
    hdcMem          dd ?
    hBm             dd ?
    hOldBm          dd ?
    
    currShape       dd ?
    currRot         dd ?
    currX           dd ?
    currY           dd ?
    
    boardMap        db 200 dup(0)

    ; Shapes Data (16-bit masks)
    shapes  dw 04E00h, 04640h, 00E40h, 04C40h
            dw 04620h, 06C00h, 08C40h, 06C00h
            dw 02640h, 0C600h, 04C80h, 0C600h
            dw 00F00h, 02222h, 000F0h, 04444h
            dw 0CC00h, 0CC00h, 0CC00h, 0CC00h
            dw 04460h, 00E80h, 06440h, 02E00h
            dw 02260h, 00E20h, 044C0h, 08E00h

.data?
    buffer          db 64 dup(?)

; --- Code Section ---
.code

; 函数声明
WinMain         PROTO :DWORD,:DWORD,:DWORD,:DWORD
WndProc         PROTO :DWORD,:DWORD,:DWORD,:DWORD
InitGame        PROTO
SpawnPiece      PROTO
CheckCollision  PROTO :DWORD,:DWORD,:DWORD
TryMove         PROTO :DWORD,:DWORD
LockPiece       PROTO
CheckLines      PROTO
DrawGame        PROTO :DWORD

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke GetTickCount
    invoke crt_srand, eax
    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, 0

WinMain proc hInst:DWORD, hPrevInst:DWORD, CmdLine:DWORD, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    
    mov eax, hPrevInst
    mov eax, CmdLine
    mov eax, CmdShow
    
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
    
    invoke CreateWindowEx, 0, addr szClassName, addr szAppName,
           WS_OVERLAPPEDWINDOW,
           CW_USEDEFAULT, CW_USEDEFAULT, WINDOW_WIDTH, WINDOW_HEIGHT,
           NULL, NULL, hInst, NULL
    mov hWnd, eax
    
    invoke ShowWindow, hWnd, SW_SHOWNORMAL
    invoke UpdateWindow, hWnd
    
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
    .if uMsg == WM_CREATE
        invoke InitGame
        invoke SetTimer, hWin, TIMER_ID, GAME_SPEED, NULL
        
    .elseif uMsg == WM_DESTROY
        invoke KillTimer, hWin, TIMER_ID
        invoke DeleteObject, hBm
        invoke DeleteDC, hdcMem
        invoke PostQuitMessage, 0
        
    .elseif uMsg == WM_TIMER
        .if gameState == STATE_PLAYING
            invoke TryMove, 0, 1
            .if eax == 0
                invoke LockPiece
                invoke CheckLines
                invoke SpawnPiece
                invoke CheckCollision, currX, currY, currRot
                .if eax != 0
                    mov gameState, STATE_GAMEOVER
                .endif
            .endif
            invoke InvalidateRect, hWin, NULL, FALSE
        .endif
        
    .elseif uMsg == WM_KEYDOWN
        .if gameState == STATE_PLAYING
            .if wParam == VK_LEFT
                invoke TryMove, -1, 0
            .elseif wParam == VK_RIGHT
                invoke TryMove, 1, 0
            .elseif wParam == VK_DOWN
                invoke TryMove, 0, 1
            .elseif wParam == VK_UP || wParam == VK_SPACE
                mov eax, currRot
                inc eax
                and eax, 3
                invoke CheckCollision, currX, currY, eax
                .if eax == 0
                    mov edx, currRot
                    inc edx
                    and edx, 3
                    mov currRot, edx
                .endif
            .endif
            invoke InvalidateRect, hWin, NULL, FALSE
        .elseif gameState == STATE_GAMEOVER
            .if wParam == VK_SPACE
                invoke InitGame
                invoke InvalidateRect, hWin, NULL, FALSE
            .endif
        .endif
        
    .elseif uMsg == WM_PAINT
        invoke DrawGame, hWin
        
    .else
        invoke DefWindowProc, hWin, uMsg, wParam, lParam
        ret
    .endif
    
    xor eax, eax
    ret
WndProc endp

InitGame proc
    cld
    mov ecx, 200
    lea edi, boardMap
    xor eax, eax
    rep stosb
    
    mov gameState, STATE_PLAYING
    mov score, 0
    invoke SpawnPiece
    ret
InitGame endp

SpawnPiece proc
    invoke crt_rand
    xor edx, edx
    mov ecx, 7
    div ecx
    mov currShape, edx
    
    mov currRot, 0
    mov currX, 3
    mov currY, 0
    ret
SpawnPiece endp

CheckCollision proc x:DWORD, y:DWORD, rot:DWORD
    LOCAL row:DWORD, col:DWORD, bitMask:WORD, shapeData:WORD
    
    mov eax, currShape
    shl eax, 2
    add eax, rot
    shl eax, 1
    lea edx, shapes
    mov bx, [edx + eax]
    mov shapeData, bx
    
    mov bitMask, 8000h
    
    mov row, 0
    .while row < 4
        mov col, 0
        .while col < 4
            mov ax, shapeData
            test ax, bitMask
            .if !ZERO?
                mov ecx, x
                add ecx, col
                mov edx, y
                add edx, row
                
                .if (SDWORD ptr ecx < 0) || (ecx >= BOARD_COLS) || (edx >= BOARD_ROWS)
                    mov eax, 1
                    ret
                .endif
                
                .if SDWORD ptr edx >= 0
                    imul edx, BOARD_COLS
                    add edx, ecx
                    lea esi, boardMap
                    mov al, [esi + edx]
                    .if al != 0
                        mov eax, 1
                        ret
                    .endif
                .endif
            .endif
            shr bitMask, 1
            inc col
        .endw
        inc row
    .endw
    
    mov eax, 0
    ret
CheckCollision endp

TryMove proc _dx:DWORD, _dy:DWORD
    mov eax, currX
    add eax, _dx
    mov ecx, currY
    add ecx, _dy
    
    invoke CheckCollision, eax, ecx, currRot
    .if eax == 0
        mov eax, currX
        add eax, _dx
        mov currX, eax
        
        mov ecx, currY
        add ecx, _dy
        mov currY, ecx
        
        mov eax, 1
        ret
    .endif
    
    mov eax, 0
    ret
TryMove endp

LockPiece proc
    LOCAL row:DWORD, col:DWORD, bitMask:WORD, shapeData:WORD
    
    mov eax, currShape
    shl eax, 2
    add eax, currRot
    shl eax, 1
    lea edx, shapes
    mov bx, [edx + eax]
    mov shapeData, bx
    
    mov bitMask, 8000h
    
    mov row, 0
    .while row < 4
        mov col, 0
        .while col < 4
            mov ax, shapeData
            test ax, bitMask
            .if !ZERO?
                mov ecx, currX
                add ecx, col
                mov edx, currY
                add edx, row
                
                .if (SDWORD ptr ecx >= 0) && (ecx < BOARD_COLS) && (SDWORD ptr edx >= 0) && (edx < BOARD_ROWS)
                    imul edx, BOARD_COLS
                    add edx, ecx
                    lea esi, boardMap
                    mov byte ptr [esi + edx], 1
                .endif
            .endif
            shr bitMask, 1
            inc col
        .endw
        inc row
    .endw
    ret
LockPiece endp

CheckLines proc
    LOCAL row:DWORD, col:DWORD, isFull:DWORD, linesCleared:DWORD
    
    mov linesCleared, 0
    mov row, BOARD_ROWS - 1
    
    .while SDWORD ptr row >= 0
        mov isFull, 1
        mov col, 0
        .while col < BOARD_COLS
            mov eax, row
            imul eax, BOARD_COLS
            add eax, col
            lea esi, boardMap
            mov bl, [esi + eax]
            .if bl == 0
                mov isFull, 0
                .break
            .endif
            inc col
        .endw
        
        .if isFull == 1
            inc linesCleared
            mov eax, row
            .while SDWORD ptr eax > 0
                mov ecx, 0
                .while ecx < BOARD_COLS
                    mov edx, eax
                    imul edx, BOARD_COLS
                    add edx, ecx
                    
                    mov edi, eax
                    dec edi
                    imul edi, BOARD_COLS
                    add edi, ecx
                    
                    lea esi, boardMap
                    mov bl, [esi + edi]
                    mov [esi + edx], bl
                    
                    inc ecx
                .endw
                dec eax
            .endw
            
            mov ecx, 0
            .while ecx < BOARD_COLS
                lea esi, boardMap
                mov byte ptr [esi + ecx], 0
                inc ecx
            .endw
            
            .continue
        .endif
        
        dec row
    .endw
    
    .if linesCleared == 1
        add score, 10
    .elseif linesCleared == 2
        add score, 30
    .elseif linesCleared == 3
        add score, 60
    .elseif linesCleared == 4
        add score, 100
    .endif
    ret
CheckLines endp

DrawGame proc hWin:DWORD
    LOCAL ps:PAINTSTRUCT
    LOCAL hDC:DWORD
    LOCAL hMemDC:DWORD
    LOCAL hBrush:DWORD
    LOCAL rect:RECT
    
    invoke BeginPaint, hWin, addr ps
    mov hDC, eax
    
    invoke CreateCompatibleDC, hDC
    mov hMemDC, eax
    invoke GetClientRect, hWin, addr rect
    invoke CreateCompatibleBitmap, hDC, rect.right, rect.bottom
    mov hBm, eax
    invoke SelectObject, hMemDC, hBm
    mov hOldBm, eax
    
    invoke GetStockObject, BLACK_BRUSH
    invoke FillRect, hMemDC, addr rect, eax
    
    invoke CreateSolidBrush, 00333333h
    mov hBrush, eax
    invoke SelectObject, hMemDC, hBrush
    invoke Rectangle, hMemDC, OFFSET_X - 10, OFFSET_Y, OFFSET_X, OFFSET_Y + BOARD_ROWS*BLOCK_SIZE + 10
    invoke Rectangle, hMemDC, OFFSET_X + BOARD_COLS*BLOCK_SIZE, OFFSET_Y, OFFSET_X + BOARD_COLS*BLOCK_SIZE + 10, OFFSET_Y + BOARD_ROWS*BLOCK_SIZE + 10
    invoke Rectangle, hMemDC, OFFSET_X - 10, OFFSET_Y + BOARD_ROWS*BLOCK_SIZE, OFFSET_X + BOARD_COLS*BLOCK_SIZE + 10, OFFSET_Y + BOARD_ROWS*BLOCK_SIZE + 10
    invoke DeleteObject, hBrush
    
    invoke CreateSolidBrush, 00AAAAAAh
    mov hBrush, eax
    invoke SelectObject, hMemDC, hBrush
    
    xor ecx, ecx
    .while ecx < BOARD_ROWS
        xor edx, edx
        .while edx < BOARD_COLS
            push ecx
            push edx
            
            imul ecx, BOARD_COLS
            add ecx, edx
            lea esi, boardMap
            mov al, [esi + ecx]
            
            pop edx
            pop ecx
            
            .if al != 0
                push ecx
                push edx
                
                mov eax, edx
                imul eax, BLOCK_SIZE
                add eax, OFFSET_X
                mov rect.left, eax
                add eax, BLOCK_SIZE
                sub eax, 1
                mov rect.right, eax
                
                mov eax, ecx
                imul eax, BLOCK_SIZE
                add eax, OFFSET_Y
                mov rect.top, eax
                add eax, BLOCK_SIZE
                sub eax, 1
                mov rect.bottom, eax
                
                invoke FillRect, hMemDC, addr rect, hBrush
                
                pop edx
                pop ecx
            .endif
            
            inc edx
        .endw
        inc ecx
    .endw
    invoke DeleteObject, hBrush
    
    .if gameState == STATE_PLAYING
        invoke CreateSolidBrush, 0000FF00h
        mov hBrush, eax
        invoke SelectObject, hMemDC, hBrush
        
        mov eax, currShape
        shl eax, 2
        add eax, currRot
        shl eax, 1
        lea edx, shapes
        mov bx, [edx + eax]
        
        mov ecx, 8000h
        
        xor esi, esi
        .while esi < 4
            xor edi, edi
            .while edi < 4
                test bx, cx
                .if !ZERO?
                    push ecx
                    push bx
                    
                    mov eax, currX
                    add eax, edi
                    imul eax, BLOCK_SIZE
                    add eax, OFFSET_X
                    mov rect.left, eax
                    add eax, BLOCK_SIZE
                    sub eax, 1
                    mov rect.right, eax
                    
                    mov eax, currY
                    add eax, esi
                    imul eax, BLOCK_SIZE
                    add eax, OFFSET_Y
                    mov rect.top, eax
                    add eax, BLOCK_SIZE
                    sub eax, 1
                    mov rect.bottom, eax
                    
                    invoke FillRect, hMemDC, addr rect, hBrush
                    
                    pop bx
                    pop ecx
                .endif
                shr ecx, 1
                inc edi
            .endw
            inc esi
        .endw
        invoke DeleteObject, hBrush
    .endif
    
    invoke SetBkMode, hMemDC, TRANSPARENT
    invoke SetTextColor, hMemDC, 00FFFFFFh
    
    invoke wsprintf, addr buffer, addr szScoreFmt, score
    invoke TextOut, hMemDC, 20, 20, addr buffer, eax
    
    .if gameState == STATE_GAMEOVER
        invoke SetTextColor, hMemDC, 000000FFh
        invoke TextOut, hMemDC, 150, 300, addr szGameOver, 9
        invoke SetTextColor, hMemDC, 00FFFFFFh
        invoke TextOut, hMemDC, 120, 330, addr szRestart, 22
    .endif
    
    invoke GetClientRect, hWin, addr rect
    invoke BitBlt, hDC, 0, 0, rect.right, rect.bottom, hMemDC, 0, 0, SRCCOPY
    
    invoke SelectObject, hMemDC, hOldBm
    invoke DeleteObject, hBm
    invoke DeleteDC, hMemDC
    invoke EndPaint, hWin, addr ps
    ret
DrawGame endp

end start