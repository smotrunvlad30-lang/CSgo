import re

with open("ФАйлы сервера кс го/rpg_skills_movement.sp", "r", encoding="utf-8") as f:
    content = f.read()

movement_old = r'void Movement_ApplyStatsFromItems\(int client\) \{.*?(?=// Главная функция)'
movement_new = """void Movement_ApplyStatsFromItems(int client) {
    if (!IsPlayerAlive(client) || !g_bLoaded[client]) return;

    // --- 1. СКОРОСТЬ (ТОЛЬКО ОТ ПРЕДМЕТОВ) ---
    float itemSpeedBonus = g_fItem_SpeedPct[client] / 100.0;
    g_fSpeedCache[client] = 1.0 + itemSpeedBonus;

    // --- 2. ГРАВИТАЦИЯ (ТОЛЬКО ОТ ПРЕДМЕТОВ) ---
    float itemGravReduction = g_fItem_GravityFlat[client] / 800.0;
    g_fGravCache[client] = 1.0 - itemGravReduction;

    // Лимиты безопасности
    if (g_fGravCache[client] < 0.1) g_fGravCache[client] = 0.1;
    if (g_fGravCache[client] > 1.0) g_fGravCache[client] = 1.0;

    // ПРИНУДИТЕЛЬНО ПРИМЕНЯЕМ СРАЗУ
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeedCache[client]);
    SetEntityGravity(client, g_fGravCache[client]);
}

"""
content = re.sub(movement_old, movement_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_skills_movement.sp", "w", encoding="utf-8") as f:
    f.write(content)
