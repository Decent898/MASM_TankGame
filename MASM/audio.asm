; ========================================
; Audio.asm - 音频管理模块
; ========================================
; 
; 使用说明：
; 1. 在TankGame.asm中添加：
;    include C:\masm32\include\winmm.inc
;    includelib C:\masm32\lib\winmm.lib
; 
; 2. 准备音乐文件：
;    - menu_music.wav (菜单背景音乐)
;    - game_music.wav (游戏背景音乐)
;    - shoot.wav (射击音效)
;    - hit.wav (击中音效)
;    将这些文件放在exe同目录下
;
; 3. 在data.inc中添加：
;    szMenuMusic  db "menu_music.wav", 0
;    szGameMusic  db "game_music.wav", 0
;    szShootSound db "shoot.wav", 0
;    szHitSound   db "hit.wav", 0
;    isMusicPlaying dd 0
;

; --- 播放背景音乐（循环） ---
; 参数：音乐文件路径的地址
PlayBackgroundMusic proc pMusicFile:DWORD
    ; 停止当前音乐
    invoke PlaySound, NULL, NULL, 0
    
    ; 播放新音乐（异步，循环）
    invoke PlaySound, pMusicFile, NULL, SND_FILENAME or SND_ASYNC or SND_LOOP
    
    ret
PlayBackgroundMusic endp

; --- 播放音效（不循环） ---
; 参数：音效文件路径的地址
PlaySoundEffect proc pSoundFile:DWORD
    ; 播放音效（异步，不循环，不等待）
    invoke PlaySound, pSoundFile, NULL, SND_FILENAME or SND_ASYNC or SND_NOSTOP
    
    ret
PlaySoundEffect endp

; --- 停止所有音乐 ---
StopMusic proc
    invoke PlaySound, NULL, NULL, 0
    ret
StopMusic endp

; --- 在适当位置调用音乐函数：
; 
; 1. 在WndProc的WM_CREATE中（启动菜单音乐）：
;    invoke PlayBackgroundMusic, addr szMenuMusic
;
; 2. 在HandleMenuInput开始游戏时：
;    invoke PlayBackgroundMusic, addr szGameMusic
;
; 3. 在FireBullet中（射击音效）：
;    invoke PlaySoundEffect, addr szShootSound
;
; 4. 在子弹击中时（gamelogic.asm）：
;    invoke PlaySoundEffect, addr szHitSound
;
; 5. 在返回菜单时：
;    invoke PlayBackgroundMusic, addr szMenuMusic
;
; 6. 在WndProc的WM_DESTROY中：
;    invoke StopMusic
;

; ========================================
; 如果不想使用WAV文件，可以使用mciSendString播放MP3
; ========================================
;
; 需要添加的字符串（在data.inc中）：
;   mciOpen    db "open ", 34, "music.mp3", 34, " type mpegvideo alias music", 0
;   mciPlay    db "play music repeat", 0
;   mciStop    db "stop music", 0
;   mciClose   db "close music", 0
;   mciBuffer  db 256 dup(0)
;
; PlayMP3Music proc
;     invoke mciSendString, addr mciOpen, NULL, 0, NULL
;     invoke mciSendString, addr mciPlay, NULL, 0, NULL
;     ret
; PlayMP3Music endp
;
; StopMP3Music proc
;     invoke mciSendString, addr mciStop, NULL, 0, NULL
;     invoke mciSendString, addr mciClose, NULL, 0, NULL
;     ret
; StopMP3Music endp
