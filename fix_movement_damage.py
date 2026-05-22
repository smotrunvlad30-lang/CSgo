import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update OnPlayerRunCmd to correctly orient and move the bot.
runcmd_old = r'public Action OnPlayerRunCmd\(int client, int &buttons, int &impulse, float vel\[3\], float angles\[3\], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse\[2\]\) \{.*?(?=public Action OnTakeDamage)'
runcmd_new = """public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (!g_bBossActive || client != g_iBossClient || !IsPlayerAlive(client)) return Plugin_Continue;

    float speedMult = 1.0;
    if (g_bRageActive) speedMult = 1.5;
    if (g_bFinalPhaseActive) speedMult = 2.0;
    SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", speedMult);

    int target = GetNearestPlayer(client);
    if (target != -1) {
        float bPos[3], tPos[3], dir[3], ang[3];
        GetClientEyePosition(client, bPos);
        GetClientEyePosition(target, tPos);

        // Вычисляем вектор направления
        SubtractVectors(tPos, bPos, dir);
        float dist = GetVectorLength(dir);

        // Преобразуем вектор в углы обзора
        GetVectorAngles(dir, ang);

        // Устанавливаем углы для бота
        angles[0] = ang[0];
        angles[1] = ang[1];
        angles[2] = 0.0; // Не крутим головой по оси Z

        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR); // Заставляем смотреть на цель

        // Заставляем бота бежать вперед (vel[0] = forward)
        vel[0] = 300.0 * speedMult;
        buttons |= IN_FORWARD;

        if (dist < 100.0) {
            buttons |= IN_ATTACK;
            if (GetEngineTime() - g_flLastAttackTime >= 1.0) {
                float dmgValue = 500.0 + (g_iBossRarity * 200.0) + (g_iSoulStealKills * 50.0);
                if (g_bRageActive) dmgValue *= 1.5;
                SDKHooks_TakeDamage(target, client, client, dmgValue, DMG_CLUB);
                g_flLastAttackTime = GetEngineTime();
            }
        }
        return Plugin_Changed;
    }
    return Plugin_Continue;
}"""
content = re.sub(runcmd_old, runcmd_new + "\n\n", content, flags=re.DOTALL)

# 2. Update OnTakeDamage to prevent hit flinch spam and handle damage cleanly.
damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype\) \{.*?(?=void CheckUltimates)'
damage_new = """public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled; // Нет урона от падения
    if (damage <= 0.0) return Plugin_Continue;

    float dmgDealt = damage;
    if (g_bFinalPhaseActive) dmgDealt *= 0.5;

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
        // Если HP кончилось, убиваем бота по-настоящему, возвращаем обычный урон
        damage = 9999999.0;
        return Plugin_Changed;
    }

    // Блокируем весь реальный урон движка (чтобы не было спама звуков/дерганий модельки)
    // Но визуально игрок будет видеть попадания по крови, если стоит sv_showimpacts
    return Plugin_Handled;
}"""
content = re.sub(damage_old, damage_new + "\n\n", content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
