import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

runcmd_old = r'if \(\!g_bBossActive \|\| client \!\= g_iBossClient \|\| \!IsPlayerAlive\(client\)\) return Plugin_Continue;'
runcmd_new = """if (!g_bBossActive || !IsPlayerAlive(client)) return Plugin_Continue;

    if (g_bMindControlled[client]) {
        // Инвертируем управление
        float newVel[3];
        newVel[0] = -vel[0];
        newVel[1] = -vel[1];
        newVel[2] = vel[2];
        vel = newVel;

        int newButtons = buttons;
        if (buttons & IN_FORWARD) { newButtons &= ~IN_FORWARD; newButtons |= IN_BACK; }
        else if (buttons & IN_BACK) { newButtons &= ~IN_BACK; newButtons |= IN_FORWARD; }
        if (buttons & IN_MOVELEFT) { newButtons &= ~IN_MOVELEFT; newButtons |= IN_MOVERIGHT; }
        else if (buttons & IN_MOVERIGHT) { newButtons &= ~IN_MOVERIGHT; newButtons |= IN_MOVELEFT; }
        buttons = newButtons;

        float newAngles[3];
        newAngles[0] = angles[0];
        newAngles[1] = angles[1] + 180.0;
        if (newAngles[1] > 180.0) newAngles[1] -= 360.0;
        angles = newAngles;
        return Plugin_Changed;
    }

    if (client != g_iBossClient) return Plugin_Continue;"""
if "if (g_bMindControlled[client])" not in content:
    content = content.replace(runcmd_old, runcmd_new)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
