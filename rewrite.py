import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Fix SetupBoss Max HP reset issue
content = content.replace('SetEntityHealth(client, 9999999);', """g_bMindControlled[client] = false;
    SetEntityHealth(client, 9999999);""")

# Update Speed
content = content.replace("float speedMult = 0.7;", "float speedMult = 1.3;")
content = content.replace("vel[0] = 200.0 * speedMult;", "vel[0] = 300.0 * speedMult;")

# Inject MindControl hook into OnPlayerRunCmd
old_hook = r'public Action OnPlayerRunCmd\(int client, int &buttons, int &impulse, float vel\[3\], float angles\[3\], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse\[2\]\) \{'
new_hook = """public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (!g_bBossActive || !IsPlayerAlive(client)) return Plugin_Continue;

    if (g_bMindControlled[client]) {
        // Инвертируем управление
        vel[0] = -vel[0];
        vel[1] = -vel[1];

        int newButtons = buttons;
        if (buttons & IN_FORWARD) { newButtons &= ~IN_FORWARD; newButtons |= IN_BACK; }
        else if (buttons & IN_BACK) { newButtons &= ~IN_BACK; newButtons |= IN_FORWARD; }
        if (buttons & IN_MOVELEFT) { newButtons &= ~IN_MOVELEFT; newButtons |= IN_MOVERIGHT; }
        else if (buttons & IN_MOVERIGHT) { newButtons &= ~IN_MOVERIGHT; newButtons |= IN_MOVELEFT; }
        buttons = newButtons;

        return Plugin_Changed;
    }

    if (client != g_iBossClient) return Plugin_Continue;
"""
content = re.sub(old_hook + r'\s*if \(\!g_bBossActive \|\| client \!\= g_iBossClient \|\| \!IsPlayerAlive\(client\)\) return Plugin_Continue;', new_hook, content)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
