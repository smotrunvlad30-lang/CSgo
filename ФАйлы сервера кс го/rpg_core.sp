#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

// ==============================================================================
// ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ЯДРА И БАЗЫ ДАННЫХ
// ==============================================================================
Database g_DB = null;

int g_iMoney[MAXPLAYERS+1], g_iLevel[MAXPLAYERS+1], g_iExp[MAXPLAYERS+1];
bool g_bLoaded[MAXPLAYERS+1];
int g_iTickCount = 0;

// ==============================================================================
// ПЕРЕМЕННЫЕ НАВЫКОВ (RPG)
// ==============================================================================
int g_sHP[MAXPLAYERS+1], g_sHPReg[MAXPLAYERS+1], g_sHPRegStand[MAXPLAYERS+1], g_sHPStay[MAXPLAYERS+1], g_sVamp[MAXPLAYERS+1], g_sDmg[MAXPLAYERS+1];
int g_sCrit[MAXPLAYERS+1], g_sArmor[MAXPLAYERS+1], g_sArmorReg[MAXPLAYERS+1], g_sButcher[MAXPLAYERS+1], g_sRespawn[MAXPLAYERS+1];
int g_sArmDest[MAXPLAYERS+1], g_sArmPierc[MAXPLAYERS+1], g_sDeadly[MAXPLAYERS+1], g_sDevil[MAXPLAYERS+1], g_sSpeed[MAXPLAYERS+1];
int g_sAdren[MAXPLAYERS+1], g_sImpulse[MAXPLAYERS+1], g_sAtkSpd[MAXPLAYERS+1], g_sPistol[MAXPLAYERS+1], g_sGrav[MAXPLAYERS+1];
int g_sLongJmp[MAXPLAYERS+1], g_sClimber[MAXPLAYERS+1], g_sHeavyJmp[MAXPLAYERS+1], g_sAgility[MAXPLAYERS+1], g_sSwap[MAXPLAYERS+1];
int g_sRat[MAXPLAYERS+1], g_sInvis[MAXPLAYERS+1], g_sNinja[MAXPLAYERS+1], g_sSpy[MAXPLAYERS+1], g_sSpikes[MAXPLAYERS+1];
int g_sSlowAura[MAXPLAYERS+1], g_sShrapnel[MAXPLAYERS+1], g_sKnockback[MAXPLAYERS+1], g_sDisarm[MAXPLAYERS+1], g_sParalyze[MAXPLAYERS+1];
int g_sSilence[MAXPLAYERS+1], g_sXp1[MAXPLAYERS+1], g_sXp2[MAXPLAYERS+1], g_sXp3[MAXPLAYERS+1], g_sFarmDuals[MAXPLAYERS+1];
int g_sFarmKnife[MAXPLAYERS+1], g_sWiseKnife[MAXPLAYERS+1], g_sFarmMag7[MAXPLAYERS+1], g_sFarmZeus[MAXPLAYERS+1], g_sWiseZeus[MAXPLAYERS+1];
int g_sZeusReturn[MAXPLAYERS+1], g_sZeusRegen[MAXPLAYERS+1], g_sIceKnife[MAXPLAYERS+1], g_sAntiIceKnife[MAXPLAYERS+1], g_sIceNade[MAXPLAYERS+1];
int g_sFireNade[MAXPLAYERS+1], g_sPoisonSmoke[MAXPLAYERS+1], g_sNadeRegen[MAXPLAYERS+1], g_sCloneDecoy[MAXPLAYERS+1], g_sHeavyScout[MAXPLAYERS+1];
int g_sPoisonScout[MAXPLAYERS+1], g_sAntiPoisonScout[MAXPLAYERS+1], g_sSniperSense[MAXPLAYERS+1], g_sFirePistol[MAXPLAYERS+1], g_sIcePistol[MAXPLAYERS+1];
int g_sAntiIcePistol[MAXPLAYERS+1], g_sKamikaze[MAXPLAYERS+1], g_sThanos[MAXPLAYERS+1], g_sPhoenix[MAXPLAYERS+1], g_sHolyTouch[MAXPLAYERS+1];
int g_sMirror[MAXPLAYERS+1];

#define MAX_SKILLS 100
char g_sSkillKey[MAX_SKILLS][32];
float g_fSkillPower[MAX_SKILLS];
int g_iTotalSkills = 0;

// ==============================================================================
// ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ПРЕДМЕТОВ ИЗ АДМИНКИ
// ==============================================================================
float g_fItem_HpFlat[MAXPLAYERS+1], g_fItem_HpPct[MAXPLAYERS+1];
float g_fItem_DmgFlat[MAXPLAYERS+1], g_fItem_DmgPct[MAXPLAYERS+1];
float g_fItem_ArmorFlat[MAXPLAYERS+1], g_fItem_ArmorPct[MAXPLAYERS+1];
float g_fItem_SpeedPct[MAXPLAYERS+1], g_fItem_GravityFlat[MAXPLAYERS+1];
float g_fItem_CritChance[MAXPLAYERS+1], g_fItem_Vampirism[MAXPLAYERS+1];
float g_fItem_LowHpBonus[MAXPLAYERS+1], g_fItem_FullHpBonus[MAXPLAYERS+1];
float g_fItem_BonusCredits[MAXPLAYERS+1], g_fItem_BonusXp[MAXPLAYERS+1];
float g_fItem_DropChance[MAXPLAYERS+1], g_fItem_RareDropChance[MAXPLAYERS+1];
float g_fItem_ReflectChance[MAXPLAYERS+1], g_fItem_SlowChance[MAXPLAYERS+1];
float g_fItem_HealOnKill[MAXPLAYERS+1], g_fItem_HealOnHit[MAXPLAYERS+1];
float g_fItem_HpRegen[MAXPLAYERS+1], g_fItem_PushChance[MAXPLAYERS+1];
float g_fItem_StunChance[MAXPLAYERS+1], g_fItem_BleedChance[MAXPLAYERS+1];
float g_fItem_BurnChance[MAXPLAYERS+1], g_fItem_JumpPower[MAXPLAYERS+1];
float g_fItem_DmgReduction[MAXPLAYERS+1], g_fItem_BlockChance[MAXPLAYERS+1];
float g_fItem_DodgeChance[MAXPLAYERS+1], g_fItem_HsBonus[MAXPLAYERS+1];
float g_fItem_BackstabBonus[MAXPLAYERS+1];

float g_flNextItemRegenTick[MAXPLAYERS + 1];

// ==============================================================================
// ПОДКЛЮЧЕНИЕ МОДУЛЕЙ
// ==============================================================================
int GetMaxHealth(int client) { return GetEntProp(client, Prop_Data, "m_iMaxHealth"); }
void HealPlayer(int client, int amount) {
    if (amount <= 0 || !IsPlayerAlive(client)) return;
    int max = GetMaxHealth(client);
    int cur = GetClientHealth(client);
    if (cur < max) {
        int newhp = cur + amount;
        SetEntityHealth(client, (newhp > max) ? max : newhp);
    }
}

#include "rpg_skills_health.sp"
#include "rpg_radar.sp"
#include "rpg_skills_attack.sp"
#include "rpg_skills_movement.sp"
#include "rpg_skills_auras.sp"
#include "rpg_skills_farm.sp"
#include "rpg_skills_all.sp"
#include "rpg_svip.sp"
#include "rpg_items_core.sp" 
#include "rpg_boss.sp" 

public Plugin myinfo = { 
    name = "RPG System: CORE (Web Version)", 
    author = "Skvirt", 
    version = "5.0.3" 
};

// ==============================================================================
// ИНИЦИАЛИЗАЦИЯ
// ==============================================================================
public void OnPluginStart() {
    RegConsoleCmd("sm_rpg", Cmd_RPGMenu);
    
    HookEvent("player_spawn", Event_Spawn);
    HookEvent("player_death", Event_Death);
    HookEvent("round_start", Event_RoundStart); 
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("round_end", Event_RoundEnd);
    
    // === СНЯТИЕ СЕРВЕРНЫХ ЛИМИТОВ ФИЗИКИ (ФИКС ТРЯСКИ) ===
    Handle cvar;
    if ((cvar = FindConVar("sv_maxvelocity")) != null) SetConVarInt(cvar, 15000); // Убираем лимит скорости полета
    if ((cvar = FindConVar("sv_maxspeed")) != null) SetConVarInt(cvar, 15000);    // Убираем лимит скорости бега
    if ((cvar = FindConVar("sv_airaccelerate")) != null) SetConVarInt(cvar, 2000); // Улучшаем стрейф в воздухе
    if ((cvar = FindConVar("sv_enablebunnyhopping")) != null) SetConVarInt(cvar, 1); // Включаем распрыжку
    // =====================================================

    Database.Connect(OnDBConnect, "rpg");
    LoadSkillsConfig(); 
    
    Health_OnPluginStart();
    Items_OnPluginStart(); 
    Attack_OnPluginStart(); 
    Auras_OnPluginStart();
    AllSkills_OnPluginStart();
    SVip_OnPluginStart();
    
    CreateTimer(1.0, Timer_GlobalLoop, _, TIMER_REPEAT);
}

public void OnMapStart() {
    LoadSkillsConfig();
    
    // Дублируем снятие лимитов при смене карты (на всякий случай, если server.cfg их сбросит)
    Handle cvar;
    if ((cvar = FindConVar("sv_maxvelocity")) != null) SetConVarInt(cvar, 15000);
    if ((cvar = FindConVar("sv_maxspeed")) != null) SetConVarInt(cvar, 15000);
    if ((cvar = FindConVar("sv_airaccelerate")) != null) SetConVarInt(cvar, 2000);
    if ((cvar = FindConVar("sv_enablebunnyhopping")) != null) SetConVarInt(cvar, 1);
}

public void OnClientPutInServer(int client) {
    g_bLoaded[client] = false; 
    Health_OnClientPutInServer(client);
    Attack_OnClientPutInServer(client); 
    AllSkills_OnClientPutInServer(client);
    SVip_OnClientPutInServer(client);
    SDKHook(client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if(!IsClientInGame(client) || !IsPlayerAlive(client)) return Plugin_Continue;

    SVip_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
    Movement_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
    
    return Plugin_Continue;
}

public void Event_WeaponSwitchPost(int client, int weapon) {
    Movement_OnWeaponSwitchPost(client, weapon);
}

// ==============================================================================
// ЛОГИКА ИНТЕРФЕЙСА И ДАННЫХ
// ==============================================================================
public Action Cmd_RPGMenu(int client, int args) {
    if (client > 0 && IsClientInGame(client)) {
        PrintToChat(client, " \x04[RPG] \x01Вся прокачка теперь на нашем сайте!");
        PrintToChat(client, " \x04[RPG] \x01Заходи: \x04giveawayland.online");
    }
    return Plugin_Handled;
}

void LoadSkillsConfig() {
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rpg_skills.txt");
    KeyValues kv = new KeyValues("RPG_Skills");
    if (!kv.ImportFromFile(path)) { LogError("Не удалось загрузить %s", path); delete kv; return; }

    g_iTotalSkills = 0;
    if (kv.GotoFirstSubKey()) {
        do {
            if (g_iTotalSkills >= MAX_SKILLS) break;
            kv.GetSectionName(g_sSkillKey[g_iTotalSkills], sizeof(g_sSkillKey[]));
            g_fSkillPower[g_iTotalSkills] = kv.GetFloat("power", 1.0);
            g_iTotalSkills++;
        } while (kv.GotoNextKey());
    }
    delete kv;
}

float GetSkillPower(const char[] key) {
    for (int i = 0; i < g_iTotalSkills; i++) {
        if (StrEqual(key, g_sSkillKey[i])) return g_fSkillPower[i];
    }
    return 1.0;
}

int GetSkillLevel(int client, const char[] key) {
    if (StrEqual(key, "hp_lvl")) return g_sHP[client];
    else if (StrEqual(key, "hp_reg_lvl")) return g_sHPReg[client];
    else if (StrEqual(key, "hp_reg_stand_lvl")) return g_sHPRegStand[client];
    else if (StrEqual(key, "vamp_lvl")) return g_sVamp[client];
    else if (StrEqual(key, "dmg_lvl")) return g_sDmg[client];
    else if (StrEqual(key, "crit_lvl")) return g_sCrit[client];
    else if (StrEqual(key, "armor_lvl")) return g_sArmor[client];
    else if (StrEqual(key, "armor_reg_lvl")) return g_sArmorReg[client];
    else if (StrEqual(key, "butcher_lvl")) return g_sButcher[client];
    else if (StrEqual(key, "respawn_lvl")) return g_sRespawn[client];
    else if (StrEqual(key, "arm_dest")) return g_sArmDest[client];
    else if (StrEqual(key, "arm_pierc")) return g_sArmPierc[client];
    else if (StrEqual(key, "deadly")) return g_sDeadly[client];
    else if (StrEqual(key, "devil")) return g_sDevil[client];
    else if (StrEqual(key, "speed")) return g_sSpeed[client];
    else if (StrEqual(key, "adren")) return g_sAdren[client];
    else if (StrEqual(key, "impulse")) return g_sImpulse[client];
    else if (StrEqual(key, "atk_spd")) return g_sAtkSpd[client];
    else if (StrEqual(key, "pistol")) return g_sPistol[client];
    else if (StrEqual(key, "grav")) return g_sGrav[client];
    else if (StrEqual(key, "long_jmp")) return g_sLongJmp[client];
    else if (StrEqual(key, "climber")) return g_sClimber[client];
    else if (StrEqual(key, "heavy_jmp")) return g_sHeavyJmp[client];
    else if (StrEqual(key, "agility")) return g_sAgility[client];
    else if (StrEqual(key, "swap")) return g_sSwap[client];
    else if (StrEqual(key, "rat")) return g_sRat[client];
    else if (StrEqual(key, "invis")) return g_sInvis[client];
    else if (StrEqual(key, "ninja")) return g_sNinja[client];
    else if (StrEqual(key, "spy")) return g_sSpy[client];
    else if (StrEqual(key, "spikes")) return g_sSpikes[client];
    else if (StrEqual(key, "slow_aura")) return g_sSlowAura[client];
    else if (StrEqual(key, "shrapnel")) return g_sShrapnel[client];
    else if (StrEqual(key, "knockback")) return g_sKnockback[client];
    else if (StrEqual(key, "disarm")) return g_sDisarm[client];
    else if (StrEqual(key, "paralyze")) return g_sParalyze[client];
    else if (StrEqual(key, "silence")) return g_sSilence[client];
    else if (StrEqual(key, "xp_1")) return g_sXp1[client];
    else if (StrEqual(key, "xp_2")) return g_sXp2[client];
    else if (StrEqual(key, "xp_3")) return g_sXp3[client];
    else if (StrEqual(key, "farm_duals")) return g_sFarmDuals[client];
    else if (StrEqual(key, "farm_knife")) return g_sFarmKnife[client];
    else if (StrEqual(key, "wise_knife")) return g_sWiseKnife[client];
    else if (StrEqual(key, "farm_mag7")) return g_sFarmMag7[client];
    else if (StrEqual(key, "farm_zeus")) return g_sFarmZeus[client];
    else if (StrEqual(key, "wise_zeus")) return g_sWiseZeus[client];
    else if (StrEqual(key, "zeus_return")) return g_sZeusReturn[client];
    else if (StrEqual(key, "zeus_regen")) return g_sZeusRegen[client];
    else if (StrEqual(key, "ice_knife")) return g_sIceKnife[client];
    else if (StrEqual(key, "anti_ice_knife")) return g_sAntiIceKnife[client];
    else if (StrEqual(key, "ice_nade")) return g_sIceNade[client];
    else if (StrEqual(key, "fire_nade")) return g_sFireNade[client];
    else if (StrEqual(key, "poison_smoke")) return g_sPoisonSmoke[client];
    else if (StrEqual(key, "nade_regen")) return g_sNadeRegen[client];
    else if (StrEqual(key, "clone_decoy")) return g_sCloneDecoy[client];
    else if (StrEqual(key, "heavy_scout")) return g_sHeavyScout[client];
    else if (StrEqual(key, "poison_scout")) return g_sPoisonScout[client];
    else if (StrEqual(key, "anti_poison_scout")) return g_sAntiPoisonScout[client];
    else if (StrEqual(key, "sniper_sense")) return g_sSniperSense[client];
    else if (StrEqual(key, "fire_pistol")) return g_sFirePistol[client];
    else if (StrEqual(key, "ice_pistol")) return g_sIcePistol[client];
    else if (StrEqual(key, "anti_ice_pistol")) return g_sAntiIcePistol[client];
    else if (StrEqual(key, "kamikaze")) return g_sKamikaze[client];
    else if (StrEqual(key, "thanos")) return g_sThanos[client];
    else if (StrEqual(key, "phoenix")) return g_sPhoenix[client];
    else if (StrEqual(key, "holy_touch")) return g_sHolyTouch[client];
    else if (StrEqual(key, "mirror")) return g_sMirror[client];
    return 0;
}

// ==============================================================================
// ИГРОВЫЕ СОБЫТИЯ И ОПЫТ
// ==============================================================================
public Action Timer_GlobalLoop(Handle timer) {
    g_iTickCount++;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && g_bLoaded[i]) {
            int nextXP = 200 + (g_iLevel[i] * 50);
            SetHudTextParams(-1.0, 0.90, 1.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
            ShowHudText(i, -1, "「 LEVEL: %d | XP: %d/%d 」\n「 КРЕДИТЫ: %d$ 」", g_iLevel[i], g_iExp[i], nextXP, g_iMoney[i]);
            
            Health_OnTick(i, g_iTickCount);
            Radar_OnTick(i);
            Auras_OnTick(i); 
            AllSkills_OnTick(i); 
            Items_OnTick(i); 
        }
    }
    return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    SVip_Event_RoundStart(event, name, dontBroadcast);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            LoadPlayerData(i);
        }
    }
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && IsClientInGame(client)) {
        CreateTimer(0.1, Timer_ApplySpawnSkills, GetClientUserId(client));
    }
}

public Action Timer_ApplySpawnSkills(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) {
        Items_OnPlayerSpawn(client); 
        Health_OnPlayerSpawn(client); 
        Movement_OnPlayerSpawn(client); 
        AllSkills_OnPlayerSpawn(client);
        SVip_OnPlayerSpawn(client);
    }
    return Plugin_Stop;
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int assister = GetClientOfUserId(event.GetInt("assister"));
    bool headshot = event.GetBool("headshot");
    
    char wpn[32]; event.GetString("weapon", wpn, sizeof(wpn));
    float deathPos[3];
    
    if (victim > 0 && victim <= MaxClients && IsClientInGame(victim)) {
        GetClientAbsOrigin(victim, deathPos);
    }

    SVip_Event_Death(event, name, dontBroadcast);
    Health_OnPlayerDeath(victim, attacker, wpn, deathPos);
    AllSkills_OnPlayerDeath(victim, attacker);
    Items_OnPlayerDeath(victim, attacker);

    if (assister > 0 && assister != victim) AddXP(assister, 2000, "Помощь");
    
    if (attacker > 0 && attacker != victim) {
        Farm_OnPlayerDeath(attacker, victim, wpn);

        int xp = headshot ? 2000 : 500;
        char reason[32]; Format(reason, sizeof(reason), headshot ? "Хедшот" : "Убийство");
        
        if (g_iLevel[victim] - g_iLevel[attacker] >= 5) {
            int diff = g_iLevel[victim] - g_iLevel[attacker];
            xp += (diff * 40);
        }
        AddXP(attacker, xp, reason);
    }
}

public void Event_BombPlanted(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    AddXP(client, 1000, "Установка бомбы");
}

public void Event_BombDefused(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    AddXP(client, 5000, "Разминирование");
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    int winner = event.GetInt("winner");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && g_bLoaded[i] && GetClientTeam(i) >= 2) {
            if (GetClientTeam(i) == winner) AddXP(i, 1500, "Победа в раунде");
            else AddXP(i, 1500, "Поражение в раунде");
        }
    }
}

// ==============================================================================
// СИСТЕМА ОПЫТА
// ==============================================================================
float GetXPMultiplier(int client) {
    float mult = 1.0 + (g_fItem_BonusXp[client] / 100.0); 
    if (g_sXp1[client] > 0) mult *= 2.0;
    if (g_sXp2[client] > 0) mult *= 2.0;
    if (g_sXp3[client] > 0) mult *= 2.0;
    return mult;
}

void AddXP(int client, int amount, const char[] reason) {
    if (!client || !IsClientInGame(client)) return;
    int playersCount = 0;
    for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && GetClientTeam(i) >= 2) playersCount++;
    
    float finalMult = GetXPMultiplier(client);
    if (playersCount < 4) finalMult *= 0.1; 
    
    int f_amount = RoundToFloor(float(amount) * finalMult);
    if (f_amount <= 0) f_amount = 1;
    
    g_iExp[client] += f_amount;
    PrintToChat(client, "[\x04RPG\x01] +%d XP (%s)", f_amount, reason);
    CheckLevelUp(client);
}

void CheckLevelUp(int client) {
    bool leveledUp = false;
    int nextXP = 200 + (g_iLevel[client] * 50);
    while (g_iExp[client] >= nextXP) {
        g_iExp[client] -= nextXP; 
        g_iLevel[client]++;
        nextXP = 200 + (g_iLevel[client] * 50); 
        
        int reward = 5000;
        if (CheckCommandAccess(client, "", ADMFLAG_CUSTOM1, true)) reward *= 2; 
        
        g_iMoney[client] += reward;
        leveledUp = true;
    }
    if (leveledUp) {
        PrintToChat(client, "[\x04RPG\x01] LVL UP! Уровень: \x04%d\x01", g_iLevel[client]);
        SavePlayerProgress(client); 
    }
}

// ==============================================================================
// БАЗА ДАННЫХ (БЕЗОПАСНАЯ СИНХРОНИЗАЦИЯ)
// ==============================================================================
public void OnDBConnect(Database db, const char[] error, any data) {
    if (db == null) { LogError("DB Error: %s", error); return; }
    g_DB = db;
}

public void OnClientPostAdminCheck(int client) {
    LoadPlayerData(client);
}

void LoadPlayerData(int client) {
    g_bLoaded[client] = false; 
    if (IsFakeClient(client) || g_DB == null) return;
    
    char auth[32], q1[1024], q2[1024], finalQ[4096]; 
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    
    Format(q1, sizeof(q1), "SELECT money, lvl, xp, hp_lvl, hp_reg_lvl, hp_stay_lvl, vamp_lvl, dmg_lvl, crit_lvl, armor_lvl, armor_reg_lvl, butcher_lvl, respawn_lvl, arm_dest, arm_pierc, deadly, devil, speed, adren, impulse, atk_spd, pistol, grav, long_jmp, climber, heavy_jmp, agility, swap, rat, invis, ninja, spy, spikes, slow_aura, shrapnel, knockback, disarm, paralyze, silence, xp_1, xp_2, xp_3, farm_duals, farm_knife, wise_knife, farm_mag7, farm_zeus, wise_zeus ");
    Format(q2, sizeof(q2), ", zeus_return, zeus_regen, ice_knife, anti_ice_knife, ice_nade, fire_nade, poison_smoke, nade_regen, clone_decoy, heavy_scout, poison_scout, anti_poison_scout, sniper_sense, fire_pistol, ice_pistol, anti_ice_pistol, kamikaze, thanos, phoenix, holy_touch, mirror, hp_reg_stand_lvl FROM rpg_system WHERE steamid='%s'", auth);
    
    Format(finalQ, sizeof(finalQ), "%s%s", q1, q2); 
    g_DB.Query(OnLoaded, finalQ, GetClientUserId(client));
}

public void OnLoaded(Database db, DBResultSet res, const char[] err, any userid) {
    int c = GetClientOfUserId(userid); if (!c || res == null) return;
    
    if (res.FetchRow()) {
        g_iMoney[c] = res.FetchInt(0); g_iLevel[c] = res.FetchInt(1); g_iExp[c] = res.FetchInt(2);
        g_sHP[c] = res.FetchInt(3); g_sHPReg[c] = res.FetchInt(4); g_sHPStay[c] = res.FetchInt(5); g_sVamp[c] = res.FetchInt(6); g_sDmg[c] = res.FetchInt(7); 
        g_sCrit[c] = res.FetchInt(8); g_sArmor[c] = res.FetchInt(9); g_sArmorReg[c] = res.FetchInt(10); g_sButcher[c] = res.FetchInt(11); g_sRespawn[c] = res.FetchInt(12); 
        g_sArmDest[c] = res.FetchInt(13); g_sArmPierc[c] = res.FetchInt(14); g_sDeadly[c] = res.FetchInt(15); g_sDevil[c] = res.FetchInt(16); g_sSpeed[c] = res.FetchInt(17); 
        g_sAdren[c] = res.FetchInt(18); g_sImpulse[c] = res.FetchInt(19); g_sAtkSpd[c] = res.FetchInt(20); g_sPistol[c] = res.FetchInt(21); g_sGrav[c] = res.FetchInt(22); 
        g_sLongJmp[c] = res.FetchInt(23); g_sClimber[c] = res.FetchInt(24); g_sHeavyJmp[c] = res.FetchInt(25); g_sAgility[c] = res.FetchInt(26); g_sSwap[c] = res.FetchInt(27); 
        g_sRat[c] = res.FetchInt(28); g_sInvis[c] = res.FetchInt(29); g_sNinja[c] = res.FetchInt(30); g_sSpy[c] = res.FetchInt(31); g_sSpikes[c] = res.FetchInt(32); 
        g_sSlowAura[c] = res.FetchInt(33); g_sShrapnel[c] = res.FetchInt(34); g_sKnockback[c] = res.FetchInt(35); g_sDisarm[c] = res.FetchInt(36); g_sParalyze[c] = res.FetchInt(37); 
        g_sSilence[c] = res.FetchInt(38); g_sXp1[c] = res.FetchInt(39); g_sXp2[c] = res.FetchInt(40); g_sXp3[c] = res.FetchInt(41); g_sFarmDuals[c] = res.FetchInt(42); 
        g_sFarmKnife[c] = res.FetchInt(43); g_sWiseKnife[c] = res.FetchInt(44); g_sFarmMag7[c] = res.FetchInt(45); g_sFarmZeus[c] = res.FetchInt(46); g_sWiseZeus[c] = res.FetchInt(47); 
        g_sZeusReturn[c] = res.FetchInt(48); g_sZeusRegen[c] = res.FetchInt(49); g_sIceKnife[c] = res.FetchInt(50); g_sAntiIceKnife[c] = res.FetchInt(51); g_sIceNade[c] = res.FetchInt(52); 
        g_sFireNade[c] = res.FetchInt(53); g_sPoisonSmoke[c] = res.FetchInt(54); g_sNadeRegen[c] = res.FetchInt(55); g_sCloneDecoy[c] = res.FetchInt(56); g_sHeavyScout[c] = res.FetchInt(57); 
        g_sPoisonScout[c] = res.FetchInt(58); g_sAntiPoisonScout[c] = res.FetchInt(59); g_sSniperSense[c] = res.FetchInt(60); g_sFirePistol[c] = res.FetchInt(61); g_sIcePistol[c] = res.FetchInt(62); 
        g_sAntiIcePistol[c] = res.FetchInt(63); g_sKamikaze[c] = res.FetchInt(64); g_sThanos[c] = res.FetchInt(65); g_sPhoenix[c] = res.FetchInt(66); g_sHolyTouch[c] = res.FetchInt(67); 
        g_sMirror[c] = res.FetchInt(68); g_sHPRegStand[c] = res.FetchInt(69);
        g_bLoaded[c] = true;
    } else {
        // Создаем нового игрока
        char auth[32], name[32], insQ[1024]; 
        GetClientAuthId(c, AuthId_Steam2, auth, sizeof(auth)); 
        GetClientName(c, name, sizeof(name));
        
       // Теперь новые игроки будут стартовать с 0, либо с тем, что ты пропишешь в БД
Format(insQ, sizeof(insQ), "INSERT IGNORE INTO rpg_system (steamid, nickname, lvl, xp, money) VALUES ('%s', '%s', 1, 0, 0)", auth, name);

        // === ВЫДАЧА СТАРТОВЫХ БОТИНОК ===
        int startBootID = 20; // Твой ID обычных ботинок
        
        char bootQ[512];
        Format(bootQ, sizeof(bootQ), "INSERT INTO rpg_inventory (steamid, item_id, is_equipped, slot_index, upgrade_speed, upgrade_grav) VALUES ('%s', %d, 0, 0, 0, 0)", auth, startBootID);
        g_DB.Query(SQL_IgnoreError, bootQ);
        // ================================

        LoadPlayerData(c); // Загружаем заново
    }
}

public void OnClientDisconnect(int c) {
    if (g_bLoaded[c]) {
        SavePlayerProgress(c);
    }
}

void SavePlayerProgress(int client) {
    if (g_DB != null && g_bLoaded[client]) {
        char auth[32]; GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
        char q[512];
        Format(q, sizeof(q), "UPDATE rpg_system SET money=%d, lvl=%d, xp=%d WHERE steamid='%s'", g_iMoney[client], g_iLevel[client], g_iExp[client], auth);
        g_DB.Query(SQL_IgnoreError, q);
    }
}

public void SQL_IgnoreError(Database db, DBResultSet res, const char[] err, any data) { 
    if (err[0]) LogError("SQL Error: %s", err); 
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("RPG_GetItemDropChance", Native_GetItemDropChance);
    return APLRes_Success;
}

public any Native_GetItemDropChance(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return g_fItem_DropChance[client];
}
