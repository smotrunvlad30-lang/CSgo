import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Fix TimeRewind
time_old = r'void Skill_TimeRewind\(\) \{.*?(?=void Skill_Snap)'
time_new = """void Skill_TimeRewind() {
    if (g_iTimeRewindCount < 3) {
        int currentHP = GetClientHealth(g_iBossClient);
        int heal = RoundFloat(g_iBossMaxHP * 0.1);
        currentHP += heal;
        if (currentHP > g_iBossMaxHP) currentHP = g_iBossMaxHP;
        SetEntityHealth(g_iBossClient, currentHP);

        g_iTimeRewindCount++;
        float bPos[3]; GetClientAbsOrigin(g_iBossClient, bPos);
        TE_SetupBeamRingPoint(bPos, 10.0, 200.0, g_iLaserModel, g_iHaloModel, 0, 10, 1.0, 20.0, 0.0, {0, 255, 0, 255}, 10, 0);
        TE_SendToAll();
    }
}

"""
content = re.sub(time_old, time_new, content, flags=re.DOTALL)

# Fix UpdateHud
hud_old = r'SetHudTextParams\(0\.02, 0\.05, 0\.6, 255, 255, 255, 255\);\n    for \(int i = 1; i <= MaxClients; i\+\+\) \{'
hud_new = """SetHudTextParams(0.02, 0.05, 0.6, 255, 255, 255, 255);
    int currentHP = GetClientHealth(g_iBossClient);
    for (int i = 1; i <= MaxClients; i++) {"""
content = re.sub(hud_old, hud_new, content)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
