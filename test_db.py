import re

with open("ФАйлы сервера кс го/rpg_core.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Let's see if the query is actually being executed!
match = re.search(r'Format\(insQ, sizeof\(insQ\), "INSERT IGNORE INTO rpg_system.*?LoadPlayerData\(c\);', content, re.DOTALL)
if match:
    print(match.group(0))
