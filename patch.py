import re

with open("ФАйлы сервера кс го/rpg_core.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Add Boss_OnPluginStart() to OnPluginStart()
content = content.replace("SVip_OnPluginStart();", "SVip_OnPluginStart();\n    Boss_OnPluginStart();")

# Add Boss_OnClientPutInServer() to OnClientPutInServer()
content = content.replace("SVip_OnClientPutInServer(client);", "SVip_OnClientPutInServer(client);\n    Boss_OnClientPutInServer(client);")

# Add Boss_OnPlayerSpawn() to Event_Spawn()
content = content.replace("SVip_OnPlayerSpawn(client);", "SVip_OnPlayerSpawn(client);\n        Boss_OnPlayerSpawn(client);")

# Add Boss_Event_RoundStart() to Event_RoundStart()
content = content.replace("Items_Event_RoundStart();", "Items_Event_RoundStart();\n    Boss_Event_RoundStart(event, name, dontBroadcast);")

# Add Boss_Event_Death() to Event_Death()
content = content.replace("SVip_Event_Death(event, name, dontBroadcast);", "SVip_Event_Death(event, name, dontBroadcast);\n    Boss_Event_Death(event, name, dontBroadcast);")

# Add Boss_OnPlayerRunCmd() to OnPlayerRunCmd()
content = content.replace("Movement_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);", "Movement_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);\n    Boss_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);")

with open("ФАйлы сервера кс го/rpg_core.sp", "w", encoding="utf-8") as f:
    f.write(content)
