import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

setup_old = r'void SetupBoss\(int client\) \{.*?(?=void StripAllWeapons)'
setup_new = r"""void SetupBoss(int client) {
    g_iBossHP = GetBossConfigHP(g_iBossRarity);
    g_iBossMaxHP = g_iBossHP;
    g_flBossEndTime = GetEngineTime() + 600.0;

    g_iTimeRewindCount = 0; g_bSnapUsed = false; g_bRageActive = false; g_bFinalPhaseActive = false; g_iSoulStealKills = 0;
    for (int i = 1; i <= MaxClients; i++) { g_bPlayerParticipated[i] = false; g_iDamageCounter[i] = 0; }

    SetEntityModel(client, g_sBossModel);

    // Даем боту обычное здоровье, чтобы движок не сходил с ума от миллионов
    SetEntityHealth(client, 50000);

    StripAllWeapons(client);
    GivePlayerItem(client, "weapon_knife");

    g_hHudTimer = CreateTimer(1.0, Timer_UpdateHud, _, TIMER_REPEAT);
    g_hRespawnTimer = CreateTimer(3.0, Timer_RespawnCTs, _, TIMER_REPEAT);
    g_hSkillTimer = CreateTimer(15.0, Timer_PrepareSkill, _, TIMER_REPEAT);

    ServerCommand("mp_ignore_round_win_conditions 1");

    PrintToChatAll(" \x04[RPG] \x02БОСС ТАНОС ПОЯВИЛСЯ! У ВАС ЕСТЬ 10 МИНУТ!");
}
"""
content = re.sub(setup_old, setup_new.replace('\\', '\\\\'), content, flags=re.DOTALL)

runcmd_old = r'public Action OnPlayerRunCmd\(int client, int &buttons, int &impulse, float vel\[3\], float angles\[3\], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse\[2\]\) \{.*?(?=public Action OnTakeDamage)'
runcmd_new = """public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (!g_bBossActive || client != g_iBossClient || !IsPlayerAlive(client)) return Plugin_Continue;

    // Уменьшаем базовую скорость босса
    float speedMult = 0.7;
    if (g_bRageActive) speedMult = 1.0;
    if (g_bFinalPhaseActive) speedMult = 1.3;

    SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", speedMult);

    int target = GetNearestPlayer(client);
    if (target != -1) {
        float bPos[3], tPos[3], dir[3], ang[3];
        GetClientEyePosition(client, bPos);
        GetClientEyePosition(target, tPos);

        SubtractVectors(tPos, bPos, dir);
        float dist = GetVectorLength(dir);

        GetVectorAngles(dir, ang);
        angles[0] = ang[0];
        angles[1] = ang[1];
        angles[2] = 0.0;

        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);

        // Уменьшаем скорость бега бота
        vel[0] = 200.0 * speedMult;
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
}
"""
content = re.sub(runcmd_old, runcmd_new, content, flags=re.DOTALL)

damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype\) \{.*?(?=void CheckUltimates)'
damage_new = """public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;

    if (damage <= 0.0) return Plugin_Continue;

    float dmgDealt = damage;
    if (g_bFinalPhaseActive) dmgDealt *= 0.5;

    // Вычитаем кастомное ХП
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
        // Если босс реально умер, наносим ему реальный урон, чтобы движок убил его
        damage = 9999999.0;
        return Plugin_Changed;
    }

    // Не даем движку убить босса раньше времени
    SetEntityHealth(victim, 50000);

    // Блокируем весь реальный урон движка (чтобы не было спама звуков/дерганий модельки)
    return Plugin_Handled;
}
"""
content = re.sub(damage_old, damage_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
