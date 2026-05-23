import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# SetupBoss logic change
setup_old = r'SetEntityHealth\(client, 50000\);'
setup_new = """SetEntityHealth(client, g_iBossHP);
    SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iBossHP);"""
content = re.sub(setup_old, setup_new, content)

# OnTakeDamage logic change
damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype\) \{.*?(?=void CheckUltimates)'
damage_new = """public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;

    if (damage <= 0.0) return Plugin_Continue;

    if (g_bFinalPhaseActive) {
        damage *= 0.5; // Щит в финальной фазе
    }

    // Позволяем движку (и другим плагинам типа rpg_core) обрабатывать этот урон
    // Просто синхронизируем наше значение
    g_iBossHP = GetClientHealth(victim) - RoundFloat(damage);

    if (attacker > 0 && attacker <= MaxClients && !IsFakeClient(attacker)) {
        g_bPlayerParticipated[attacker] = true;
        PrintCenterText(attacker, "УРОН ПО БОССУ: -%d | ОСТАЛОСЬ: %d", RoundFloat(damage), g_iBossHP);

        g_iDamageCounter[attacker] += RoundFloat(damage);
        if (g_iDamageCounter[attacker] >= 5000) {
            g_iDamageCounter[attacker] -= 5000;
            if (GetRandomFloat(0.0, 100.0) <= GetBossDropChance(g_iBossRarity)) GiveRandomResource(attacker);
        }
    }

    CheckUltimates();

    return Plugin_Changed; // Меняем урон если сработал щит
}
"""
content = re.sub(damage_old, damage_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
