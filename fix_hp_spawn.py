import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update Spawn Event to use a 0.2s timer so CS:GO finishes its 100 HP reset BEFORE we set the real max HP
spawn_old = r'public Action Event_PlayerSpawn\(Event event, const char\[\] name, bool dontBroadcast\) \{.*?(?=void EndBossFight)'
spawn_new = """public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_bBossActive && client == g_iBossClient) {
        StripAllWeapons(client);
        GivePlayerItem(client, "weapon_knife");
        SetEntityModel(client, g_sBossModel);

        // CS:GO сбрасывает ХП до 100 *после* этого хука.
        // Делаем задержку в 0.2 сек, чтобы гарантированно установить правильное здоровье.
        CreateTimer(0.2, Timer_SetBossHealth, GetClientUserId(client));
    }
    return Plugin_Continue;
}

public Action Timer_SetBossHealth(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && g_bBossActive && client == g_iBossClient) {
        // Устанавливаем движковое максимальное здоровье и текущее, чтобы не было багов с уроном
        SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iBossMaxHP);
        SetEntityHealth(client, g_iBossHP);
    }
    return Plugin_Stop;
}

"""
content = re.sub(spawn_old, spawn_new, content, flags=re.DOTALL)


# 2. Update OnTakeDamage to perfectly sync our g_iBossHP with the engine damage instead of getting out of sync
damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype\) \{.*?(?=void CheckUltimates)'
damage_new = """public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;

    if (damage <= 0.0) return Plugin_Continue;

    if (g_bFinalPhaseActive) {
        damage *= 0.5; // Щит в финальной фазе
    }

    // Вычитаем из нашей кастомной переменной
    g_iBossHP -= RoundFloat(damage);

    // Синхронизируем движок, чтобы не было багов отображения
    // Если босс умер, не мешаем движку убить его
    if (g_iBossHP > 0) {
        SetEntityHealth(victim, g_iBossHP);
    }

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

    // Разрешаем движку и RPG плагину обработать этот урон
    return Plugin_Changed;
}
"""
content = re.sub(damage_old, damage_new, content, flags=re.DOTALL)


with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
