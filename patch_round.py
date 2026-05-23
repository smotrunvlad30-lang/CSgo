import re

with open("ФАйлы сервера кс го/rpg_core.sp", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("SVip_Event_RoundStart(event, name, dontBroadcast);", "SVip_Event_RoundStart(event, name, dontBroadcast);\n    Boss_Event_RoundStart(event, name, dontBroadcast);")

with open("ФАйлы сервера кс го/rpg_core.sp", "w", encoding="utf-8") as f:
    f.write(content)
