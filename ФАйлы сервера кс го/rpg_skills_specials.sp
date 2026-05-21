// ==============================================================================
// МОДУЛЬ 6: СПЕЦ-ОРУЖИЕ, ГРАНАТЫ И ЧУТЬЕ СНАЙПЕРА (rpg_skills_specials.sp)
// ==============================================================================

int g_iLaserModel;

void Specials_OnPluginStart() {
    HookEvent("weapon_fire", Specials_Event_WeaponFire);
    HookEvent("hegrenade_detonate", Specials_Event_HEDetonate);
    HookEvent("smokegrenade_detonate", Specials_Event_SmokeDetonate);
    HookEvent("decoy_started", Specials_Event_DecoyStarted);
}

void Specials_OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, Specials_OnTakeDamage);
}

void Specials_OnMapStart() {
    g_iLaserModel = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}

// ------------------------------------------------------------------------------
// ЕЖЕСЕКУНДНЫЙ ЦИКЛ (Реген, ВХ Снайпера)
// ------------------------------------------------------------------------------
void Specials_OnTick(int client) {
    if (!IsPlayerAlive(client)) return;

    // 1. РЕГЕН ТАЗЕРА (zeus_regen)
    int zRegLvl = GetSkillLevel(client, "zeus_regen");
    if (zRegLvl > 0 && (g_iTickCount % (101 - zRegLvl) == 0)) {
        if (!HasWeaponSpecials(client, "weapon_taser")) {
            GivePlayerItem(client, "weapon_taser");
        }
    }

    // 2. РЕГЕН ГРАНАТ (nade_regen)
    int nadeReg = GetSkillLevel(client, "nade_regen");
    if (nadeReg > 0 && (g_iTickCount % (101 - nadeReg) == 0)) {
        if (!HasWeaponSpecials(client, "weapon_hegrenade")) GivePlayerItem(client, "weapon_hegrenade");
        if (!HasWeaponSpecials(client, "weapon_smokegrenade")) GivePlayerItem(client, "weapon_smokegrenade");
        if (!HasWeaponSpecials(client, "weapon_decoy")) GivePlayerItem(client, "weapon_decoy");
    }

    // 3. ЧУТЬЕ СНАЙПЕРА (sniper_sense) - ESP/ВХ без смены цвета экрана
    int senseLvl = GetSkillLevel(client, "sniper_sense");
    if (senseLvl > 0 && GetEntProp(client, Prop_Send, "m_bIsScoped")) {
        float myPos[3]; GetClientEyePosition(client, myPos);
        float maxDist = float(senseLvl) * GetSkillPower("sniper_sense");

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client)) {
                float ePos[3]; GetClientAbsOrigin(i, ePos);
                if (GetVectorDistance(myPos, ePos) <= maxDist) {
                    float eTop[3]; eTop = ePos; eTop[2] += 70.0;
                    
                    // Рисуем вертикальную лазерную линию на враге (видит только снайпер)
                    int color[4] = {255, 0, 0, 255};
                    TE_SetupBeamPoints(ePos, eTop, g_iLaserModel, 0, 0, 0, 1.1, 4.0, 4.0, 0, 0.0, color, 0);
                    TE_SendToClient(client);
                }
            }
        }
    }
}

// ------------------------------------------------------------------------------
// ОРУЖИЕ: ВЫСТРЕЛЫ И УРОН
// ------------------------------------------------------------------------------
public void Specials_Event_WeaponFire(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    char wpn[32]; event.GetString("weapon", wpn, sizeof(wpn));
    
    // Возврат тазера (zeus_return)
    if (StrEqual(wpn, "weapon_taser")) {
        int retLvl = GetSkillLevel(client, "zeus_return");
        if (retLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(retLvl) * GetSkillPower("zeus_return"))) {
            GivePlayerItem(client, "weapon_taser");
            PrintToChat(client, "[\x04RPG\x01] Вы мгновенно вернули заряд Zeus!");
        }
    }
}

public Action Specials_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker)) return Plugin_Continue;
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return Plugin_Continue;

    char wpn[32]; GetClientWeapon(attacker, wpn, sizeof(wpn));

    // --- НАВЫКИ СКАУТА ---
    if (StrEqual(wpn, "weapon_ssg08")) {
        // Тяжелый скаут (Выбивает оружие)
        int heavyLvl = GetSkillLevel(attacker, "heavy_scout");
        if (heavyLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(heavyLvl) * GetSkillPower("heavy_scout"))) {
            int weapon = GetPlayerWeaponSlot(victim, CS_SLOT_PRIMARY);
            if (weapon != -1) CS_DropWeapon(victim, weapon, true, true);
            PrintToChat(attacker, "[\x04RPG\x01] Тяжелый выстрел выбил оружие врага!");
        }

        // Ядовитый скаут (Травит ядом)
        int poisLvl = GetSkillLevel(attacker, "poison_scout");
        if (poisLvl > 0) {
            DataPack pack;
            CreateDataTimer(3.0, Timer_PoisonHit, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            pack.WriteCell(GetClientUserId(victim));
            pack.WriteCell(GetClientUserId(attacker));
            pack.WriteCell(poisLvl);
            pack.WriteCell(0); // Счетчик тиков
            PrintToChat(victim, "[\x04RPG\x01] \x02Вы отравлены скаутом!");
        }
    }

    // --- НАВЫКИ ПИСТОЛЕТОВ ---
    if (IsPistolWeapon(wpn)) {
        // Огненный пистолет
        int fireLvl = GetSkillLevel(attacker, "fire_pistol");
        if (fireLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(fireLvl) * 0.2)) {
            IgniteEntity(victim, float(fireLvl) * GetSkillPower("fire_pistol"));
        }
        
        // Ледяной пистолет
        int iceLvl = GetSkillLevel(attacker, "ice_pistol");
        if (iceLvl > 0 && !g_bIsFrozen[victim]) {
            float freezeForce = (float(iceLvl) * GetSkillPower("ice_pistol")) - (float(GetSkillLevel(victim, "anti_ice_pistol")) * GetSkillPower("anti_ice_pistol"));
            if (freezeForce > 0.0) {
                SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", 0.3); // Сильное замедление
                CreateTimer(freezeForce * 0.1, Timer_UnfreezeSpecials, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }

    return Plugin_Continue;
}

// ------------------------------------------------------------------------------
// ГРАНАТЫ
// ------------------------------------------------------------------------------
public void Specials_Event_HEDetonate(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    float pos[3]; pos[0] = event.GetFloat("x"); pos[1] = event.GetFloat("y"); pos[2] = event.GetFloat("z");
    
    // Ледяная граната (Заморозка)
    int iceLvl = GetSkillLevel(attacker, "ice_nade");
    if (iceLvl > 0) {
        float freezeTime = float(iceLvl) * GetSkillPower("ice_nade");
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(attacker)) {
                float tPos[3]; GetClientAbsOrigin(i, tPos);
                if (GetVectorDistance(pos, tPos) <= 250.0) {
                    SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.1); 
                    CreateTimer(freezeTime, Timer_UnfreezeSpecials, GetClientUserId(i));
                }
            }
        }
    }

    // Огненная граната (Поджог)
    int fireLvl = GetSkillLevel(attacker, "fire_nade");
    if (fireLvl > 0) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(attacker)) {
                float tPos[3]; GetClientAbsOrigin(i, tPos);
                if (GetVectorDistance(pos, tPos) <= 250.0) {
                    IgniteEntity(i, float(fireLvl) * GetSkillPower("fire_nade"));
                }
            }
        }
    }
}

public void Specials_Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int smokeLvl = GetSkillLevel(attacker, "poison_smoke");
    if (smokeLvl > 0) {
        float pos[3]; pos[0] = event.GetFloat("x"); pos[1] = event.GetFloat("y"); pos[2] = event.GetFloat("z");
        
        DataPack pack;
        CreateDataTimer(5.0, Timer_PoisonSmokeArea, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(GetClientUserId(attacker));
        pack.WriteFloat(pos[0]); pack.WriteFloat(pos[1]); pack.WriteFloat(pos[2]);
        pack.WriteCell(3); // Дым висит около 15 секунд (3 тика по 5 сек)
        pack.WriteCell(smokeLvl);
    }
}

public void Specials_Event_DecoyStarted(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    if (!attacker || !IsClientInGame(attacker)) return;

    float pos[3]; pos[0] = event.GetFloat("x"); pos[1] = event.GetFloat("y"); pos[2] = event.GetFloat("z");
    
    // Телепорт на Decoy
    int tpLvl = GetSkillLevel(attacker, "tp_decoy");
    if (tpLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(tpLvl) * GetSkillPower("tp_decoy"))) {
        TeleportEntity(attacker, pos, NULL_VECTOR, NULL_VECTOR);
        PrintToChat(attacker, "[\x04RPG\x01] Вы переместились к ложной гранате!");
        return; // Если тпшнулись, клон уже не создаем
    }

    // Клон на месте Decoy
    int cloneLvl = GetSkillLevel(attacker, "clone_decoy");
    if (cloneLvl > 0) {
        int prop = CreateEntityByName("prop_dynamic_override");
        if (IsValidEntity(prop)) {
            char model[128]; GetClientModel(attacker, model, sizeof(model));
            SetEntityModel(prop, model);
            DispatchSpawn(prop);
            
            float ang[3]; GetClientEyeAngles(attacker, ang); ang[0] = 0.0;
            TeleportEntity(prop, pos, ang, NULL_VECTOR);
            
            // Удаляем клона через заданное время
            CreateTimer(float(cloneLvl) * GetSkillPower("clone_decoy"), Timer_RemoveClone, EntIndexToEntRef(prop));
        }
    }
}

// ------------------------------------------------------------------------------
// ТАЙМЕРЫ И ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ------------------------------------------------------------------------------
public Action Timer_UnfreezeSpecials(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) {
        // Возвращаем нормальную скорость с учетом базовых навыков
        float baseSpeed = 1.0 + (float(GetSkillLevel(client, "speed")) * GetSkillPower("speed") / 100.0);
        float finalSpeed = baseSpeed * (1.0 + (g_fItem_SpeedPct[client] / 100.0));
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", finalSpeed);
    }
    return Plugin_Stop;
}

public Action Timer_PoisonHit(Handle timer, DataPack pack) {
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    int attacker = GetClientOfUserId(pack.ReadCell());
    int level = pack.ReadCell();
    int ticks = pack.ReadCell();

    if (victim > 0 && IsClientInGame(victim) && IsPlayerAlive(victim)) {
        float finalDmg = float(level) * GetSkillPower("poison_scout");
        
        int antiLvl = GetSkillLevel(victim, "anti_poison_scout");
        float reduction = (float(antiLvl) * GetSkillPower("anti_poison_scout")) / 100.0;
        if (reduction > 1.0) reduction = 1.0;
        
        finalDmg *= (1.0 - reduction);
        SDKHooks_TakeDamage(victim, attacker, attacker, finalDmg, DMG_POISON);
        
        ticks++;
        if (ticks >= 2) return Plugin_Stop; 
        
        pack.Reset(); pack.ReadCell(); pack.ReadCell(); pack.ReadCell();
        pack.WriteCell(ticks);
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

public Action Timer_PoisonSmokeArea(Handle timer, DataPack pack) {
    pack.Reset();
    int attacker = GetClientOfUserId(pack.ReadCell());
    float pos[3]; pos[0] = pack.ReadFloat(); pos[1] = pack.ReadFloat(); pos[2] = pack.ReadFloat();
    int ticks = pack.ReadCell();
    int level = pack.ReadCell();

    if (ticks > 0) {
        float dmg = float(level) * GetSkillPower("poison_smoke");
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(attacker)) {
                float tPos[3]; GetClientAbsOrigin(i, tPos);
                if (GetVectorDistance(pos, tPos) <= 200.0) {
                    SDKHooks_TakeDamage(i, attacker, attacker, dmg, DMG_POISON);
                }
            }
        }
        
        ticks--;
        if (ticks <= 0) return Plugin_Stop;
        
        pack.Reset(); pack.ReadCell(); pack.ReadFloat(); pack.ReadFloat(); pack.ReadFloat();
        pack.WriteCell(ticks);
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

public Action Timer_RemoveClone(Handle timer, any entRef) {
    int ent = EntRefToEntIndex(entRef);
    if (ent > 0 && IsValidEntity(ent)) AcceptEntityInput(ent, "Kill");
    return Plugin_Stop;
}

bool IsPistolWeapon(const char[] weapon) {
    return (StrContains(weapon, "glock") != -1 || StrContains(weapon, "hkp2000") != -1 ||
            StrContains(weapon, "usp_silencer") != -1 || StrContains(weapon, "p250") != -1 ||
            StrContains(weapon, "tec9") != -1 || StrContains(weapon, "fiveseven") != -1 ||
            StrContains(weapon, "deagle") != -1 || StrContains(weapon, "elite") != -1 ||
            StrContains(weapon, "cz75a") != -1 || StrContains(weapon, "revolver") != -1);
}

bool HasWeaponSpecials(int client, const char[] weaponName) {
    int m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
    for (int i = 0; i < 128; i += 4) {
        int weapon = GetEntDataEnt2(client, m_hMyWeapons + i);
        if (weapon != -1 && IsValidEntity(weapon)) {
            char classname[32]; GetEntityClassname(weapon, classname, sizeof(classname));
            if (StrEqual(classname, weaponName)) return true;
        }
    }
    return false;
}