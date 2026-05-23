import re

with open("ФАйлы сервера кс го/rpg_core.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Replace was likely missed due to regex interpretation of regex chars, let's use exact string search
target = 'Format(insQ, sizeof(insQ), "INSERT IGNORE INTO rpg_system (steamid, nickname, lvl, xp, money) VALUES (\'%s\', \'%s\', 1, 0, 0)", auth, name);'
replacement = """Format(insQ, sizeof(insQ), "INSERT IGNORE INTO rpg_system (steamid, nickname, lvl, xp, money) VALUES ('%s', '%s', 1, 0, 0)", auth, name);
        g_DB.Query(SQL_IgnoreError, insQ);"""

if target in content:
    content = content.replace(target, replacement)
else:
    print("TARGET NOT FOUND!")

with open("ФАйлы сервера кс го/rpg_core.sp", "w", encoding="utf-8") as f:
    f.write(content)
