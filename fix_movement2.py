import re

with open("ФАйлы сервера кс го/rpg_skills_movement.sp", "r", encoding="utf-8") as f:
    content = f.read()

movement_old = r'void Movement_ApplyStatsFromItems\(int client\) \{.*?(?=// Главная функция)'
movement_new = """void Movement_ApplyStatsFromItems(int client) {
    if (!IsPlayerAlive(client) || !g_bLoaded[client]) return;

    // --- 1. СКОРОСТЬ (RPG + ПРЕДМЕТЫ) ---
    int spdLvl = GetSkillLevel(client, "speed");
    float spdPower = GetSkillPower("speed");
    if (spdPower <= 0.0) spdPower = 0.8;

    float rpgSpeedBonus = (float(spdLvl) * spdPower) / 100.0;
    float itemSpeedBonus = g_fItem_SpeedPct[client] / 100.0;

    g_fSpeedCache[client] = 1.0 + rpgSpeedBonus + itemSpeedBonus;

    // --- 2. ГРАВИТАЦИЯ (RPG + ПРЕДМЕТЫ) ---
    int gLvl = GetSkillLevel(client, "grav");
    float gravPower = GetSkillPower("grav");
    if (gravPower <= 0.0) gravPower = 5.0;

    float rpgGravReduction = (float(gLvl) * gravPower) / 800.0;
    float itemGravReduction = g_fItem_GravityFlat[client] / 800.0;

    g_fGravCache[client] = 1.0 - rpgGravReduction - itemGravReduction;

    // Лимиты безопасности
    if (g_fGravCache[client] < 0.1) g_fGravCache[client] = 0.1;
    if (g_fGravCache[client] > 1.0) g_fGravCache[client] = 1.0;

    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeedCache[client]);
    SetEntityGravity(client, g_fGravCache[client]);
}

"""
content = re.sub(movement_old, movement_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_skills_movement.sp", "w", encoding="utf-8") as f:
    f.write(content)

with open("ФАйлы сервера кс го/rpg_skills_attack.sp", "r", encoding="utf-8") as f:
    content = f.read()

reset_speed_old = r'public Action Timer_ResetItemSpeed\(Handle timer, any userid\) \{.*?(?=public Action Timer_ResetItemStun)'
reset_speed_new = """public Action Timer_ResetItemSpeed(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsPlayerAlive(client)) {
        Movement_ApplyStatsFromItems(client);
    }
    return Plugin_Stop;
}

"""
content = re.sub(reset_speed_old, reset_speed_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_skills_attack.sp", "w", encoding="utf-8") as f:
    f.write(content)
