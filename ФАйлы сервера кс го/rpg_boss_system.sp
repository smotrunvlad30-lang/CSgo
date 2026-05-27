#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

public Plugin myinfo = {
    name = "RPG Boss Thanos - Raid Edition",
    author = "Skvirt",
    description = "Thanos Boss: 10 min raid, CT team only, infinite respawns",
    version = "40.0"
};

Database g_dDatabase = null;
bool g_bBossActive = false;
int g_iBossClient = -1;
int g_iBossRarity = 0;

Handle g_hHudTimer = null;
Handle g_hRespawnTimer = null;
Handle g_hHudSync = null;

Handle g_hSkillTimer = null;
int g_iNextSkill = -1;
bool g_bSnapUsed = false;
bool g_bPhase30 = false;
bool g_bPhase10 = false;


int g_iBossHP = 0;
int g_iBossMaxHP = 0;
float g_flLastAttackTime = 0.0;
float g_flStuckCheckTime = 0.0;
float g_flBossEndTime = 0.0; // Время, когда босс исчезнет (10 минут)

// Массив для отслеживания участия игроков в бою
bool g_bPlayerParticipated[MAXPLAYERS + 1];
int g_iDamageCounter[MAXPLAYERS + 1];

native float RPG_GetItemDropChance(int client);

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

    RegConsoleCmd("sm_bosik", Command_BossMenu);
    //RegConsoleCmd("sm_boss", Command_BossMenu);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    g_iDamageCounter[client] = 0;
    g_bPlayerParticipated[client] = false;
}

public void OnMapStart() {
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.phy");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos_arms.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos_arms.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kaesar2018/thanos/thanos_arms.vvd");

    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_body_d.vmt");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_body_d.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_body_n.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_gauntlet_d.vmt");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_gauntlet_d.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_gauntlet_n.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_head_d.vmt");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_head_d.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_head_n.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_helmet_d.vmt");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_helmet_d.vtf");
    AddFileToDownloadsTable("materials/models/player/kaesar2018/thanos/t_m_lrg_jim_helmet_n.vtf");

    if (FileExists(g_sBossModel, true)) {
        PrecacheModel(g_sBossModel, true);
    }
}

public void OnMapEnd() {
    g_bBossActive = false;
    g_iBossClient = -1;
    if (g_hHudTimer != null) { KillTimer(g_hHudTimer); g_hHudTimer = null; }
    if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
        if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }

    // Возвращаем обычные условия раунда, если карта сменилась во время босса
    ServerCommand("mp_ignore_round_win_conditions 0");
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
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "kill")) {
            if (g_bBossActive && g_iBossClient != -1 && IsClientInGame(g_iBossClient)) {
                g_iBossHP = 0;
                SDKHooks_TakeDamage(g_iBossClient, client, client, 99999999.0, DMG_GENERIC);
            }
        } else {
            PrepareBossSpawn(StringToInt(info));
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

public Action Timer_CheckTime(Handle timer) {
    char sTime[16];
    FormatTime(sTime, sizeof(sTime), "%H:%M");
    if (StrEqual(sTime, "00:00") || StrEqual(sTime, "03:00") || StrEqual(sTime, "06:00") || StrEqual(sTime, "09:00") || StrEqual(sTime, "12:00") || StrEqual(sTime, "15:00") || StrEqual(sTime, "18:00") || StrEqual(sTime, "21:00")) {
        PrepareBossSpawn(-1);
    }
    return Plugin_Continue;
}

void PrepareBossSpawn(int forcedRarity) {
    if (g_bBossActive) return;
    g_iBossRarity = (forcedRarity == -1) ? GetRandomInt(0, 3) : forcedRarity;
    int bot = CreateFakeClient("ТАНОС");
    if (bot > 0) {
        CreateTimer(0.2, Timer_SetupBot, GetClientUserId(bot));
    }
}

public Action Timer_SetupBot(Handle timer, any userid) {
    int bot = GetClientOfUserId(userid);
    if (bot > 0 && IsClientInGame(bot)) {
        ChangeClientTeam(bot, CS_TEAM_T);
        CS_RespawnPlayer(bot);
        SpawnThanosBot(bot);
    }
    return Plugin_Stop;
}

void SpawnThanosBot(int bot) {
    g_bBossActive = true;
    g_iBossClient = bot;
    g_flLastAttackTime = GetEngineTime();
    g_flStuckCheckTime = GetEngineTime();

    // БОСС ИСЧЕЗНЕТ РОВНО ЧЕРЕЗ 10 МИНУТ (600 СЕКУНД)
    g_flBossEndTime = GetEngineTime() + 600.0;

    // Отключаем обычное завершение раунда (по времени карты)
    ServerCommand("mp_ignore_round_win_conditions 1");

    int hp;
    switch(g_iBossRarity) {
        case 0: hp = 500000;
        case 1: hp = 1500000;
        case 2: hp = 3000000;
        case 3: hp = 8000000;
    }
    g_iBossHP = hp;
    g_iBossMaxHP = hp;
    for(int i = 1; i <= MaxClients; i++) {
        g_iDamageCounter[i] = 0;
        g_bPlayerParticipated[i] = false;
    }

    SetEntProp(bot, Prop_Data, "m_iMaxHealth", 99999999);
    SetEntityHealth(bot, 99999999);
    SetEntityModel(bot, g_sBossModel);
    SetEntProp(bot, Prop_Send, "m_bGunGameImmunity", 0);
    SetEntProp(bot, Prop_Data, "m_takedamage", 2);
    SetEntPropFloat(bot, Prop_Data, "m_flMaxspeed", 500.0);
    GivePlayerItem(bot, "weapon_knife");
    float spawnPos[3];
    if (FindHottestSpawnPoint(spawnPos)) TeleportEntity(bot, spawnPos, NULL_VECTOR, NULL_VECTOR);

    // ЗАПУСК ТАЙМЕРОВ (HUD + ВОЗРОЖДЕНИЕ)
    if (g_hHudTimer != null) KillTimer(g_hHudTimer);
    g_hHudTimer = CreateTimer(0.5, Timer_UpdateHud, _, TIMER_REPEAT);


    g_bSnapUsed = false;
    g_bPhase30 = false;
    g_bPhase10 = false;
    if (g_hSkillTimer != null) KillTimer(g_hSkillTimer);
    g_hSkillTimer = CreateTimer(15.0, Timer_CastSkill, _, TIMER_REPEAT);

    if (g_hRespawnTimer != null) KillTimer(g_hRespawnTimer);
    g_hRespawnTimer = CreateTimer(1.0, Timer_EnforceRules, _, TIMER_REPEAT);

    SDKHook(bot, SDKHook_OnTakeDamage, OnTakeDamage);

    PrintToChatAll(" \x04[RPG] \x02ВНИМАНИЕ! \x01ТАНОС ПРИБЫЛ!");
    PrintToChatAll(" \x04[RPG] \x01Вы переведены за Спецназ. У вас есть \x0210 МИНУТ \x01на его убийство!");
    PrintToChatAll(" \x04[RPG] \x01Бесконечные возрождения активированы.");
}

// ТАЙМЕР БЕСКОНЕЧНЫХ ВОЗРОЖДЕНИЙ И ПЕРЕВОДА ЗА CT
public Action Timer_EnforceRules(Handle timer) {
    if (!g_bBossActive) {
        g_hRespawnTimer = null;
        return Plugin_Stop;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            int team = GetClientTeam(i);

            // Если игрок за Террористов (Т), переводим его за Спецназ (СТ)
            if (team == CS_TEAM_T) {
                ChangeClientTeam(i, CS_TEAM_CT);
            }

            // Если игрок мертв и находится за Спецназ - возрождаем
            if (GetClientTeam(i) == CS_TEAM_CT && !IsPlayerAlive(i)) {
                CS_RespawnPlayer(i);
            }
        }
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (!g_bBossActive || client != g_iBossClient || !IsPlayerAlive(client)) return Plugin_Continue;
    SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", 1.0);
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

        float speedMod = 500.0;
        if (g_bPhase30) speedMod = 700.0;
        if (g_bPhase10) speedMod = 900.0;
        vel[0] = speedMod;

        buttons |= IN_FORWARD;

        float currentVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentVel);
        float realSpeed = SquareRoot(currentVel[0]*currentVel[0] + currentVel[1]*currentVel[1]);
        if (realSpeed < 15.0 && dist > 150.0) {
            if (GetEngineTime() - g_flStuckCheckTime > 5.0) {
                float tpPos[3];
                if (FindHottestSpawnPoint(tpPos)) {
                    TeleportEntity(client, tpPos, NULL_VECTOR, NULL_VECTOR);
                    g_flStuckCheckTime = GetEngineTime();
                }
            }
        } else {
            g_flStuckCheckTime = GetEngineTime();
        }

        if (dist < 100.0) {
            buttons |= IN_ATTACK;
            if (GetEngineTime() - g_flLastAttackTime >= 1.0) {
                int dmgValue = 500 + (g_iBossRarity * 200);
                SDKHooks_TakeDamage(target, client, client, float(dmgValue), DMG_CLUB);
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
    int dmgDealt = RoundFloat(damage);
    g_iBossHP -= dmgDealt;

    // Ультимейты по ХП
    float hpPct = float(g_iBossHP) / float(g_iBossMaxHP);

    // Щелчок (50%)
    if (hpPct <= 0.5 && !g_bSnapUsed) {
        g_bSnapUsed = true;
        PrintToChatAll(" \x02[ТАНОС] \x10Я сама неотвратимость... (ЩЕЛЧОК)");
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT) {
                if (GetRandomFloat(0.0, 100.0) <= 50.0) {
                    int curHp = GetClientHealth(i);
                    int newHp = curHp / 2;
                    if (newHp < 1) newHp = 1;
                    SetEntityHealth(i, newHp);
                    PrintToChat(i, " \x04[ТАНОС] \x01Вас задело щелчком! Половина здоровья уничтожена.");
                }
            }
        }
    }

    // Ярость Титана (30%)
    if (hpPct <= 0.3 && !g_bPhase30) {
        g_bPhase30 = true;
        PrintToChatAll(" \x02[ТАНОС] \x07ЯРОСТЬ ТИТАНА! Босс ускорен!");
    }

    // Финальная фаза (10%)
    if (hpPct <= 0.1 && !g_bPhase10) {
        g_bPhase10 = true;
        PrintToChatAll(" \x02[ТАНОС] \x04ФИНАЛЬНАЯ ФАЗА! Время скиллов уменьшено!");
        if (g_hSkillTimer != null) KillTimer(g_hSkillTimer);
        g_hSkillTimer = CreateTimer(8.0, Timer_CastSkill, _, TIMER_REPEAT);
    }


    if (attacker > 0 && attacker <= MaxClients && attacker != g_iBossClient) {
        g_bPlayerParticipated[attacker] = true;
        PrintCenterText(attacker, "УРОН ПО БОССУ: -%d | ОСТАЛОСЬ: %d", dmgDealt, g_iBossHP);

        g_iDamageCounter[attacker] += dmgDealt;
        if (g_iDamageCounter[attacker] >= 5000) {
            g_iDamageCounter[attacker] -= 5000;
            float dropChance = (g_iBossRarity == 0) ? 1.0 : (g_iBossRarity == 1) ? 5.0 : (g_iBossRarity == 2) ? 10.0 : 25.0;
            float itemBonus = RPG_GetItemDropChance(attacker);
            dropChance = dropChance + (dropChance * itemBonus / 100.0);
            if (GetRandomFloat(0.0, 100.0) <= dropChance) GiveRandomResource(attacker);
        }
    }


    if (g_iBossHP <= 0) {
        g_iBossHP = 0;
        damage = 99999999.0;
        return Plugin_Changed;
    } else {
        SetEntityHealth(victim, 99999999);
        return Plugin_Handled;
    }

}

void GiveRandomResource(int client) {
    if (client < 1 || !IsClientInGame(client)) return;
    char sSteamID[32]; GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    // Веса шансов: Обычная руда - самая частая, осколки - самая редкая
    // iron_ore: 60%, magic_crystal: 25%, titan_heart: 10%, star_shard: 5%
    float roll = GetRandomFloat(0.0, 100.0);
    char resName[32];
    char chatName[64];

    if (roll <= 60.0) {
        strcopy(resName, sizeof(resName), "iron_ore");
        chatName = "Железная руда";
    } else if (roll <= 85.0) {
        strcopy(resName, sizeof(resName), "magic_crystal");
        chatName = "Магический кристалл";
    } else if (roll <= 95.0) {
        strcopy(resName, sizeof(resName), "titan_heart");
        chatName = "Сердце Титана";
    } else {
        strcopy(resName, sizeof(resName), "star_shard");
        chatName = "Осколок Звезды";
    }

    char query[512];
    Format(query, sizeof(query), "INSERT INTO rpg_materials (steamid, %s) VALUES ('%s', 1) ON DUPLICATE KEY UPDATE %s = %s + 1", resName, sSteamID, resName, resName);
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);

    PrintToChat(client, " \x04[RPG] \x01Вы получили: \x0C%s (1 шт.) \x01за урон!", chatName);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));

    // ЕСЛИ УБИЛИ БОССА
    if (g_bBossActive && victim == g_iBossClient) {
        g_bBossActive = false;

        // Очищаем все таймеры
        if (g_hHudTimer != null) { KillTimer(g_hHudTimer); g_hHudTimer = null; }
        if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
        if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }

        // Завершаем раунд победой CT и включаем обычные условия раунда обратно
        ServerCommand("mp_ignore_round_win_conditions 0");
        CS_TerminateRound(5.0, CSRoundEnd_CTWin);

        // ВЫДАЕМ НАГРАДЫ ВСЕМ УЧАСТНИКАМ
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && g_bPlayerParticipated[i]) {
                HandleRewards(i);
            }
        }

        if (IsClientInGame(victim)) KickClient(victim, "Босс повержен");
    }
    return Plugin_Continue;
}

void HandleRewards(int client) {
    if (client < 1 || IsFakeClient(client)) return;
    char sSteamID[32]; GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    int mult = g_iBossRarity + 1;
    char query[1024];
    // Ресурсы за убийство
    Format(query, sizeof(query), "INSERT INTO rpg_materials (steamid, iron_ore, magic_crystal) VALUES ('%s', %d, %d) ON DUPLICATE KEY UPDATE iron_ore=iron_ore+%d, magic_crystal=magic_crystal+%d", sSteamID, 100*mult, 30*mult, 100*mult, 30*mult);
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_Silent, query);

    // Запрос на дроп предметов из БД
    Format(query, sizeof(query), "SELECT id, item_name, rarity FROM rpg_items_list");
    if (g_dDatabase != null) g_dDatabase.Query(SQL_Callback_BossDrops, query, GetClientUserId(client));

    g_bPlayerParticipated[client] = false;
}

public void SQL_Callback_BossDrops(Database db, DBResultSet results, const char[] error, any data) {
    int client = GetClientOfUserId(data);
    if (client == 0 || !IsClientInGame(client) || results == null || error[0] != '\0') return;

    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    float itemBonus = RPG_GetItemDropChance(client); // Бонус от надетых предметов в %

    while (results.FetchRow()) {
        int itemId = results.FetchInt(0);
        char sItemName[64];
        results.FetchString(1, sItemName, sizeof(sItemName));
        int itemRarity = results.FetchInt(2);

        float baseChance = 0.0;

        // Шансы выпадения в зависимости от уровня босса и редкости предмета
        if (g_iBossRarity == 0) {
            if (itemRarity == 1) baseChance = 25.0;
            else if (itemRarity == 2) baseChance = 15.0;
            else if (itemRarity == 3) baseChance = 5.0;
            else if (itemRarity == 4) baseChance = 1.0;
        } else if (g_iBossRarity == 1) {
            if (itemRarity == 1) baseChance = 40.0;
            else if (itemRarity == 2) baseChance = 20.0;
            else if (itemRarity == 3) baseChance = 10.0;
            else if (itemRarity == 4) baseChance = 5.0;
        } else if (g_iBossRarity == 2) {
            if (itemRarity == 1) baseChance = 60.0;
            else if (itemRarity == 2) baseChance = 30.0;
            else if (itemRarity == 3) baseChance = 20.0;
            else if (itemRarity == 4) baseChance = 10.0;
        } else if (g_iBossRarity == 3) {
            if (itemRarity == 1) baseChance = 80.0;
            else if (itemRarity == 2) baseChance = 50.0;
            else if (itemRarity == 3) baseChance = 30.0;
            else if (itemRarity == 4) baseChance = 15.0;
        }

        if (baseChance > 0.0) {
            // Увеличиваем базовый шанс на процент от предметов
            float finalChance = baseChance + (baseChance * itemBonus / 100.0);

            if (GetRandomFloat(0.0, 100.0) <= finalChance) {
                char query[512];
                Format(query, sizeof(query), "INSERT INTO rpg_inventory (steamid, item_id, is_equipped, slot_index) VALUES ('%s', %d, 0, 0)", sSteamID, itemId);
                g_dDatabase.Query(SQL_Callback_Silent, query);

                PrintToChat(client, " \x04[RPG] \x01Вы выбили \x04%s\x01 с Босса!", sItemName);
            }
        }
    }
}


public Action Timer_UpdateHud(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsClientInGame(g_iBossClient)) {
        g_hHudTimer = null;
        return Plugin_Stop;
    }

    // Считаем сколько осталось времени
    int timeLeft = RoundToCeil(g_flBossEndTime - GetEngineTime());

    // ЕСЛИ ВРЕМЯ ВЫШЛО (10 минут прошло)
    if (timeLeft <= 0) {
        g_bBossActive = false; // Выключаем статус, чтобы не выдать награды при смерти

        PrintToChatAll(" \x04[RPG] \x02Время вышло! Танос покинул поле боя.");
        if (IsClientInGame(g_iBossClient)) KickClient(g_iBossClient, "Время вышло");

        // Отключаем бесконечные спавны и делаем Ничью
        if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
        if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }
        ServerCommand("mp_ignore_round_win_conditions 0");
        CS_TerminateRound(3.0, CSRoundEnd_Draw);

        g_hHudTimer = null;
        return Plugin_Stop;
    }

    char rName[32];
    switch(g_iBossRarity) {
        case 0: rName = "Обычный";
        case 1: rName = "Редкий";
        case 2: rName = "Легендарный";
        case 3: rName = "МИФИЧЕСКИЙ";
    }

    // Форматируем минуты и секунды
    int mins = timeLeft / 60;
    int secs = timeLeft % 60;

    SetHudTextParams(0.02, 0.05, 0.6, 255, 255, 255, 255);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            ShowSyncHudText(i, g_hHudSync, "ТАНОС [%s]\\nХП: %d / %d\\nОсталось: %02d:%02d", rName, g_iBossHP, g_iBossMaxHP, mins, secs);
        }
    }
    return Plugin_Continue;
}

int GetNearestPlayer(int bossEntity) {
    int nearest = -1;
    float minDist = 9999.0;
    float bPos[3]; GetClientAbsOrigin(bossEntity, bPos);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != bossEntity && GetClientTeam(i) != GetClientTeam(bossEntity)) {
            float pPos[3];
            GetClientAbsOrigin(i, pPos);
            float d = GetVectorDistance(bPos, pPos);
            if (d < minDist) { minDist = d; nearest = i; }
        }
    }
    return nearest;
}

bool FindHottestSpawnPoint(float pos[3]) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i)) {
            float playerPos[3], eyeAng[3], fwd[3];
            GetClientAbsOrigin(i, playerPos);
            GetClientEyeAngles(i, eyeAng);
            GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);

            pos[0] = playerPos[0] + (fwd[0] * 150.0);
            pos[1] = playerPos[1] + (fwd[1] * 150.0);
            pos[2] = playerPos[2] + 10.0;
            return true;
        }
    }
    return false;
}

public void SQL_Callback_Silent(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') LogError("[RPG SQL Error] %s", error);
}
public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason) {
    if (g_bBossActive) {
        if (reason != CSRoundEnd_Draw && reason != CSRoundEnd_CTWin) {
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}


public Action Timer_CastSkill(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsClientInGame(g_iBossClient)) {
        g_hSkillTimer = null;
        return Plugin_Stop;
    }

    g_iNextSkill = GetRandomInt(1, 4);
    char skillName[64];

    switch (g_iNextSkill) {
        case 1: skillName = "КАМЕНЬ СИЛЫ (УДАР ТИТАНА)";
        case 2: skillName = "КАМЕНЬ ПРОСТРАНСТВА (ТЕЛЕПОРТАЦИЯ)";
        case 3: skillName = "КАМЕНЬ РЕАЛЬНОСТИ (ИСКАЖЕНИЕ)";
        case 4: skillName = "КАМЕНЬ РАЗУМА (ОСЛЕПЛЕНИЕ)";
    }

    PrintToChatAll(" \x04[ТАНОС] \x0EПодготовка способности: \x0C%s", skillName);

    // Вывод текста на экран за 3 сек до каста
    SetHudTextParams(-1.0, 0.3, 3.0, 255, 0, 255, 255); // Фиолетовый
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            ShowHudText(i, -1, "ВНИМАНИЕ!\n%s ЧЕРЕЗ 3 СЕК!", skillName);
        }
    }

    CreateTimer(3.0, Timer_ExecuteSkill);
    return Plugin_Continue;
}

public Action Timer_ExecuteSkill(Handle timer) {
    if (!g_bBossActive || g_iBossClient == -1 || !IsClientInGame(g_iBossClient)) return Plugin_Stop;

    float bossPos[3];
    GetClientAbsOrigin(g_iBossClient, bossPos);

    switch (g_iNextSkill) {
        case 1: { // Удар Титана
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT) {
                    float pPos[3];
                    GetClientAbsOrigin(i, pPos);
                    if (GetVectorDistance(bossPos, pPos) < 500.0) {
                        SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 50.0, DMG_BLAST);
                        float push[3];
                        MakeVectorFromPoints(bossPos, pPos, push);
                        NormalizeVector(push, push);
                        ScaleVector(push, 800.0);
                        push[2] = 400.0;
                        TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, push);
                    }
                }
            }
            PrintToChatAll(" \x04[ТАНОС] \x0EКАМЕНЬ СИЛЫ: Все в радиусе отброшены!");
        }
        case 2: { // Телепортация
            int target = GetNearestPlayer(g_iBossClient);
            if (target != -1) {
                float pPos[3];
                GetClientAbsOrigin(target, pPos);
                TeleportEntity(g_iBossClient, pPos, NULL_VECTOR, NULL_VECTOR);

                // АоЕ урон после ТП
                for (int i = 1; i <= MaxClients; i++) {
                    if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT) {
                        float tPos[3];
                        GetClientAbsOrigin(i, tPos);
                        if (GetVectorDistance(pPos, tPos) < 300.0) {
                            SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 40.0, DMG_ENERGYBEAM);
                        }
                    }
                }
                PrintToChatAll(" \x04[ТАНОС] \x0EКАМЕНЬ ПРОСТРАНСТВА: Телепортация!");
            }
        }
        case 3: { // Искажение (Ослепление)
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT) {
                    float pPos[3];
                    GetClientAbsOrigin(i, pPos);
                    if (GetVectorDistance(bossPos, pPos) < 800.0) {
                        ClientCommand(i, "r_screenoverlay """); // Сброс
                        SetEntPropFloat(i, Prop_Send, "m_flFlashDuration", 5.0);
                        SetEntPropFloat(i, Prop_Send, "m_flFlashMaxAlpha", 255.0);
                    }
                }
            }
            PrintToChatAll(" \x04[ТАНОС] \x0EКАМЕНЬ РЕАЛЬНОСТИ: Искажение пространства!");
        }
        case 4: { // Разум (Инверсия или ослепление)
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT) {
                    if (GetRandomFloat(0.0, 100.0) <= 30.0) {
                        SetEntPropFloat(i, Prop_Send, "m_flFlashDuration", 5.0);
                        SetEntPropFloat(i, Prop_Send, "m_flFlashMaxAlpha", 255.0);
                        PrintToChat(i, " \x02Вам затуманили разум!");
                    }
                }
            }
            PrintToChatAll(" \x04[ТАНОС] \x0EКАМЕНЬ РАЗУМА: Затуманивание сознания!");
        }
    }
    return Plugin_Stop;
}
