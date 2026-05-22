with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("char sSkillName[64];", "char sSkillName[256];")

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
