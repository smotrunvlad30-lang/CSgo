#pragma semicolon 1
#include <sourcemod>

Database g_hDatabase = null;

public Plugin myinfo = {
    name = "ONYX Web Status",
    author = "Skvirt",
    description = "Fix connection",
    version = "1.6"
};

public void OnPluginStart() {
    Database.Connect(SQL_OnConnect, "rpg"); 
}

public void SQL_OnConnect(Database db, const char[] error, any data) {
    if (db == null) {
        LogError("[ONYX-STATUS] Ошибка: %s", error);
        return;
    }
    g_hDatabase = db;
    UpdateStatus();
}

public void OnMapStart() {
    CreateTimer(60.0, Timer_UpdateStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_UpdateStatus(Handle timer) {
    UpdateStatus();
    return Plugin_Continue;
}

void UpdateStatus() {
    if (g_hDatabase == null) return;
    char map[64];
    GetCurrentMap(map, sizeof(map));
    int players = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) players++;
    }
    char query[512];
    Format(query, sizeof(query), "INSERT INTO rpg_settings (setting_name, setting_value) VALUES ('server_map', '%s'), ('server_players', '%d'), ('server_max', '%d'), ('server_last_update', '%d') ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)", map, players, GetMaxHumanPlayers(), GetTime());
    g_hDatabase.Query(SQL_CheckError, query);
}

public void SQL_CheckError(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0]) LogError("[ONYX-STATUS] SQL Error: %s", error);
}