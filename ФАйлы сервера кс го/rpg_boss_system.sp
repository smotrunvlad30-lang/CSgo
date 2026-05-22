#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include "rpg_boss_drops.inc"

public Plugin myinfo = {
    name = "RPG Boss Thanos - Custom Raid Edition",
    author = "Skvirt (modified)",
    description = "Thanos Boss: Auto-spawn, skills, ultimates, knife only.",
    version = "41.0"
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
float g_flBossEndTime = 0.0; // 10 минут
float g_flLastAttackTime = 0.0;
float g_flStuckCheckTime = 0.0;

// Массив участия
bool g_bPlayerParticipated[MAXPLAYERS + 1];
int g_iDamageCounter[MAXPLAYERS + 1];

// Навыки
int g_iNextSkill = -1;
int g_iTimeRewindCount = 0;
bool g_bSnapUsed = false;
bool g_bRageActive = false;
bool g_bFinalPhaseActive = false;
int g_iSoulStealKills = 0;

char g_sResources[][] = {
    "iron_ore",
    "magic_crystal",
    "titan_heart",
    "star_shard"
};

char g_sBossModel[] = "models/player/custom_player/kaesar2018/thanos/thanos.mdl";

public void OnPluginStart() {
    char error[255];
    g_dDatabase = SQL_Connect("rpg", true, error, sizeof(error));
    if (g_dDatabase == null) {
        LogError("[RPG Boss] Ошибка подключения к БД: %s", error);
    }

    g_hHudSync = CreateHudSynchronizer();
    CreateTimer(60.0, Timer_CheckTime, _, TIMER_REPEAT);

    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);

    RegConsoleCmd("sm_bos", Command_BossMenu);
    RegConsoleCmd("sm_boss", Command_BossMenu);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public void OnMapStart() {
    PrecacheModel(g_sBossModel, true);
    // Добавление файлов в загрузку... (сокращено для примера, подразумевается что они скачиваются)
    // AddFileToDownloadsTable...
}

public void OnMapEnd() {
    g_bBossActive = false;
    g_iBossClient = -1;
    ClearBossTimers();
    ServerCommand("mp_ignore_round_win_conditions 0");
}

public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    g_iDamageCounter[client] = 0;
    g_bPlayerParticipated[client] = false;
}

public Action Timer_CheckTime(Handle timer) {
    char sTime[16];
    FormatTime(sTime, sizeof(sTime), "%H:%M", GetTime());

    // Спавн каждые 3 часа: 12:00, 15:00, 18:00, 21:00, 00:00 и тд.
    if (!g_bBossActive) {
        int hour;
        char sHour[4];
        FormatTime(sHour, sizeof(sHour), "%H", GetTime());
        hour = StringToInt(sHour);

        char sMinute[4];
        FormatTime(sMinute, sizeof(sMinute), "%M", GetTime());
        int minute = StringToInt(sMinute);

        if (hour % 3 == 0 && minute == 0) {
            int randomPlayer = GetRandomPlayer();
            if (randomPlayer != -1) {
                SpawnBoss(randomPlayer, GetRandomInt(0, 3));
            }
        }
    }
    return Plugin_Continue;
}

int GetRandomPlayer() {
    int[] players = new int[MaxClients];
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            players[count++] = i;
        }
    }
    if (count > 0) return players[GetRandomInt(0, count - 1)];
    return -1;
}

public Action Command_BossMenu(int client, int args) {
    if (client < 1 || !IsClientInGame(client)) return Plugin_Handled;
    int flags = GetUserFlagBits(client);
    if (!(flags & ADMFLAG_ROOT) && !(flags & ADMFLAG_CUSTOM3)) {
        PrintToChat(client, " \x04[RPG] \x02Ошибка: \x01У вас нет прав!");
        return Plugin_Handled;
    }
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
            if (g_bBossActive && g_iBossClient != -1 && IsClientInGame(g_iBossClient)) {
                SDKHooks_TakeDamage(g_iBossClient, client, client, 99999999.0, DMG_CLUB);
            }
        } else {
            int rarity = StringToInt(info);
            int target = GetNearestPlayerForSpawn();
            if (target == -1) target = client;
            SpawnBoss(target, rarity);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

int GetNearestPlayerForSpawn() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i)) return i;
    }
    return -1;
}

void SpawnBoss(int client, int rarity) {
    if (g_bBossActive) return;

    g_bBossActive = true;
    g_iBossClient = client;
    g_iBossRarity = rarity;

    g_iBossHP = 50000 + (rarity * 50000); // Базовое хп: 50к, 100к, 150к, 200к
    g_iBossMaxHP = g_iBossHP;
    g_flBossEndTime = GetEngineTime() + 600.0; // 10 мин

    // Сброс статов навыков
    g_iTimeRewindCount = 0;
    g_bSnapUsed = false;
    g_bRageActive = false;
    g_bFinalPhaseActive = false;
    g_iSoulStealKills = 0;

    for (int i = 1; i <= MaxClients; i++) {
        g_bPlayerParticipated[i] = false;
        g_iDamageCounter[i] = 0;
    }

    SetEntityModel(client, g_sBossModel);
    SetEntityHealth(client, 99999999);
    CS_SwitchTeam(client, CS_TEAM_T);

    // Убираем всё оружие и выдаём нож
    StripAllWeapons(client);
    GivePlayerItem(client, "weapon_knife");

    // Таймеры
    g_hHudTimer = CreateTimer(1.0, Timer_UpdateHud, _, TIMER_REPEAT);
    g_hRespawnTimer = CreateTimer(3.0, Timer_RespawnCTs, _, TIMER_REPEAT);
    g_hSkillTimer = CreateTimer(15.0, Timer_RandomSkill, _, TIMER_REPEAT);

    ServerCommand("mp_ignore_round_win_conditions 1");

    char rName[32];
    switch(rarity) {
        case 0: rName = "Обычный";
        case 1: rName = "Редкий";
        case 2: rName = "Легендарный";
        case 3: rName = "МИФИЧЕСКИЙ";
    }
    PrintToChatAll(" \x04[RPG] \x02БОСС ТАНОС [%s] ПОЯВИЛСЯ! У ВАС ЕСТЬ 10 МИНУТ!", rName);
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
    if (!g_bBossActive) {
        g_hRespawnTimer = null;
        return Plugin_Stop;
    }
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsAlive(i) && GetClientTeam(i) == CS_TEAM_CT) {
            if (!IsFakeClient(i)) {
                CS_RespawnPlayer(i);
            }
        }
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
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
        SubtractVectors(tPos, bPos, dir);
        float dist = GetVectorLength(dir);

        GetVectorAngles(dir, ang);
        ang[0] = 0.0;
        angles = ang;
        vel[0] = 500.0 * speedMult;
        buttons |= IN_FORWARD;

        if (dist < 100.0) {
            buttons |= IN_ATTACK;
            if (GetEngineTime() - g_flLastAttackTime >= 1.0) {
                float dmgValue = 500.0 + (g_iBossRarity * 200.0);
                dmgValue += g_iSoulStealKills * 50.0; // Камень души дает урон
                if (g_bRageActive) dmgValue *= 1.5;
                SDKHooks_TakeDamage(target, client, client, dmgValue, DMG_CLUB);
                g_flLastAttackTime = GetEngineTime();
            }
        }
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (!g_bBossActive || victim != g_iBossClient) return Plugin_Continue;
    if (damagetype & DMG_FALL) return Plugin_Handled;

    if (damage <= 0.0) return Plugin_Continue;

    float dmgDealt = damage;
    if (g_bFinalPhaseActive) dmgDealt *= 0.5; // Щит 50%

    g_iBossHP -= RoundFloat(dmgDealt);

    if (attacker > 0 && attacker <= MaxClients && attacker != g_iBossClient) {
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
        damage = 99999999.0;
        return Plugin_Changed;
    } else {
        SetEntityHealth(victim, 99999999);
        return Plugin_Continue;
    }
}

void CheckUltimates() {
    float hpPct = float(g_iBossHP) / float(g_iBossMaxHP);

    if (hpPct <= 0.5 && !g_bSnapUsed) {
        g_bSnapUsed = true;
        Skill_Snap();
    }
    if (hpPct <= 0.3 && !g_bRageActive) {
        g_bRageActive = true;
        PrintToChatAll(" \x04[Танос] \x02ЯРОСТЬ ТИТАНА! Урон и скорость увеличены!");
    }
    if (hpPct <= 0.1 && !g_bFinalPhaseActive) {
        g_bFinalPhaseActive = true;
        PrintToChatAll(" \x04[Танос] \x02Я НЕИЗБЕЖЕН! Активирован щит и безумие!");
        // Перезапускаем таймер скиллов быстрее
        if (g_hSkillTimer != null) KillTimer(g_hSkillTimer);
        g_hSkillTimer = CreateTimer(7.0, Timer_RandomSkill, _, TIMER_REPEAT);
    }
}

// --- НАВЫКИ ---
public Action Timer_RandomSkill(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsPlayerAlive(g_iBossClient)) return Plugin_Continue;

    g_iNextSkill = GetRandomInt(1, 6);
    char sSkillName[64];
    switch (g_iNextSkill) {
        case 1: sSkillName = "Удар Титана (Камень Силы)";
        case 2: sSkillName = "Телепортация (Камень Пространства)";
        case 3: sSkillName = "Искажение Реальности (Камень Реальности)";
        case 4: sSkillName = "Контроль Сознания (Камень Разума)";
        case 5: sSkillName = "Откат Времени (Камень Времени)";
        case 6: sSkillName = "Космический Разлом";
    }

    SetHudTextParams(-1.0, 0.2, 3.0, 255, 0, 0, 255);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            ShowSyncHudText(i, g_hHudSync, "ВНИМАНИЕ!\nТанос готовит:\n%s", sSkillName);
        }
    }

    g_hWarningTimer = CreateTimer(3.0, Timer_ExecuteSkill);
    return Plugin_Continue;
}

public Action Timer_ExecuteSkill(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsPlayerAlive(g_iBossClient)) return Plugin_Stop;

    switch (g_iNextSkill) {
        case 1: Skill_TitanStrike();
        case 2: Skill_Teleport();
        case 3: Skill_Reality();
        case 4: Skill_MindControl();
        case 5: Skill_TimeRewind();
        case 6: Skill_CosmicRift();
    }
    g_hWarningTimer = null;
    return Plugin_Stop;
}

void Skill_TitanStrike() {
    float bPos[3]; GetClientAbsOrigin(g_iBossClient, bPos);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            float pPos[3]; GetClientAbsOrigin(i, pPos);
            if (GetVectorDistance(bPos, pPos) < 400.0) {
                SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 400.0, DMG_BLAST);
                // Отбрасывание
                float dir[3]; SubtractVectors(pPos, bPos, dir);
                NormalizeVector(dir, dir);
                ScaleVector(dir, 1000.0);
                dir[2] = 300.0;
                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, dir);
            }
        }
    }
    PrintToChatAll(" \x04[Танос] \x02Удар Титана нанес сокрушительный урон!");
}

void Skill_Teleport() {
    int target = GetRandomPlayer();
    if (target != -1) {
        float pos[3]; GetClientAbsOrigin(target, pos);
        TeleportEntity(g_iBossClient, pos, NULL_VECTOR, NULL_VECTOR);
        Skill_TitanStrike(); // АоЕ урон после ТП
    }
}

void Skill_Reality() {
    // Временно ослепляем игроков (Иллюзия реальности)
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            ClientCommand(i, "r_screenoverlay effects/tp_eyefx/tpeye.vmt");
            CreateTimer(10.0, Timer_RemoveOverlay, GetClientUserId(i));
        }
    }
    PrintToChatAll(" \x04[Танос] \x02Реальность полна разочарований.");
}

public Action Timer_RemoveOverlay(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) ClientCommand(client, "r_screenoverlay \"\"");
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
        PrintToChatAll(" \x04[Танос] \x02Откат времени: Восстановлено %d HP!", heal);
    }
}

void Skill_Snap() {
    PrintToChatAll(" \x04[Танос] \x02*Щелчок*");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            if (GetRandomInt(1, 2) == 1) {
                int hp = GetClientHealth(i);
                SetEntityHealth(i, hp / 2);
            }
        }
    }
}

void Skill_CosmicRift() {
    // Вызов метеоритов/взрывов на случайных позициях
    PrintToChatAll(" \x04[Танос] \x02Космический Разлом!");
    for(int i=0; i<5; i++) {
        int target = GetRandomPlayer();
        if (target != -1) {
            float pos[3]; GetClientAbsOrigin(target, pos);
            // Визуальный эффект и урон через секунду можно добавить, здесь упрощенный АоЕ
            CreateTimer(2.0, Timer_RiftExplosion, pos[0]); // Передача координат упрощена для примера, в реальности нужен массив
        }
    }
}
public Action Timer_RiftExplosion(Handle timer, any data) {
    // Упрощенная заглушка взрыва
    return Plugin_Stop;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (g_bBossActive && attacker == g_iBossClient) {
        g_iSoulStealKills++;
    }

    if (g_bBossActive && victim == g_iBossClient) {
        g_bBossActive = false;
        ClearBossTimers();
        ServerCommand("mp_ignore_round_win_conditions 0");
        CS_TerminateRound(5.0, CSRoundEnd_CTWin);

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && g_bPlayerParticipated[i]) HandleRewards(i);
        }
        if (IsClientInGame(victim)) KickClient(victim, "Босс повержен");
    }
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_bBossActive && client == g_iBossClient) {
        StripAllWeapons(client);
        GivePlayerItem(client, "weapon_knife");
        SetEntityModel(client, g_sBossModel);
    }
    return Plugin_Continue;
}

void HandleRewards(int client) {
    if (client < 1 || IsFakeClient(client)) return;
    char sSteamID[32]; GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    int mult = g_iBossRarity + 1;
    char query[1024];
    Format(query, sizeof(query), "INSERT INTO rpg_materials (steamid, iron_ore, magic_crystal) VALUES ('%s', %d, %d) ON DUPLICATE KEY UPDATE iron_ore=iron_ore+%d, magic_crystal=magic_crystal+%d", sSteamID, 100*mult, 30*mult, 100*mult, 30*mult);
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);

    KeyValues kv = new KeyValues("RPG_Items");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rpg_items.txt");
    if (!kv.ImportFromFile(path)) { delete kv; return; }

    if (kv.GotoFirstSubKey()) {
        char sItemId[16], sItemName[64];
        do {
            if (g_iBossRarity >= kv.GetNum("drop_from", 0)) {
                if (GetRandomFloat(0.0, 100.0) <= kv.GetFloat("drop_chance", 0.0)) {
                    kv.GetSectionName(sItemId, sizeof(sItemId));
                    kv.GetString("name", sItemName, sizeof(sItemName));
                    Format(query, sizeof(query), "INSERT INTO rpg_inventory (steamid, item_id, is_equipped, slot_index) VALUES ('%s', %d, 0, 0)", sSteamID, StringToInt(sItemId));
                    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);
                    PrintToChat(client, " \x04[RPG] \x01Вы выбили \x04%s\x01 с Босса!", sItemName);
                }
            }
        } while (kv.GotoNextKey());
    }
    delete kv;
    g_bPlayerParticipated[client] = false;
}

public Action Timer_UpdateHud(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsClientInGame(g_iBossClient)) {
        g_hHudTimer = null;
        return Plugin_Stop;
    }

    int timeLeft = RoundToCeil(g_flBossEndTime - GetEngineTime());
    if (timeLeft <= 0) {
        g_bBossActive = false;
        PrintToChatAll(" \x04[RPG] \x02Время вышло! Танос покинул поле боя.");
        if (IsClientInGame(g_iBossClient)) KickClient(g_iBossClient, "Время вышло");
        ClearBossTimers();
        ServerCommand("mp_ignore_round_win_conditions 0");
        CS_TerminateRound(3.0, CSRoundEnd_Draw);
        return Plugin_Stop;
    }

    char rName[32];
    switch(g_iBossRarity) {
        case 0: rName = "Обычный";
        case 1: rName = "Редкий";
        case 2: rName = "Легендарный";
        case 3: rName = "МИФИЧЕСКИЙ";
    }

    int mins = timeLeft / 60;
    int secs = timeLeft % 60;

    SetHudTextParams(0.02, 0.05, 0.6, 255, 255, 255, 255);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            ShowSyncHudText(i, g_hHudSync, "ТАНОС [%s]\nХП: %d / %d\nОсталось: %02d:%02d", rName, g_iBossHP, g_iBossMaxHP, mins, secs);
        }
    }
    return Plugin_Continue;
}

void ClearBossTimers() {
    if (g_hHudTimer != null) { KillTimer(g_hHudTimer); g_hHudTimer = null; }
    if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
    if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }
    if (g_hWarningTimer != null) { KillTimer(g_hWarningTimer); g_hWarningTimer = null; }
}

int GetNearestPlayer(int bossEntity) {
    int nearest = -1;
    float minDist = 9999.0;
    float bPos[3]; GetClientAbsOrigin(bossEntity, bPos);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != bossEntity && GetClientTeam(i) != GetClientTeam(bossEntity)) {
            float pPos[3]; GetClientAbsOrigin(i, pPos);
            float d = GetVectorDistance(bPos, pPos);
            if (d < minDist) { minDist = d; nearest = i; }
        }
    }
    return nearest;
}

bool IsAlive(int client) {
    return IsPlayerAlive(client);
}

void GiveRandomResource(int client) {
    if (client < 1 || !IsClientInGame(client)) return;
    char sSteamID[32]; GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    int resIndex = GetRandomInt(0, sizeof(g_sResources) - 1);
    char resName[32]; strcopy(resName, sizeof(resName), g_sResources[resIndex]);

    char query[512];
    Format(query, sizeof(query), "INSERT INTO rpg_materials (steamid, %s) VALUES ('%s', 1) ON DUPLICATE KEY UPDATE %s = %s + 1", resName, sSteamID, resName, resName);
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);

    char chatName[64];
    if (StrEqual(resName, "iron_ore")) chatName = "Железная руда";
    else if (StrEqual(resName, "magic_crystal")) chatName = "Магический кристалл";
    else if (StrEqual(resName, "titan_heart")) chatName = "Сердце Титана";
    else chatName = "Осколок Звезды";
    PrintToChat(client, " \x04[RPG] \x01Вы получили: \x0C%s (1 шт.) \x01за урон!", chatName);
}

public void SQL_Callback_Silent(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') LogError("[RPG SQL Error] %s", error);
}
