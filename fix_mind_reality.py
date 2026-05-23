import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Add a global array for Mind Control state
globals_block = r'bool g_bFinalPhaseActive = false;\nint g_iSoulStealKills = 0;'
globals_new = """bool g_bFinalPhaseActive = false;
int g_iSoulStealKills = 0;
bool g_bMindControlled[MAXPLAYERS + 1];"""
content = content.replace(globals_block, globals_new)

# Reset Mind Control in SetupBoss
setup_old = r'for \(int i = 1; i <= MaxClients; i\+\+\) \{ g_bPlayerParticipated\[i\] = false; g_iDamageCounter\[i\] = 0; \}'
setup_new = """for (int i = 1; i <= MaxClients; i++) {
        g_bPlayerParticipated[i] = false;
        g_iDamageCounter[i] = 0;
        g_bMindControlled[i] = false;
    }"""
content = content.replace(setup_old, setup_new)

# Mind Control Logic
mind_old = r'void Skill_MindControl\(\) \{.*?(?=void Skill_TimeRewind)'
mind_new = r"""void Skill_MindControl() {
    PrintToChatAll(" \x04[Танос] \x02Контроль Сознания! Управление инвертировано!");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            if (GetRandomInt(1, 2) == 1) {
                g_bMindControlled[i] = true;
                CreateTimer(5.0, Timer_RemoveMindControl, GetClientUserId(i));
            }
        }
    }
}

public Action Timer_RemoveMindControl(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) g_bMindControlled[client] = false;
    return Plugin_Stop;
}
"""
content = re.sub(mind_old, mind_new.replace('\\', '\\\\'), content, flags=re.DOTALL)

# Add inversion logic to OnPlayerRunCmd
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
        return Plugin_Changed;
    }

    if (client != g_iBossClient) return Plugin_Continue;"""
content = content.replace(runcmd_old, runcmd_new)

# Reality Logic
reality_old = r'void Skill_Reality\(\) \{.*?(?=void Skill_MindControl)'
reality_new = r"""void Skill_Reality() {
    PrintToChatAll(" \x04[Танос] \x02Искажение Реальности!");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            SetEntProp(i, Prop_Send, "m_iDefaultFOV", 140);
            CreateTimer(7.0, Timer_RemoveReality, GetClientUserId(i));
        }
    }
}

public Action Timer_RemoveReality(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) {
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
    }
    return Plugin_Stop;
}
"""
content = re.sub(reality_old, reality_new.replace('\\', '\\\\'), content, flags=re.DOTALL)


with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
