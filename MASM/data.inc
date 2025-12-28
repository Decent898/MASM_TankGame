; ========================================
; Data.inc - 数据定义
; ========================================

.data
    ; --- 窗口字符串 ---
    szClassName db "TankClass", 0
    szAppName   db "RETRO TANK BATTLE", 0
    
    ; --- 游戏结果字符串 ---
    szP1Win     db "PLAYER 1 WINS!", 0
    szP2Win     db "PLAYER 2 WINS!", 0
    
    ; --- 菜单字符串 (Undertale风格) ---
    szMenuTitle db "RETRO TANK BATTLE", 0
    szSubTitle  db "A Classic Arcade Experience", 0
    szMenuItem1 db "* START GAME", 0
    szMenuItem2 db "* QUIT", 0
    szPressKey  db "Press ENTER to select", 0
    szMenuHeart db ">", 0
    szBorder1   db "=", 0
    szBorder2   db "~", 0
    szVersion   db "v1.0 - 2025", 0
    
    ; --- 暂停菜单字符串 ---
    szPaused    db "= PAUSED =", 0
    szResume    db "* RESUME", 0
    szRestart   db "* RESTART", 0
    szQuitGame  db "* QUIT TO MENU", 0
    
    ; --- 控制说明 ---
    szControls1 db "PLAYER 1: WASD + J", 0
    szControls2 db "PLAYER 2: ARROWS + ENTER", 0
    szPauseInfo db "Press P to Pause", 0
    
    ; --- 音频文件路径（取消注释以启用音乐） ---
    ; szMenuMusic  db "menu_music.wav", 0
    ; szGameMusic  db "game_music.wav", 0
    ; szShootSound db "shoot.wav", 0
    ; szHitSound   db "hit.wav", 0
    
    ; --- 浮点常量 ---
    double_PI   dq 3.141592653589793
    double_180  dq 180.0
    double_256  dq 256.0

    ; --- 游戏数据 ---
    map         dd MAP_ROWS * MAP_COLS dup(0)
    sinTable    dd 360 dup(0)
    cosTable    dd 360 dup(0)
    bullets     BULLET MAX_BULLETS dup(<0,0,0,0,0,0>)
    
    p1          TANK <0,0,0,0,0,0>
    p2          TANK <0,0,0,0,0,0>
    
    ; --- 游戏状态 ---
    gameState       dd STATE_MENU
    menuSelection   dd MENU_START
    pauseSelection  dd 0
    
    ; --- 菜单动画 ---
    menuAnimTick    dd 0
    heartBeat       dd 0

.data?
    hInstance   dd ?
    hWnd        dd ?
    buffer      db 128 dup(?)
