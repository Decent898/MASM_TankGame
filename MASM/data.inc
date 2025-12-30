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
    szMenuItem2 db "* NETWORK GAME", 0
    szMenuItem3 db "* QUIT", 0
    szPressKey  db "Press ENTER to select", 0
    szMenuHeart db ">", 0
    szBorder1   db "=", 0
    szBorder2   db "~", 0
    szVersion   db "v1.1 - Online", 0
    
    ; --- 网络菜单字符串 ---
    szNetworkTitle    db "NETWORK MODE", 0
    szHostOption      db "H - Create Game (Connect as Host)", 0
    szJoinOption      db "J - Join Game (Connect as Client)", 0
    szBackOption      db "ESC - Back to Menu", 0
    szWaitingConnect  db "Waiting for other player...", 0
    szConnecting      db "Connecting to server...", 0
    szOfflineStatus   db "Select an option", 0
    szConnectSuccess  db "Connected! Waiting for opponent...", 0
    szConnectFailed   db "Connection failed! Check server status", 0
    szInitFailed      db "Network init failed! Press ESC to return", 0
    szHostWaiting     db "Connected to server! Waiting for opponent...", 0
    szArialFont       db "Arial", 0
    
    ; --- 调试信息格式 ---
    szDebugFormat     db "Mode:%d InitOK:%d LastResult:%d WSAErr:%d", 0
    szDebugBuffer     db 100 dup(0)
    szDbgGameStart    db "[NET] MSG_CONNECT received! Starting game!", 13, 10, 0
    szDbgCheckingMsg  db "[NET] Checking for messages (connected)...", 13, 10, 0
    
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
    
    ; --- 网络状态 ---
    networkMode       dd NET_MODE_OFFLINE
    isNetworkReady    dd 0
    networkInitOK     dd 0
    lastNetworkResult dd 0
    wsaStartupError   dd 0
    
    ; --- 菜单动画 ---
    menuAnimTick    dd 0
    heartBeat       dd 0

.data?
    hInstance   dd ?
    hWnd        dd ?
    buffer      db 128 dup(?)
