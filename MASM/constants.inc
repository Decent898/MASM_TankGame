; ========================================
; Constants.inc - 常量定义
; ========================================

; --- 窗口与地图常量 ---
WINDOW_W        equ 800
WINDOW_H        equ 600
MAP_COLS        equ 20
MAP_ROWS        equ 15
BLOCK_SIZE      equ 40

; --- 游戏常量 ---
SCALE           equ 256
TANK_SPEED      equ (2 * SCALE)
ROT_SPEED       equ 4
BULLET_SPEED    equ (6 * SCALE)
MAX_BULLETS     equ 20
TANK_RADIUS     equ 15
TANK_HALF_W     equ 12
TANK_HALF_H     equ 9
BARREL_LEN      equ 22

; --- 计时器 ---
TIMER_ID        equ 1

; --- 游戏状态 ---
STATE_MENU      equ 0
STATE_PLAYING   equ 1
STATE_PAUSED    equ 2
STATE_GAME_OVER equ 3

; --- 菜单选项 ---
MENU_START      equ 0
MENU_MODE       equ 1
MENU_DIFFICULTY equ 2
MENU_QUIT       equ 3

; --- 游戏模式 ---
MODE_PVP        equ 0
MODE_PVE        equ 1

; --- AI难度 ---
AI_EASY         equ 0
AI_MEDIUM       equ 1
AI_HARD         equ 2

; --- 颜色定义 ---
COLOR_P1        equ 0000A0FFh   ; 橙色 (BGR格式)
COLOR_P2        equ 00FF4040h   ; 红色
COLOR_BG        equ 00000000h   ; 黑色背景
COLOR_WALL      equ 00969696h   ; 灰色墙壁
COLOR_BULLET    equ 0000FFFFh   ; 黄色子弹
COLOR_TEXT      equ 00FFFFFFh   ; 白色文本
COLOR_MENU_HL   equ 00FFD700h   ; 金色高亮

; --- 结构体定义 ---
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
    owner       dd ?    ; 指向拥有者TANK的指针
BULLET ENDS
