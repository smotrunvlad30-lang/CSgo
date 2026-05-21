#pragma semicolon 1
#include <sourcemod>

Database g_hDB = null;

// Кеш привилегий
bool g_bHasVip[MAXPLAYERS + 1];
bool g_bHasSVip[MAXPLAYERS + 1];
bool g_bHasBoss[MAXPLAYERS + 1];
char g_szPrefix[MAXPLAYERS + 1][64];

// Кеш цветов
char g_szPrefixColor[MAXPLAYERS + 1][8];
char g_szNameColor[MAXPLAYERS + 1][8];
char g_szTextColor[MAXPLAYERS + 1][8];

// Состояние меню для игрока
char g_szMenuType[MAXPLAYERS + 1][16];

public Plugin myinfo = {
    name = "ONYX VIP Core (Safe Admins)",
    author = "ONYX",
    description = "Автовыдача доната + Настройка цветов (!s) + Безопасность admins_simple",
    version = "1.3"
};

public void OnPluginStart() {
    Database.Connect(SQL_OnConnect, "rpg");
    CreateTimer(60.0, Timer_UpdateAll, _, TIMER_REPEAT);
    
    RegConsoleCmd("sm_s", Cmd_Settings, "Меню настройки чата");
}

public void SQL_OnConnect(Database db, const char[] error, any data) {
    if (db == null) LogError("[ONYX-VIP] Ошибка БД: %s", error);
    else g_hDB = db;
}

public void OnClientPostAdminCheck(int client) {
    UpdatePlayerVIP(client);
}

public Action Timer_UpdateAll(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) UpdatePlayerVIP(i);
    }
    return Plugin_Continue;
}

void UpdatePlayerVIP(int client) {
    if (g_hDB == null || !IsClientInGame(client) || IsFakeClient(client)) return;

    char auth[32];
    if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth))) return;

    char query[512];
    Format(query, sizeof(query), "SELECT is_vip, vip_expire, is_svip, svip_expire, is_boss, boss_expire, prefix, prefix_color, name_color, text_color FROM rpg_system WHERE steamid = '%s'", auth);
    g_hDB.Query(SQL_OnCheckVIP, query, GetClientUserId(client));
}

public void SQL_OnCheckVIP(Database db, DBResultSet results, const char[] error, any data) {
    int client = GetClientOfUserId(data);
    if (!client || !IsClientInGame(client)) return;

    if (error[0]) {
        LogError("[ONYX-VIP] SQL Error: %s", error);
        return;
    }

    AdminId admin = GetUserAdmin(client);
    char auth[32];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

    if (results.FetchRow()) {
        int is_vip = results.FetchInt(0);
        int vip_expire = results.FetchInt(1);
        int is_svip = results.FetchInt(2);
        int svip_expire = results.FetchInt(3);
        int is_boss = results.FetchInt(4);
        int boss_expire = results.FetchInt(5);
        
        char prefix[64], cPrefix[16], cName[16], cText[16];
        results.FetchString(6, prefix, sizeof(prefix));
        results.FetchString(7, cPrefix, sizeof(cPrefix));
        results.FetchString(8, cName, sizeof(cName));
        results.FetchString(9, cText, sizeof(cText));

        int currentTime = GetTime();

        // Истечение сроков
        if (is_vip > 0 && vip_expire < currentTime) { is_vip = 0; g_hDB.Query(SQL_CheckError, "UPDATE rpg_system SET is_vip=0 WHERE steamid='%s'", auth); }
        if (is_svip > 0 && svip_expire < currentTime) { is_svip = 0; g_hDB.Query(SQL_CheckError, "UPDATE rpg_system SET is_svip=0 WHERE steamid='%s'", auth); }
        if (is_boss > 0 && boss_expire < currentTime) { is_boss = 0; g_hDB.Query(SQL_CheckError, "UPDATE rpg_system SET is_boss=0 WHERE steamid='%s'", auth); }

        g_bHasVip[client] = (is_vip > 0);
        g_bHasSVip[client] = (is_svip > 0);
        g_bHasBoss[client] = (is_boss > 0);
        strcopy(g_szPrefix[client], sizeof(g_szPrefix[]), prefix);

        ApplyColor(g_szPrefixColor[client], sizeof(g_szPrefixColor[]), cPrefix);
        ApplyColor(g_szNameColor[client], sizeof(g_szNameColor[]), cName);
        ApplyColor(g_szTextColor[client], sizeof(g_szTextColor[]), cText);

        // ИСПРАВЛЕНИЕ: Выдаем или забираем ТОЛЬКО наши флаги, не трогая z и другие
        if (g_bHasVip[client] || g_bHasSVip[client] || g_bHasBoss[client]) {
            if (admin == INVALID_ADMIN_ID) { 
                admin = CreateAdmin("ONYX_WEB_DONATE"); 
                SetUserAdmin(client, admin, true); 
            }
            admin.SetFlag(Admin_Custom1, g_bHasVip[client]);
            admin.SetFlag(Admin_Custom2, g_bHasSVip[client]);
            admin.SetFlag(Admin_Custom3, g_bHasBoss[client]);
        } else {
            if (admin != INVALID_ADMIN_ID) {
                admin.SetFlag(Admin_Custom1, false);
                admin.SetFlag(Admin_Custom2, false);
                admin.SetFlag(Admin_Custom3, false);
            }
        }
    } 
    else {
        // Если игрока вообще нет в базе (например, Главный Админ, который еще не заходил на сайт)
        g_bHasVip[client] = false;
        g_bHasSVip[client] = false;
        g_bHasBoss[client] = false;
        g_szPrefix[client][0] = '\0';
        ApplyColor(g_szPrefixColor[client], 8, "default");
        ApplyColor(g_szNameColor[client], 8, "default");
        ApplyColor(g_szTextColor[client], 8, "default");

        // Убираем только донатные флаги
        if (admin != INVALID_ADMIN_ID) {
            admin.SetFlag(Admin_Custom1, false);
            admin.SetFlag(Admin_Custom2, false);
            admin.SetFlag(Admin_Custom3, false);
        }
    }
}

public void SQL_CheckError(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0]) LogError("[ONYX-VIP] SQL Error: %s", error);
}

// -------------------------------------------------------------------------
// МЕНЮ НАСТРОЕК !s
// -------------------------------------------------------------------------
public Action Cmd_Settings(int client, int args) {
    if (!client || !IsClientInGame(client)) return Plugin_Handled;
    
    Menu menu = new Menu(MenuHandler_Main);
    menu.SetTitle("🎨 Настройка чата\n ");
    
    if (g_szPrefix[client][0] != '\0') menu.AddItem("prefix", "Цвет префикса");
    else menu.AddItem("prefix", "Цвет префикса (Нет префикса)", ITEMDRAW_DISABLED);
    
    // ROOT (z флаг) автоматически получает доступ к покраске
    bool isRoot = (GetUserFlagBits(client) & ADMFLAG_ROOT) != 0;
    
    if (g_bHasVip[client] || g_bHasSVip[client] || g_bHasBoss[client] || isRoot) {
        menu.AddItem("name", "Цвет ника");
        menu.AddItem("text", "Цвет текста");
    } else {
        menu.AddItem("name", "Цвет ника [Доступно VIP+]", ITEMDRAW_DISABLED);
        menu.AddItem("text", "Цвет текста [Доступно VIP+]", ITEMDRAW_DISABLED);
    }
    
    menu.Display(client, 30);
    return Plugin_Handled;
}

public int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        strcopy(g_szMenuType[param1], 16, info);
        ShowColorMenu(param1);
    } else if (action == MenuAction_End) delete menu;
}

void ShowColorMenu(int client) {
    Menu menu = new Menu(MenuHandler_Color);
    menu.SetTitle("Выберите цвет:\n ");
    
    menu.AddItem("default", "Стандартный");
    menu.AddItem("red", "Красный");
    menu.AddItem("darkred", "Темно-красный");
    menu.AddItem("green", "Зеленый");
    menu.AddItem("lightgreen", "Салатовый");
    menu.AddItem("lime", "Лаймовый");
    menu.AddItem("blue", "Синий");
    menu.AddItem("darkblue", "Темно-синий");
    menu.AddItem("purple", "Фиолетовый");
    menu.AddItem("pink", "Розовый");
    menu.AddItem("yellow", "Желтый");
    menu.AddItem("orange", "Оранжевый");
    menu.AddItem("gold", "Золотой");
    menu.AddItem("grey", "Серый");

    menu.ExitBackButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_Color(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char colorName[16];
        menu.GetItem(param2, colorName, sizeof(colorName));
        
        char query[256];
        char auth[32];
        GetClientAuthId(param1, AuthId_Steam2, auth, sizeof(auth));
        
        if (StrEqual(g_szMenuType[param1], "prefix")) {
            ApplyColor(g_szPrefixColor[param1], 8, colorName);
            Format(query, sizeof(query), "UPDATE rpg_system SET prefix_color = '%s' WHERE steamid = '%s'", colorName, auth);
            PrintToChat(param1, " \x04[ONYX]\x01 Цвет префикса успешно изменен!");
        } 
        else if (StrEqual(g_szMenuType[param1], "name")) {
            ApplyColor(g_szNameColor[param1], 8, colorName);
            Format(query, sizeof(query), "UPDATE rpg_system SET name_color = '%s' WHERE steamid = '%s'", colorName, auth);
            PrintToChat(param1, " \x04[ONYX]\x01 Цвет ника успешно изменен!");
        } 
        else if (StrEqual(g_szMenuType[param1], "text")) {
            ApplyColor(g_szTextColor[param1], 8, colorName);
            Format(query, sizeof(query), "UPDATE rpg_system SET text_color = '%s' WHERE steamid = '%s'", colorName, auth);
            PrintToChat(param1, " \x04[ONYX]\x01 Цвет текста успешно изменен!");
        }
        g_hDB.Query(SQL_CheckError, query);
    } 
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        Cmd_Settings(param1, 0); 
    }
    else if (action == MenuAction_End) delete menu;
}

// -------------------------------------------------------------------------
// КАСТОМНЫЙ ЧАТ
// -------------------------------------------------------------------------
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;

    bool hasPrefix = (g_szPrefix[client][0] != '\0');
    bool isRoot = (GetUserFlagBits(client) & ADMFLAG_ROOT) != 0;
    bool hasDonate = (g_bHasVip[client] || g_bHasSVip[client] || g_bHasBoss[client] || isRoot);

    if (hasPrefix || hasDonate) {
        if (sArgs[0] == '/' || sArgs[0] == '!') return Plugin_Continue;

        char nameColor[8], textColor[8];
        strcopy(nameColor, sizeof(nameColor), g_szNameColor[client]);
        strcopy(textColor, sizeof(textColor), g_szTextColor[client]);
        
        if (!hasDonate) {
            strcopy(nameColor, sizeof(nameColor), "\x03"); 
            strcopy(textColor, sizeof(textColor), "\x01"); 
        }

        if (hasPrefix) {
            PrintToChatAll(" \x01%s[%s] %s%N\x01 : %s%s", g_szPrefixColor[client], g_szPrefix[client], nameColor, client, textColor, sArgs);
        } else {
            PrintToChatAll(" \x01%s%N\x01 : %s%s", nameColor, client, textColor, sArgs);
        }
        return Plugin_Handled; 
    }

    return Plugin_Continue;
}

void ApplyColor(char[] buffer, int maxlen, const char[] colorName) {
    if (StrEqual(colorName, "darkred")) strcopy(buffer, maxlen, "\x02");
    else if (StrEqual(colorName, "purple")) strcopy(buffer, maxlen, "\x03");
    else if (StrEqual(colorName, "green")) strcopy(buffer, maxlen, "\x04");
    else if (StrEqual(colorName, "lightgreen")) strcopy(buffer, maxlen, "\x05");
    else if (StrEqual(colorName, "lime")) strcopy(buffer, maxlen, "\x06");
    else if (StrEqual(colorName, "red")) strcopy(buffer, maxlen, "\x07");
    else if (StrEqual(colorName, "grey")) strcopy(buffer, maxlen, "\x08");
    else if (StrEqual(colorName, "yellow")) strcopy(buffer, maxlen, "\x09");
    else if (StrEqual(colorName, "orange")) strcopy(buffer, maxlen, "\x0A");
    else if (StrEqual(colorName, "blue")) strcopy(buffer, maxlen, "\x0B");
    else if (StrEqual(colorName, "darkblue")) strcopy(buffer, maxlen, "\x0C");
    else if (StrEqual(colorName, "pink")) strcopy(buffer, maxlen, "\x0E");
    else if (StrEqual(colorName, "gold")) strcopy(buffer, maxlen, "\x10");
    else strcopy(buffer, maxlen, "\x01"); 
}