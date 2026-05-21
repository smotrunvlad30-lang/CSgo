// ==============================================================================
// МОДУЛЬ 2: АТАКА, УРОН И ЭФФЕКТЫ (rpg_skills_attack.sp)
// Навыки: dmg_lvl, crit_lvl, arm_dest, arm_pierc, deadly, devil, vamp_lvl, atk_spd
// + ПОЛНАЯ ИНТЕГРАЦИЯ ХАРАКТЕРИСТИК ИЗ АДМИНКИ САЙТА
// ==============================================================================

int g_iVampCount[MAXPLAYERS + 1]; 
bool g_bDeadlyShotReady[MAXPLAYERS + 1]; 
float g_flBleedTime[MAXPLAYERS + 1];     

void Attack_OnPluginStart() {
    HookEvent("round_start", Attack_Event_RoundStart);
    HookEvent("weapon_reload", Attack_Event_WeaponReload); 
    HookEvent("weapon_fire", Attack_Event_WeaponFire);    
    
    PrecacheSound("physics/glass/glass_impact_bullet1.wav", true);
    PrecacheSound("physics/glass/glass_impact_bullet2.wav", true);
    PrecacheSound("physics/glass/glass_impact_bullet3.wav", true);
    PrecacheSound("physics/glass/glass_sheet_impact_hard1.wav", true);
}

// Специальная функция для вампиризма (хил сверх лимита)[cite: 32]
void HealPlayerVamp(int client, int amount) {
    if (amount <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
    int cur = GetClientHealth(client);
    SetEntityHealth(client, cur + amount);
    PrintCenterText(client, "★ ВАМПИРИЗМ: +%d HP ★", amount);
}

public void Attack_Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_iVampCount[i] = 0;
        g_bDeadlyShotReady[i] = false;
        g_flBleedTime[i] = 0.0;
    }
}

void Attack_OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, Attack_OnTakeDamage);
    g_iVampCount[client] = 0;
    g_bDeadlyShotReady[client] = false;
}

// Навык: Скорость атаки[cite: 32]
public void Attack_Event_WeaponFire(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    int atkLvl = GetSkillLevel(client, "atk_spd");
    if (atkLvl > 0) {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if (weapon != -1) {
            float nextAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
            float delay = nextAttack - GetGameTime();
            if (delay > 0.0) {
                float newDelay = delay * (1.0 - (atkLvl * 0.006)); 
                SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + newDelay);
            }
        }
    }
}

// Навык: Смертельный выстрел[cite: 32]
public void Attack_Event_WeaponReload(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client)) {
        int deadlyLvl = GetSkillLevel(client, "deadly");
        if (deadlyLvl > 0) {
            g_bDeadlyShotReady[client] = true;
        }
    }
}

public Action Attack_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker)) return Plugin_Continue;
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return Plugin_Continue;
    if (attacker == victim) return Plugin_Continue;

    bool bChanged = false;
    float originalDamage = damage;
    char sWeapon[32]; GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
    bool isKnife = (StrContains(sWeapon, "knife") != -1 || StrContains(sWeapon, "bayonet") != -1);

    // ==============================================================================
    // 1. ЗАЩИТА ЖЕРТВЫ (СНИЖЕНИЕ УРОНА, БЛОК)
    // ==============================================================================
    
    // Шанс полностью заблокировать урон (Предметы)
    if (g_fItem_BlockChance[victim] > 0.0 && GetRandomFloat(0.0, 100.0) <= g_fItem_BlockChance[victim]) {
        damage = 0.0;
        PrintToChat(victim, "[\x04RPG\x01] Вы \x04ЗАБЛОКИРОВАЛИ\x01 урон щитом!");
        return Plugin_Changed;
    }

    // Снижение входящего урона (Предметы)
    float resist = g_fItem_DmgReduction[victim] / 100.0;
    
    // Бонус защиты при полном ХП (Предметы)
    if (GetClientHealth(victim) >= GetMaxHealth(victim)) {
        resist += (g_fItem_FullHpBonus[victim] / 100.0);
    }
    
    if (resist > 0.0) {
        if (resist > 0.9) resist = 0.9; // Кап резиста 90%, чтобы не было бессмертия
        damage *= (1.0 - resist);
        bChanged = true;
    }

    // ==============================================================================
    // 2. РАСЧЕТ УРОНА АТАКУЮЩЕГО (RPG + ПРЕДМЕТЫ)
    // ==============================================================================
    
    int dmgLvl = GetSkillLevel(attacker, "dmg_lvl");
    float dmgMult = 1.0 + (float(dmgLvl) * GetSkillPower("dmg_lvl") / 100.0) + (g_fItem_DmgPct[attacker] / 100.0);
    
    // Бонус при низком ХП (Предметы)
    if (GetClientHealth(attacker) <= (GetMaxHealth(attacker) * 0.3)) {
        dmgMult += (g_fItem_LowHpBonus[attacker] / 100.0);
    }
    
    // Доп. урон в голову (Предметы)
    if (damagetype & CS_DMG_HEADSHOT) {
        dmgMult += (g_fItem_HsBonus[attacker] / 100.0);
    }

    // Добавляем плоский урон от предметов перед умножением
    damage += g_fItem_DmgFlat[attacker];
    
    if (dmgMult > 1.0) {
        damage *= dmgMult;
        bChanged = true;
    }

    // Смертельный выстрел (RPG)[cite: 32]
    if (g_bDeadlyShotReady[attacker]) {
        damage += (float(GetSkillLevel(attacker, "deadly")) * GetSkillPower("deadly"));
        g_bDeadlyShotReady[attacker] = false;
        bChanged = true;
    }

    // Критический удар (RPG + Предметы)
    int critLvl = GetSkillLevel(attacker, "crit_lvl");
    float critChance = (float(critLvl) * GetSkillPower("crit_lvl")) + g_fItem_CritChance[attacker];
    if (critChance > 0.0 && GetRandomFloat(0.0, 100.0) <= critChance) {
        damage *= 3.0;
        bChanged = true;
    }

    // ==============================================================================
    // 3. ЭФФЕКТЫ ПРИ ПОПАДАНИИ (ОТ ПРЕДМЕТОВ И RPG)
    // ==============================================================================
    
    // Лечение за попадание (Предметы)
    if (g_fItem_HealOnHit[attacker] > 0.0) {
        HealPlayer(attacker, RoundToFloor(g_fItem_HealOnHit[attacker]));
    }
    
    // Поджог (Предметы)
    if (g_fItem_BurnChance[attacker] > 0.0 && GetRandomFloat(0.0, 100.0) <= g_fItem_BurnChance[attacker]) {
        IgniteEntity(victim, 3.0);
    }
    
    // Замедление (Предметы)
    if (g_fItem_SlowChance[attacker] > 0.0 && GetRandomFloat(0.0, 100.0) <= g_fItem_SlowChance[attacker]) {
        SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", 0.5);
        CreateTimer(3.0, Timer_ResetItemSpeed, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    // Оглушение (Предметы)
    if (g_fItem_StunChance[attacker] > 0.0 && GetRandomFloat(0.0, 100.0) <= g_fItem_StunChance[attacker]) {
        SetEntityMoveType(victim, MOVETYPE_NONE);
        SetEntityRenderColor(victim, 255, 255, 0, 255); 
        CreateTimer(1.0, Timer_ResetItemStun, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    // Кровотечение (Предметы)
    if (g_fItem_BleedChance[attacker] > 0.0 && GetRandomFloat(0.0, 100.0) <= g_fItem_BleedChance[attacker]) {
        g_flBleedTime[victim] = GetEngineTime() + 5.0;
        CreateTimer(1.0, Timer_BleedTick, GetClientUserId(victim), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    
    // Отталкивание (Предметы)
    if (g_fItem_PushChance[attacker] > 0.0 && GetRandomFloat(0.0, 100.0) <= g_fItem_PushChance[attacker]) {
        float posV[3], posA[3], dir[3];
        GetClientAbsOrigin(victim, posV);
        GetClientAbsOrigin(attacker, posA);
        SubtractVectors(posV, posA, dir);
        NormalizeVector(dir, dir);
        ScaleVector(dir, 600.0);
        TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, dir);
    }

    // Отражение урона (Предметы)
    if (g_fItem_ReflectChance[victim] > 0.0 && GetRandomFloat(0.0, 100.0) <= 20.0) {
        float reflectDmg = originalDamage * (g_fItem_ReflectChance[victim] / 100.0);
        SDKHooks_TakeDamage(attacker, victim, victim, reflectDmg, DMG_GENERIC);
    }
    
    // Вампиризм (RPG + Предметы)[cite: 32]
    float vampChance = 50.0; 
    float vampPct = (float(GetSkillLevel(attacker, "vamp_lvl")) * GetSkillPower("vamp_lvl") / 100.0) + (g_fItem_Vampirism[attacker] / 100.0);
    if (vampPct > 0.0 && g_iVampCount[attacker] < 35) {
        if (GetRandomFloat(0.0, 100.0) <= vampChance) {
            int heal = RoundToFloor(damage * vampPct);
            if (heal > 0) {
                HealPlayerVamp(attacker, heal); 
                g_iVampCount[attacker]++;
            }
        }
    }

    // Уничтожитель брони (RPG)[cite: 32]
    int armDestLvl = GetSkillLevel(attacker, "arm_dest");
    if (armDestLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(armDestLvl) * GetSkillPower("arm_dest"))) {
        int armor = GetEntProp(victim, Prop_Send, "m_ArmorValue");
        if (armor > 0) SetEntProp(victim, Prop_Send, "m_ArmorValue", (armor - armDestLvl < 0) ? 0 : armor - armDestLvl);
    }

    // Бронебойные патроны (RPG)[cite: 32]
    if (!isKnife && GetRandomFloat(0.0, 100.0) <= (float(GetSkillLevel(attacker, "arm_pierc")) * GetSkillPower("arm_pierc"))) {
        damagetype |= DMG_POISON; // Урон игнорирует броню
        bChanged = true;
    }

    if (bChanged) return Plugin_Changed;
    return Plugin_Continue;
}

// ==============================================================================
// ТАЙМЕРЫ ДЛЯ ЭФФЕКТОВ
// ==============================================================================

public Action Timer_BleedTick(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsPlayerAlive(client) && GetEngineTime() < g_flBleedTime[client]) {
        SDKHooks_TakeDamage(client, 0, 0, 5.0, DMG_GENERIC);
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

public Action Timer_ResetItemSpeed(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsPlayerAlive(client)) {
        // Возвращаем скорость, учитывая прокачку RPG и плоские бонусы предметов
        float baseSpeed = 1.0 + (float(GetSkillLevel(client, "speed")) * GetSkillPower("speed") / 100.0);
        float finalSpeed = baseSpeed * (1.0 + (g_fItem_SpeedPct[client] / 100.0));
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", finalSpeed);
    }
    return Plugin_Stop;
}

public Action Timer_ResetItemStun(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsPlayerAlive(client)) {
        SetEntityMoveType(client, MOVETYPE_WALK);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
    return Plugin_Stop;
}