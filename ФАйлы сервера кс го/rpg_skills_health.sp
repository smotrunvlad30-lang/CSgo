// ==============================================================================
// МОДУЛЬ 1: ЗДОРОВЬЕ, БРОНЯ И ВОЗРОЖДЕНИЕ (rpg_skills_health.sp)
// ==============================================================================

#include <sourcemod>
#include <sdktools>

int g_iRespawnsUsed[MAXPLAYERS + 1];
bool g_bSpawnAtBase[MAXPLAYERS + 1];
float g_fRoundStartTime;

// КЕШИРОВАНИЕ МАКСИМУМОВ 
int g_iMaxArmorCache[MAXPLAYERS + 1];
int g_iMaxHpCache[MAXPLAYERS + 1];

void Health_OnPluginStart() {
    RegConsoleCmd("sm_rpgspawn", Cmd_ToggleSpawnMode, "Переключить место возрождения");
    HookEvent("round_start", Health_Event_RoundStart);
}

public void Health_Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    g_fRoundStartTime = GetGameTime();
}

public Action Cmd_ToggleSpawnMode(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        g_bSpawnAtBase[client] = !g_bSpawnAtBase[client];
        PrintToChat(client, "[\x04RPG\x01] Место возрождения: \x04%s\x01", g_bSpawnAtBase[client] ? "БАЗА" : "МЕСТО СМЕРТИ");
    }
    return Plugin_Handled;
}

void Health_OnClientPutInServer(int client) {
    g_iRespawnsUsed[client] = 0;
    g_bSpawnAtBase[client] = false;
    
    // По умолчанию 0 брони, как мы и задумали
    g_iMaxArmorCache[client] = 0; 
    g_iMaxHpCache[client] = 100;
}

void Health_ApplyStatsFromItems(int client) {
    if (!IsPlayerAlive(client)) return;

    // --- 1. РАСЧЕТ ЗДОРОВЬЯ ---
    int hpLvl = GetSkillLevel(client, "hp_lvl");
    float hpPower = GetSkillPower("hp_lvl");
    if (hpPower <= 0.0) hpPower = 20.0;
    
    float baseHp = 100.0 + (float(hpLvl) * hpPower);
    float finalHp = (baseHp + g_fItem_HpFlat[client]) * (1.0 + (g_fItem_HpPct[client] / 100.0));
    g_iMaxHpCache[client] = RoundToFloor(finalHp);

    // --- 2. РАСЧЕТ БРОНИ ---
    int armLvl = GetSkillLevel(client, "armor_lvl");
    float armPower = GetSkillPower("armor_lvl");
    if (armPower <= 0.0) armPower = 10.0;
    
    // Базовая броня 0. Считается только прокачка и экипировка.
    float baseArmor = (float(armLvl) * armPower);
    float finalArmor = (baseArmor + g_fItem_ArmorFlat[client]) * (1.0 + (g_fItem_ArmorPct[client] / 100.0));
    g_iMaxArmorCache[client] = RoundToFloor(finalArmor);

    // --- ПРИМЕНЕНИЕ СТАТОВ ---
    SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iMaxHpCache[client]);
    SetEntityHealth(client, g_iMaxHpCache[client]); 
    
    SetEntProp(client, Prop_Send, "m_ArmorValue", g_iMaxArmorCache[client]);
    
    // Если броня больше 0, выдаем шлем. Если 0 — забираем.
    if (g_iMaxArmorCache[client] > 0) {
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
    } else {
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
    }
}

void Health_OnPlayerSpawn(int client) {
    if (!IsPlayerAlive(client)) return;
    
    // Благодаря настройке mp_free_armor 0 нам больше не нужны задержки.
    // Выдаем броню и ХП мгновенно при спавне.
    Health_ApplyStatsFromItems(client);
}

void Health_OnTick(int client, int tickCount) {
    if (!IsPlayerAlive(client)) return;

    int currentHp = GetClientHealth(client);
    int maxHp = g_iMaxHpCache[client];
    if (maxHp < 100) maxHp = 100; 
    
    // Регенерация стоя
    int standLvl = GetSkillLevel(client, "hp_reg_stand_lvl");
    if (standLvl > 0 && currentHp < maxHp) {
        float vel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
        if (vel[0] == 0.0 && vel[1] == 0.0 && vel[2] == 0.0) { 
            float standPwr = GetSkillPower("hp_reg_stand_lvl");
            if (standPwr <= 0.0) standPwr = 5.0;

            int heal = RoundToFloor(float(standLvl) * standPwr);
            if (heal < 1) heal = 1;
            HealPlayer(client, heal);
            currentHp = GetClientHealth(client); 
        }
    }

    if (tickCount % 2 == 0) {
        // Регенерация ХП
        int hprLvl = GetSkillLevel(client, "hp_reg_lvl");
        if (hprLvl > 0 && currentHp < maxHp) {
            float regPwr = GetSkillPower("hp_reg_lvl");
            if (regPwr <= 0.0) regPwr = 3.0;

            int heal = RoundToFloor(float(hprLvl) * regPwr);
            if (heal < 1) heal = 1;
            HealPlayer(client, heal);
        }

        // Регенерация брони
        int armrLvl = GetSkillLevel(client, "armor_reg_lvl");
        if (armrLvl > 0) {
            int currentArm = GetEntProp(client, Prop_Send, "m_ArmorValue");
            int maxArm = g_iMaxArmorCache[client];
            
            // Восстанавливаем броню только в том случае, если максимум больше нуля
            if (maxArm > 0 && currentArm < maxArm) {
                float armRegPwr = GetSkillPower("armor_reg_lvl");
                if (armRegPwr <= 0.0) armRegPwr = 3.0;

                int armHeal = RoundToFloor(float(armrLvl) * armRegPwr);
                if (armHeal < 1) armHeal = 1;
                
                int nextArm = currentArm + armHeal;
                SetEntProp(client, Prop_Send, "m_ArmorValue", (nextArm >= maxArm) ? maxArm : nextArm);
            }
        }
    }
}

void Health_OnPlayerDeath(int victim, int attacker, const char[] weapon, float deathPos[3]) {
    
    if (attacker > 0 && attacker != victim && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
        int butchLvl = GetSkillLevel(attacker, "butcher_lvl");
        if (butchLvl > 0 && (StrContains(weapon, "knife") != -1 || StrContains(weapon, "bayonet") != -1)) {
            float butchPwr = GetSkillPower("butcher_lvl");
            if (butchPwr <= 0.0) butchPwr = 10.0;

            int heal = RoundToFloor(float(butchLvl) * butchPwr);
            HealPlayer(attacker, heal); 
            PrintToChat(attacker, "[\x04RPG\x01] Мясник: \x04+%d HP\x01", heal);
        }
    }

    if (victim > 0 && IsClientInGame(victim)) {
        if (GetGameTime() - g_fRoundStartTime <= 30.0) {
            PrintToChat(victim, "[\x04RPG\x01] Бесплатное возрождение (до 30 сек)!");
            CreateTimer(2.0, Timer_RespawnPlayerBase, GetClientUserId(victim));
            return;
        }

        int respLvl = GetSkillLevel(victim, "respawn_lvl");
        if (respLvl > 0 && g_iRespawnsUsed[victim] < 5) {
            float respPwr = GetSkillPower("respawn_lvl");
            if (respPwr <= 0.0) respPwr = 1.0;

            float chance = float(respLvl) * respPwr; 
            if (GetRandomFloat(0.0, 100.0) <= chance) {
                g_iRespawnsUsed[victim]++;
                PrintToChat(victim, "[\x04RPG\x01] Навык возрождения сработал! (%d/5)", g_iRespawnsUsed[victim]);
                
                DataPack pack;
                CreateDataTimer(2.0, Timer_RespawnPlayerRPG, pack);
                pack.WriteCell(GetClientUserId(victim));
                pack.WriteFloat(deathPos[0]); pack.WriteFloat(deathPos[1]); pack.WriteFloat(deathPos[2]);
            }
        }
    }
}

public Action Timer_RespawnPlayerBase(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && !IsPlayerAlive(client)) CS_RespawnPlayer(client);
    return Plugin_Stop;
}

public Action Timer_RespawnPlayerRPG(Handle timer, DataPack pack) {
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    float pos[3]; pos[0] = pack.ReadFloat(); pos[1] = pack.ReadFloat(); pos[2] = pack.ReadFloat();

    if (client && IsClientInGame(client) && !IsPlayerAlive(client)) {
        CS_RespawnPlayer(client);
        if (!g_bSpawnAtBase[client]) TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
    }
    return Plugin_Stop;
}