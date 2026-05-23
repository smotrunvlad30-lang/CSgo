import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace('RegConsoleCmd("sm_bos", Command_BossMenu);', 'RegConsoleCmd("sm_boss_admin", Command_BossMenu);')
content = content.replace('RegConsoleCmd("sm_boss", Command_BossMenu);', 'RegConsoleCmd("sm_boss_spawn", Command_BossMenu);')

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
