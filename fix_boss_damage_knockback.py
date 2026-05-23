import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Completely rewrite OnTakeDamage to prevent all engine knockback/flinching while syncing our HP.
damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype\) \{.*?(?=void CheckUltimates)'
damage_new = """public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;

    if (damage <= 0.0) return Plugin_Continue;

    float dmgDealt = damage;
    if (g_bFinalPhaseActive) {
        dmgDealt *= 0.5; // Щит в финальной фазе
    }

    // Вычитаем из нашей кастомной переменной
    g_iBossHP -= RoundFloat(dmgDealt);

    if (attacker > 0 && attacker <= MaxClients && !IsFakeClient(attacker)) {
        g_bPlayerParticipated[attacker] = true;
        PrintCenterText(attacker, "УРОН ПО БОССУ: -%d | ОСТАЛОСЬ: %d", RoundFloat(dmgDealt), g_iBossHP);

        g_iDamageCounter[attacker] += RoundFloat(dmgDealt);
        if (g_iDamageCounter[attacker] >= 5000) {
            g_iDamageCounter[attacker] -= 5000;
            if (GetRandomFloat(0.0, 100.0) <= GetBossDropChance(g_iBossRarity)) GiveRandomResource(attacker);
        }
    }

    CheckUltimates();

    if (g_iBossHP <= 0) {
        g_iBossHP = 0;
        // Если босс мертв, наносим ему финальный урон, чтобы убить по-настоящему
        damage = 9999999.0;
        return Plugin_Changed;
    }

    // Блокируем весь реальный урон движка.
    // Это полностью отключает замедление от пуль (tagging), отбрасывание, и спам звуков попадания.
    // Босс будет бежать сквозь пули как танк.
    return Plugin_Handled;
}
"""
content = re.sub(damage_old, damage_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
