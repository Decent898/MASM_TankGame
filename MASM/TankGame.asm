.386
.model flat, stdcall
option casemap :none

; ========================================
; TankGame.asm - 坦克大战主程序
; Undertale风格街机游戏
; ========================================

; --- Windows API Includes ---
include C:\masm32\include\windows.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\gdi32.inc
include C:\masm32\include\msvcrt.inc
include C:\masm32\include\winmm.inc

includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\gdi32.lib
includelib C:\masm32\lib\msvcrt.lib
includelib C:\masm32\lib\winmm.lib

; --- 包含项目模块 ---
include constants.inc
include data.inc

; --- 函数声明 ---
WinMain         PROTO :DWORD, :DWORD, :DWORD, :DWORD
WndProc         PROTO :DWORD, :DWORD, :DWORD, :DWORD

; 游戏逻辑
InitGame        PROTO
InitMap         PROTO
UpdateGame      PROTO
IsWall          PROTO :DWORD, :DWORD
CheckTankMove   PROTO :DWORD, :DWORD, :DWORD
FireBullet      PROTO :DWORD
CheckMapConnectivity PROTO
TryVisit        PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

; AI系统
UpdateAI                PROTO
CalculateAngleToTarget  PROTO :SDWORD, :SDWORD
CheckDangerousBullets   PROTO
EvadeBullet             PROTO
RandomMove              PROTO
CheckWallAhead          PROTO
CheckLineOfSight        PROTO

; 菜单系统
HandleMenuInput     PROTO
HandlePauseInput    PROTO
HandleGameInput     PROTO
HandleGameOverInput PROTO
DrawMenu            PROTO :DWORD
DrawPauseMenu       PROTO :DWORD
DrawGameOver        PROTO :DWORD

; 渲染
DrawGame        PROTO :DWORD
DrawGameScene   PROTO :DWORD
DrawOneTank     PROTO :DWORD, :DWORD

; 音频（可选，如果你有音乐文件则取消注释）
; PlayBackgroundMusic PROTO :DWORD
; PlaySoundEffect     PROTO :DWORD
; StopMusic           PROTO

.code

; --- 包含游戏逻辑模块 ---
include gamelogic.asm

; --- 包含AI模块 ---
include ai.asm

; --- 包含菜单模块 ---
include menu.asm

; --- 包含渲染模块 ---
include render.asm

; ========================================
; 程序入口
; ========================================
start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, 0

; ========================================
; WinMain - Windows主函数
; ========================================
WinMain proc hInst:DWORD, hPrevInst:DWORD, CmdLine:DWORD, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hWindow:DWORD
    LOCAL rect:RECT       ; 用于计算实际窗口大小
    LOCAL winW:DWORD
    LOCAL winH:DWORD

    mov eax, hPrevInst
    mov eax, CmdLine

    ; 创建控制台窗口用于调试输出
    invoke AllocConsole
    
    ; 注册窗口类
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
    
    ; --- 修正窗口大小问题 ---
    ; 设置期望的客户区大小 (800x600)
    mov rect.left, 0
    mov rect.top, 0
    mov rect.right, WINDOW_W
    mov rect.bottom, WINDOW_H
    
    ; 计算包含标题栏和边框后的实际窗口大小
    ; 使用 WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX (禁止调整大小)
    invoke AdjustWindowRect, addr rect, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, FALSE
    
    ; 计算实际宽度
    mov eax, rect.right
    sub eax, rect.left
    mov winW, eax
    
    ; 计算实际高度
    mov eax, rect.bottom
    sub eax, rect.top
    mov winH, eax

    ; 创建窗口 (禁止调整大小)
    invoke CreateWindowEx, 0, addr szClassName, addr szAppName, \
           WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, \
           CW_USEDEFAULT, CW_USEDEFAULT, \
           winW, winH, NULL, NULL, hInst, NULL
    mov hWindow, eax
    mov hWnd, eax

    invoke ShowWindow, hWindow, CmdShow
    invoke UpdateWindow, hWindow

    ; 消息循环
    .while TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw
    mov eax, msg.wParam
    ret
WinMain endp

; ========================================
; WndProc - 窗口过程
; ========================================
WndProc proc hWin:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL ps:PAINTSTRUCT
    LOCAL hDC:DWORD
    LOCAL hMemDC:DWORD
    LOCAL hBm:DWORD
    LOCAL hOldBm:DWORD

    .if uMsg == WM_CREATE
        ; 启动定时器
        invoke SetTimer, hWin, TIMER_ID, 16, NULL
        ; 初始化游戏状态
        mov gameState, STATE_MENU
        mov menuSelection, MENU_START

    .elseif uMsg == WM_TIMER
        ; 根据游戏状态更新
        mov eax, gameState
        .if eax == STATE_MENU
            invoke HandleMenuInput
        .elseif eax == STATE_PLAYING
            invoke UpdateGame
            invoke HandleGameInput
        .elseif eax == STATE_PAUSED
            invoke HandlePauseInput
        .elseif eax == STATE_GAME_OVER
            invoke HandleGameOverInput
        .endif
        
        ; 刷新窗口
        invoke InvalidateRect, hWin, NULL, FALSE

    .elseif uMsg == WM_PAINT
        ; 双缓冲绘制
        invoke BeginPaint, hWin, addr ps
        mov hDC, eax
        
        invoke CreateCompatibleDC, hDC
        mov hMemDC, eax
        invoke CreateCompatibleBitmap, hDC, WINDOW_W, WINDOW_H
        mov hBm, eax
        invoke SelectObject, hMemDC, hBm
        mov hOldBm, eax

        ; 绘制游戏
        invoke DrawGame, hMemDC
        
        ; 复制到屏幕
        invoke BitBlt, hDC, 0, 0, WINDOW_W, WINDOW_H, hMemDC, 0, 0, SRCCOPY

        invoke SelectObject, hMemDC, hOldBm
        invoke DeleteObject, hBm
        invoke DeleteDC, hMemDC
        invoke EndPaint, hWin, addr ps

    .elseif uMsg == WM_DESTROY
        invoke KillTimer, hWin, TIMER_ID
        invoke FreeConsole
        invoke PostQuitMessage, 0

    .else
        invoke DefWindowProc, hWin, uMsg, wParam, lParam
        ret
    .endif
    
    xor eax, eax
    ret
WndProc endp

end start