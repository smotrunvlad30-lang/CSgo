import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Add to globals explicitly at the top
globals_old = r'int g_iSoulStealKills = 0;'
globals_new = """int g_iSoulStealKills = 0;
bool g_bMindControlled[MAXPLAYERS + 1];"""
if "bool g_bMindControlled[MAXPLAYERS + 1];" not in content:
    content = content.replace(globals_old, globals_new)

# Reset in SetupBoss
setup_old = r'for \(int i = 1; i <= MaxClients; i\+\+\) \{ g_bPlayerParticipated\[i\] = false; g_iDamageCounter\[i\] = 0; \}'
setup_new = """for (int i = 1; i <= MaxClients; i++) { g_bPlayerParticipated[i] = false; g_iDamageCounter[i] = 0; g_bMindControlled[i] = false; }"""
if "g_bMindControlled[i] = false;" not in content:
    content = content.replace(setup_old, setup_new)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
