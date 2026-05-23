import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Remove g_iBossHP and use only g_iBossMaxHP
content = content.replace("int g_iBossHP = 0;\n", "")

# Rewrite OnClientPutInServer to add OnTakeDamagePost
client_old = r'public void OnClientPutInServer\(int client\) \{.*?(?=public Action Timer_CheckTime)'
client_new = """public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
    g_iDamageCounter[client] = 0;
    g_bPlayerParticipated[client] = false;
    g_bMindControlled[client] = false;
}
"""
content = re.sub(client_old, client_new, content, flags=re.DOTALL)

# Rewrite SetupBoss, Event_PlayerSpawn, and Timer_SetBossHealth to use only pure engine health
setup_old = r'void SetupBoss\(int client\) \{.*?(?=void StripAllWeapons)'
setup_new = r"""void SetupBoss(int client) {
    g_iBossMaxHP = GetBossConfigHP(g_iBossRarity);
    g_flBossEndTime = GetEngineTime() + 600.0;

    g_iTimeRewindCount = 0; g_bSnapUsed = false; g_bRageActive = false; g_bFinalPhaseActive = false; g_iSoulStealKills = 0;

    for (int i = 1; i <= MaxClients; i++) {
        g_bPlayerParticipated[i] = false;
        g_iDamageCounter[i] = 0;
        g_bMindControlled[i] = false;

        if (IsClientInGame(i) && !IsFakeClient(i) && i != client) {
            ChangeClientTeam(i, CS_TEAM_CT);
            CS_RespawnPlayer(i);
        }
    }

    SetEntityModel(client, g_sBossModel);

    SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iBossMaxHP);
    SetEntityHealth(client, g_iBossMaxHP);

    StripAllWeapons(client);
    GivePlayerItem(client, "weapon_knife");

    g_hHudTimer = CreateTimer(1.0, Timer_UpdateHud, _, TIMER_REPEAT);
    g_hRespawnTimer = CreateTimer(3.0, Timer_RespawnCTs, _, TIMER_REPEAT);
    g_hSkillTimer = CreateTimer(15.0, Timer_PrepareSkill, _, TIMER_REPEAT);

    ServerCommand("mp_ignore_round_win_conditions 1");

    PrintToChatAll(" \x04[RPG] \x02БОСС ТАНОС ПОЯВИЛСЯ! ВСЕ ПЕРЕВЕДЕНЫ ЗА CT. У ВАС 10 МИНУТ!");
}
"""
content = re.sub(setup_old, setup_new.replace('\\', '\\\\'), content, flags=re.DOTALL)

spawn_old = r'public Action Event_PlayerSpawn\(Event event, const char\[\] name, bool dontBroadcast\) \{.*?(?=void EndBossFight)'
spawn_new = """public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_bBossActive && client == g_iBossClient) {
        StripAllWeapons(client);
        GivePlayerItem(client, "weapon_knife");
        SetEntityModel(client, g_sBossModel);

        CreateTimer(0.2, Timer_SetBossHealth, GetClientUserId(client));
    }
    return Plugin_Continue;
}

public Action Timer_SetBossHealth(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && g_bBossActive && client == g_iBossClient) {
        SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iBossMaxHP);
        SetEntityHealth(client, g_iBossMaxHP);
    }
    return Plugin_Stop;
}

"""
content = re.sub(spawn_old, spawn_new, content, flags=re.DOTALL)


# Rewrite OnTakeDamage and CheckUltimates
damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce\[3\], float damagePosition\[3\]\) \{.*?(?=public Action Timer_PrepareSkill)'
damage_new = r"""public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;
    if (damage <= 0.0) return Plugin_Continue;

    if (g_bFinalPhaseActive) damage *= 0.5;

    // Блокируем замедление/отбрасывание
    damageForce[0] = 0.0;
    damageForce[1] = 0.0;
    damageForce[2] = 0.0;

    return Plugin_Changed;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom) {
    if (!g_bBossActive || victim != g_iBossClient) return;

    int currentHP = GetClientHealth(victim);
    if (attacker > 0 && attacker <= MaxClients && !IsFakeClient(attacker)) {
        g_bPlayerParticipated[attacker] = true;
        PrintCenterText(attacker, "УРОН ПО БОССУ: -%d | ОСТАЛОСЬ: %d", RoundFloat(damage), currentHP);

        g_iDamageCounter[attacker] += RoundFloat(damage);
        if (g_iDamageCounter[attacker] >= 5000) {
            g_iDamageCounter[attacker] -= 5000;
            if (GetRandomFloat(0.0, 100.0) <= GetBossDropChance(g_iBossRarity)) GiveRandomResource(attacker);
        }
    }
    CheckUltimates(currentHP);
}

void CheckUltimates(int currentHP) {
    float hpPct = float(currentHP) / float(g_iBossMaxHP);
    if (hpPct <= 0.5 && !g_bSnapUsed) { g_bSnapUsed = true; Skill_Snap(); }
    if (hpPct <= 0.3 && !g_bRageActive) { g_bRageActive = true; PrintToChatAll(" \x04[Танос] \x02ЯРОСТЬ ТИТАНА! Скорость увеличена!"); }
    if (hpPct <= 0.1 && !g_bFinalPhaseActive) {
        g_bFinalPhaseActive = true;
        PrintToChatAll(" \x04[Танос] \x02Я НЕИЗБЕЖЕН!");
        if (g_hSkillTimer != null) KillTimer(g_hSkillTimer);
        g_hSkillTimer = CreateTimer(7.0, Timer_PrepareSkill, _, TIMER_REPEAT);
    }
}

"""
content = re.sub(damage_old, damage_new.replace('\\', '\\\\'), content, flags=re.DOTALL)


# Fix HUD
hud_old = r'ShowSyncHudText\(i, g_hHudSync, "ТАНОС \[%s\]\\nХП: %d / %d\\nОсталось: %02d:%02d", rName, g_iBossHP, g_iBossMaxHP, timeLeft / 60, timeLeft % 60\);'
hud_new = r'ShowSyncHudText(i, g_hHudSync, "ТАНОС [%s]\\nХП: %d / %d\\nОсталось: %02d:%02d", rName, currentHP, g_iBossMaxHP, timeLeft / 60, timeLeft % 60);'
content = re.sub(hud_old, hud_new, content)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
