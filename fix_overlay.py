import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace('ClientCommand(client, "r_screenoverlay """);', 'ClientCommand(client, "r_screenoverlay \\"\\"");')

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
