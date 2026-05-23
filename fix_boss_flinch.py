import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Update OnTakeDamage to perfectly block engine damage and avoid bleeding flinching
damage_old = r'public Action OnTakeDamage\(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce\[3\], float damagePosition\[3\]\) \{.*?(?=public Action Event_PlayerDeath)'
damage_new = """public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
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

    // Блокируем весь реальный урон движка (чтобы не было спама звуков/дерганий модельки от кровотечений и пуль)
    return Plugin_Handled;
}

void CheckUltimates() {
    float hpPct = float(g_iBossHP) / float(g_iBossMaxHP);
    if (hpPct <= 0.5 && !g_bSnapUsed) { g_bSnapUsed = true; Skill_Snap(); }
    if (hpPct <= 0.3 && !g_bRageActive) { g_bRageActive = true; PrintToChatAll(" \\x04[Танос] \\x02ЯРОСТЬ ТИТАНА! Скорость увеличена!"); }
    if (hpPct <= 0.1 && !g_bFinalPhaseActive) {
        g_bFinalPhaseActive = true;
        PrintToChatAll(" \\x04[Танос] \\x02Я НЕИЗБЕЖЕН!");
        if (g_hSkillTimer != null) KillTimer(g_hSkillTimer);
        g_hSkillTimer = CreateTimer(7.0, Timer_PrepareSkill, _, TIMER_REPEAT);
    }
}

public Action Timer_PrepareSkill(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsPlayerAlive(g_iBossClient)) return Plugin_Continue;
    g_iNextSkill = GetRandomInt(1, 6);
    g_iWarningCount = 3;
    g_hWarningTimer = CreateTimer(1.0, Timer_SkillCountdown, _, TIMER_REPEAT);
    return Plugin_Continue;
}

public Action Timer_SkillCountdown(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsPlayerAlive(g_iBossClient)) {
        g_hWarningTimer = null;
        return Plugin_Stop;
    }

    if (g_iWarningCount <= 0) {
        ExecuteSkill();
        g_hWarningTimer = null;
        return Plugin_Stop;
    }

    char sSkillName[256];
    switch (g_iNextSkill) {
        case 1: sSkillName = "Удар Титана";
        case 2: sSkillName = "Телепортация";
        case 3: sSkillName = "Искажение Реальности";
        case 4: sSkillName = "Контроль Сознания";
        case 5: sSkillName = "Откат Времени";
        case 6: sSkillName = "Космический Разлом";
    }

    SetHudTextParams(-1.0, 0.4, 1.1, 255, 0, 0, 255, 0, 0.0, 0.0, 0.0);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) ShowSyncHudText(i, g_hHudSync, "ТАНОС ИСПОЛЬЗУЕТ: %s\\nЧерез %d сек!", sSkillName, g_iWarningCount);
    }
    g_iWarningCount--;
    return Plugin_Continue;
}

void ExecuteSkill() {
    switch (g_iNextSkill) {
        case 1: Skill_TitanStrike();
        case 2: Skill_Teleport();
        case 3: Skill_Reality();
        case 4: Skill_MindControl();
        case 5: Skill_TimeRewind();
        case 6: Skill_CosmicRift();
    }
}

void Skill_TitanStrike() {
    float bPos[3]; GetClientAbsOrigin(g_iBossClient, bPos);
    TE_SetupBeamRingPoint(bPos, 10.0, 400.0, g_iLaserModel, g_iHaloModel, 0, 10, 1.0, 20.0, 0.0, {255, 0, 255, 255}, 10, 0);
    TE_SendToAll();

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            float pPos[3]; GetClientAbsOrigin(i, pPos);
            if (GetVectorDistance(bPos, pPos) < 400.0) {
                SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 400.0, DMG_BLAST);
                float dir[3]; SubtractVectors(pPos, bPos, dir);
                NormalizeVector(dir, dir); ScaleVector(dir, 1000.0); dir[2] = 300.0;
                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, dir);
            }
        }
    }
}

void Skill_Teleport() {
    int target = GetRandomPlayer();
    if (target != -1) {
        float bPos[3]; GetClientAbsOrigin(g_iBossClient, bPos);
        TE_SetupSmoke(bPos, g_iSmokeModel, 100.0, 10); TE_SendToAll();

        float tPos[3]; GetClientAbsOrigin(target, tPos);
        TeleportEntity(g_iBossClient, tPos, NULL_VECTOR, NULL_VECTOR);
        TE_SetupSmoke(tPos, g_iSmokeModel, 100.0, 10); TE_SendToAll();
        Skill_TitanStrike();
    }
}

void Skill_Reality() {
    PrintToChatAll(" \\x04[Танос] \\x02Искажение Реальности!");
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

void Skill_MindControl() {
    PrintToChatAll(" \\x04[Танос] \\x02Контроль Сознания! Управление инвертировано!");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            if (GetRandomInt(1, 2) == 1) {
                g_bMindControlled[i] = true;
                g_iMindControlType[i] = GetRandomInt(0, 2);
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

void Skill_TimeRewind() {
    if (g_iTimeRewindCount < 3) {
        int heal = RoundFloat(g_iBossMaxHP * 0.1);
        g_iBossHP += heal;
        if (g_iBossHP > g_iBossMaxHP) g_iBossHP = g_iBossMaxHP;
        g_iTimeRewindCount++;
        float bPos[3]; GetClientAbsOrigin(g_iBossClient, bPos);
        TE_SetupBeamRingPoint(bPos, 10.0, 200.0, g_iLaserModel, g_iHaloModel, 0, 10, 1.0, 20.0, 0.0, {0, 255, 0, 255}, 10, 0);
        TE_SendToAll();
    }
}

void Skill_Snap() {
    PrintToChatAll(" \\x04[Танос] \\x02*Щелчок*");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            // 50% шанс мгновенной смерти для каждого игрока
            if (GetRandomInt(1, 2) == 1) {
                float pPos[3]; GetClientAbsOrigin(i, pPos);
                TE_SetupSmoke(pPos, g_iSmokeModel, 50.0, 5); TE_SendToAll();
                SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 9999999.0, DMG_DISSOLVE);
            }
        }
    }
}

void Skill_CosmicRift() {
    for(int i=0; i<3; i++) {
        int target = GetRandomPlayer();
        if (target != -1) {
            float pPos[3]; GetClientAbsOrigin(target, pPos);
            TE_SetupBeamRingPoint(pPos, 10.0, 300.0, g_iLaserModel, g_iHaloModel, 0, 10, 2.0, 30.0, 0.0, {128, 0, 128, 255}, 10, 0);
            TE_SendToAll();

            DataPack pack = new DataPack();
            pack.WriteFloat(pPos[0]);
            pack.WriteFloat(pPos[1]);
            pack.WriteFloat(pPos[2]);
            CreateTimer(2.0, Timer_RiftDamage, pack);
        }
    }
}

public Action Timer_RiftDamage(Handle timer, DataPack pack) {
    pack.Reset();
    float pPos[3];
    pPos[0] = pack.ReadFloat();
    pPos[1] = pack.ReadFloat();
    pPos[2] = pack.ReadFloat();
    delete pack;

    TE_SetupSmoke(pPos, g_iSmokeModel, 300.0, 10);
    TE_SendToAll();

    for (int j = 1; j <= MaxClients; j++) {
        if (IsClientInGame(j) && IsPlayerAlive(j) && j != g_iBossClient) {
            float victimPos[3]; GetClientAbsOrigin(j, victimPos);
            if (GetVectorDistance(pPos, victimPos) <= 300.0) {
                SDKHooks_TakeDamage(j, g_iBossClient, g_iBossClient, 600.0, DMG_BLAST);
                float dir[3]; SubtractVectors(victimPos, pPos, dir);
                NormalizeVector(dir, dir); ScaleVector(dir, 800.0); dir[2] = 400.0;
                TeleportEntity(j, NULL_VECTOR, NULL_VECTOR, dir);
            }
        }
    }
    return Plugin_Stop;
}
"""
content = re.sub(damage_old, damage_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
