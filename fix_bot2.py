import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# I noticed earlier when checking the previous version that I didn't actually restore the python script to correctly modify the file from the current state (it was probably overwritten by `git checkout` earlier). Let's do the full complete write manually.

full_code = """#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

public Plugin myinfo = {
    name = "RPG Boss Thanos - Custom Raid Edition",
    author = "Skvirt (modified)",
    description = "Thanos Boss: Auto-spawn Bot, skills, ultimates, visuals.",
    version = "42.0"
};

Database g_dDatabase = null;
bool g_bBossActive = false;
int g_iBossClient = -1;
int g_iBossRarity = 0;

Handle g_hHudTimer = null;
Handle g_hRespawnTimer = null;
Handle g_hHudSync = null;
Handle g_hSkillTimer = null;
Handle g_hWarningTimer = null;

int g_iBossHP = 0;
int g_iBossMaxHP = 0;
float g_flBossEndTime = 0.0;
float g_flLastAttackTime = 0.0;

bool g_bPlayerParticipated[MAXPLAYERS + 1];
int g_iDamageCounter[MAXPLAYERS + 1];

int g_iNextSkill = -1;
int g_iWarningCount = 0;
int g_iTimeRewindCount = 0;
bool g_bSnapUsed = false;
bool g_bRageActive = false;
bool g_bFinalPhaseActive = false;
int g_iSoulStealKills = 0;

int g_iLaserModel = -1;
int g_iHaloModel = -1;
int g_iSmokeModel = -1;

char g_sResources[][] = { "iron_ore", "magic_crystal", "titan_heart", "star_shard" };
char g_sBossModel[] = "models/player/custom_player/kaesar2018/thanos/thanos.mdl";
char g_sBossName[] = "THANOS_BOSS";

public void OnPluginStart() {
    char error[255];
    g_dDatabase = SQL_Connect("rpg", true, error, sizeof(error));

    g_hHudSync = CreateHudSynchronizer();
    CreateTimer(60.0, Timer_CheckTime, _, TIMER_REPEAT);

    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);

    RegConsoleCmd("sm_boss_admin", Command_BossMenu);
    RegConsoleCmd("sm_boss_spawn", Command_BossMenu);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public void OnMapStart() {
    PrecacheModel(g_sBossModel, true);
    g_iLaserModel = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iHaloModel = PrecacheModel("materials/sprites/halo.vmt");
    g_iSmokeModel = PrecacheModel("materials/effects/smokematerial.vmt");
}

public void OnMapEnd() {
    EndBossFight();
}

public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    g_iDamageCounter[client] = 0;
    g_bPlayerParticipated[client] = false;
}

public Action Timer_CheckTime(Handle timer) {
    if (!g_bBossActive) {
        char sHour[4], sMinute[4];
        FormatTime(sHour, sizeof(sHour), "%H", GetTime());
        FormatTime(sMinute, sizeof(sMinute), "%M", GetTime());
        if (StringToInt(sHour) % 3 == 0 && StringToInt(sMinute) == 0) {
            SpawnBossBot(GetRandomInt(0, 3));
        }
    }
    return Plugin_Continue;
}

public Action Command_BossMenu(int client, int args) {
    if (client < 1 || !IsClientInGame(client)) return Plugin_Handled;
    int flags = GetUserFlagBits(client);
    if (!(flags & ADMFLAG_ROOT) && !(flags & ADMFLAG_CUSTOM3)) return Plugin_Handled;

    Menu menu = new Menu(MenuHandler_Boss);
    menu.SetTitle("Управление Боссом");
    if (!g_bBossActive) {
        menu.AddItem("0", "Спавн: Обычный");
        menu.AddItem("1", "Спавн: Редкий");
        menu.AddItem("2", "Спавн: Легендарный");
        menu.AddItem("3", "Спавн: МИФИЧЕСКИЙ");
    } else {
        menu.AddItem("kill", "Убить босса");
    }
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int MenuHandler_Boss(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[32]; menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "kill")) {
            if (g_bBossActive && g_iBossClient != -1) SDKHooks_TakeDamage(g_iBossClient, client, client, 99999999.0, DMG_CLUB);
        } else {
            SpawnBossBot(StringToInt(info));
        }
    } else if (action == MenuAction_End) delete menu;
    return 0;
}

void SpawnBossBot(int rarity) {
    if (g_bBossActive) return;

    g_bBossActive = true;
    g_iBossRarity = rarity;
    g_iBossClient = -1;

    int bot = CreateFakeClient(g_sBossName);
    if (bot > 0) {
        CreateTimer(0.5, Timer_SetupBot, GetClientUserId(bot));
    } else {
        g_bBossActive = false;
        PrintToServer("[RPG Boss] Ошибка CreateFakeClient()!");
    }
}

public Action Timer_SetupBot(Handle timer, any userid) {
    int bot = GetClientOfUserId(userid);
    if (bot > 0 && IsClientInGame(bot)) {
        CS_SwitchTeam(bot, CS_TEAM_T);
        CS_RespawnPlayer(bot);
        g_iBossClient = bot;
        SetupBoss(bot);
    }
    return Plugin_Stop;
}

void SetupBoss(int client) {
    g_iBossHP = 50000 + (g_iBossRarity * 50000);
    g_iBossMaxHP = g_iBossHP;
    g_flBossEndTime = GetEngineTime() + 600.0;

    g_iTimeRewindCount = 0; g_bSnapUsed = false; g_bRageActive = false; g_bFinalPhaseActive = false; g_iSoulStealKills = 0;
    for (int i = 1; i <= MaxClients; i++) { g_bPlayerParticipated[i] = false; g_iDamageCounter[i] = 0; }

    SetEntityModel(client, g_sBossModel);
    SetEntityHealth(client, 99999999);
    StripAllWeapons(client);
    GivePlayerItem(client, "weapon_knife");

    g_hHudTimer = CreateTimer(1.0, Timer_UpdateHud, _, TIMER_REPEAT);
    g_hRespawnTimer = CreateTimer(3.0, Timer_RespawnCTs, _, TIMER_REPEAT);
    g_hSkillTimer = CreateTimer(15.0, Timer_PrepareSkill, _, TIMER_REPEAT);

    ServerCommand("mp_ignore_round_win_conditions 1");

    PrintToChatAll(" \\x04[RPG] \\x02БОСС ТАНОС ПОЯВИЛСЯ! У ВАС ЕСТЬ 10 МИНУТ!");
}

void StripAllWeapons(int client) {
    int weapon;
    for (int i = 0; i < 5; i++) {
        while ((weapon = GetPlayerWeaponSlot(client, i)) != -1) {
            RemovePlayerItem(client, weapon);
            AcceptEntityInput(weapon, "Kill");
        }
    }
}

public Action Timer_RespawnCTs(Handle timer) {
    if (!g_bBossActive) { g_hRespawnTimer = null; return Plugin_Stop; }
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT && !IsFakeClient(i)) CS_RespawnPlayer(i);
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (!g_bBossActive || client != g_iBossClient || !IsPlayerAlive(client)) return Plugin_Continue;

    float speedMult = 1.0;
    if (g_bRageActive) speedMult = 1.5;
    if (g_bFinalPhaseActive) speedMult = 2.0;
    SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", speedMult);

    if (g_bBossActive && g_iBossClient == client) {
        int target = GetNearestPlayer(client);
        if (target != -1) {
            float bPos[3], tPos[3];
            GetClientEyePosition(client, bPos);
            GetClientEyePosition(target, tPos);
            if (GetVectorDistance(bPos, tPos) < 100.0 && GetEngineTime() - g_flLastAttackTime >= 1.0) {
                float dmgValue = 500.0 + (g_iBossRarity * 200.0) + (g_iSoulStealKills * 50.0);
                if (g_bRageActive) dmgValue *= 1.5;
                SDKHooks_TakeDamage(target, client, client, dmgValue, DMG_CLUB);
                g_flLastAttackTime = GetEngineTime();
            }
        }
    }
    return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;
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
        damage = 99999999.0;
        return Plugin_Changed;
    } else {
        SetEntityHealth(victim, 99999999);
        return Plugin_Continue;
    }
}

void CheckUltimates() {
    float hpPct = float(g_iBossHP) / float(g_iBossMaxHP);
    if (hpPct <= 0.5 && !g_bSnapUsed) { g_bSnapUsed = true; Skill_Snap(); }
    if (hpPct <= 0.3 && !g_bRageActive) { g_bRageActive = true; PrintToChatAll(" \\x04[Танос] \\x02ЯРОСТЬ ТИТАНА! Урон и скорость увеличены!"); }
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
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            ClientCommand(i, "r_screenoverlay \\"effects/tp_eyefx/tpeye.vmt\\"");
            CreateTimer(10.0, Timer_RemoveOverlay, GetClientUserId(i));
        }
    }
}

public Action Timer_RemoveOverlay(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) ClientCommand(client, "r_screenoverlay \\"\\"");
    return Plugin_Stop;
}

void Skill_MindControl() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient && GetRandomInt(1, 2) == 1) {
            SetEntPropFloat(i, Prop_Send, "m_flFlashDuration", 5.0);
            SetEntPropFloat(i, Prop_Send, "m_flFlashMaxAlpha", 255.0);
        }
    }
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
    for(int i=0; i<5; i++) {
        int target = GetRandomPlayer();
        if (target != -1) {
            float pPos[3]; GetClientAbsOrigin(target, pPos);
            TE_SetupBeamRingPoint(pPos, 10.0, 200.0, g_iLaserModel, g_iHaloModel, 0, 10, 2.0, 10.0, 0.0, {255, 0, 0, 255}, 10, 0);
            TE_SendToAll();
        }
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (g_bBossActive && attacker == g_iBossClient) g_iSoulStealKills++;
    if (g_bBossActive && victim == g_iBossClient) {
        EndBossFight();
        for (int i = 1; i <= MaxClients; i++) { if (IsClientInGame(i) && g_bPlayerParticipated[i]) HandleRewards(i); }
    }
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_bBossActive && client == g_iBossClient) {
        StripAllWeapons(client); GivePlayerItem(client, "weapon_knife"); SetEntityModel(client, g_sBossModel);
    }
    return Plugin_Continue;
}

void EndBossFight() {
    g_bBossActive = false;

    if (g_iBossClient != -1 && IsClientInGame(g_iBossClient)) {
        KickClient(g_iBossClient, "Танос повержен");
    }
    g_iBossClient = -1;

    if (g_hHudTimer != null) { KillTimer(g_hHudTimer); g_hHudTimer = null; }
    if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
    if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }
    if (g_hWarningTimer != null) { KillTimer(g_hWarningTimer); g_hWarningTimer = null; }
    ServerCommand("mp_ignore_round_win_conditions 0");
    CS_TerminateRound(5.0, CSRoundEnd_CTWin);
}

void HandleRewards(int client) {
    if (client < 1 || IsFakeClient(client)) return;
    char sSteamID[32]; GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    int mult = g_iBossRarity + 1;
    char query[1024];
    Format(query, sizeof(query), "INSERT INTO rpg_materials (steamid, iron_ore, magic_crystal) VALUES ('%s', %d, %d) ON DUPLICATE KEY UPDATE iron_ore=iron_ore+%d, magic_crystal=magic_crystal+%d", sSteamID, 100*mult, 30*mult, 100*mult, 30*mult);
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);

    KeyValues kv = new KeyValues("RPG_Items");
    char path[PLATFORM_MAX_PATH]; BuildPath(Path_SM, path, sizeof(path), "configs/rpg_items.txt");
    if (!kv.ImportFromFile(path)) { delete kv; return; }

    if (kv.GotoFirstSubKey()) {
        char sItemId[16], sItemName[64];
        do {
            if (g_iBossRarity >= kv.GetNum("drop_from", 0) && GetRandomFloat(0.0, 100.0) <= kv.GetFloat("drop_chance", 0.0)) {
                kv.GetSectionName(sItemId, sizeof(sItemId)); kv.GetString("name", sItemName, sizeof(sItemName));
                Format(query, sizeof(query), "INSERT INTO rpg_inventory (steamid, item_id, is_equipped, slot_index) VALUES ('%s', %d, 0, 0)", sSteamID, StringToInt(sItemId));
                if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);
            }
        } while (kv.GotoNextKey());
    }
    delete kv; g_bPlayerParticipated[client] = false;
}

public Action Timer_UpdateHud(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsPlayerAlive(g_iBossClient)) { g_hHudTimer = null; return Plugin_Stop; }

    int timeLeft = RoundToCeil(g_flBossEndTime - GetEngineTime());
    if (timeLeft <= 0) { EndBossFight(); return Plugin_Stop; }

    char rName[32];
    switch(g_iBossRarity) { case 0: rName = "Обычный"; case 1: rName = "Редкий"; case 2: rName = "Легендарный"; case 3: rName = "МИФИЧЕСКИЙ"; }

    SetHudTextParams(0.02, 0.05, 0.6, 255, 255, 255, 255);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) ShowSyncHudText(i, g_hHudSync, "ТАНОС [%s]\\nХП: %d / %d\\nОсталось: %02d:%02d", rName, g_iBossHP, g_iBossMaxHP, timeLeft / 60, timeLeft % 60);
    }
    return Plugin_Continue;
}

int GetNearestPlayer(int bossEntity) {
    int nearest = -1; float minDist = 9999.0; float bPos[3]; GetClientAbsOrigin(bossEntity, bPos);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != bossEntity && !IsFakeClient(i)) {
            float pPos[3]; GetClientAbsOrigin(i, pPos);
            float d = GetVectorDistance(bPos, pPos);
            if (d < minDist) { minDist = d; nearest = i; }
        }
    }
    return nearest;
}

int GetRandomPlayer() {
    int[] players = new int[MaxClients]; int count = 0;
    for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && !IsFakeClient(i)) players[count++] = i;
    if (count > 0) return players[GetRandomInt(0, count - 1)];
    return -1;
}

void GiveRandomResource(int client) {
    char sSteamID[32]; GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    char resName[32]; strcopy(resName, sizeof(resName), g_sResources[GetRandomInt(0, sizeof(g_sResources) - 1)]);
    char query[512]; Format(query, sizeof(query), "INSERT INTO rpg_materials (steamid, %s) VALUES ('%s', 1) ON DUPLICATE KEY UPDATE %s = %s + 1", resName, sSteamID, resName, resName);
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);
}

public void SQL_Callback_Silent(Database db, DBResultSet results, const char[] error, any data) {}

float GetBossDropChance(int rarity) {
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rpg_boss_drops.txt");

    KeyValues kv = new KeyValues("BossDrops");
    if (!kv.ImportFromFile(path)) {
        delete kv;
        switch (rarity) {
            case 0: return 5.0;
            case 1: return 15.0;
            case 2: return 35.0;
            case 3: return 70.0;
        }
        return 1.0;
    }

    char key[16];
    Format(key, sizeof(key), "rarity_%d", rarity);
    float chance = kv.GetFloat(key, 1.0);
    delete kv;
    return chance;
}
"""

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(full_code)
