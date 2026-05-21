#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

// Объявляем Native из основного плагина RPG
native void RPG_GiveCredits(int client, int amount);

int g_iCredTarget[MAXPLAYERS+1];
#define HIDE_RADAR (1 << 12)

public Plugin myinfo = {
    name = "Surf Utilities - Core",
    author = "Skvirt", 
    version = "3.7" // Версия обновлена
};

public void OnPluginStart() {
    // Команда доступна только админам с флагом ROOT (z)
    RegAdminCmd("sm_cred", Cmd_CredAdmin, ADMFLAG_ROOT, "Выдать кредиты");
    
    // Таймер для скрытия худа и денег
    CreateTimer(1.0, Timer_EnforceLimits, _, TIMER_REPEAT);
}

// ==============================================================================
// ПРИНУДИТЕЛЬНЫЕ НАСТРОЙКИ СЕРВЕРА ПРИ ЗАПУСКЕ КАРТЫ
// ==============================================================================
public void OnMapStart() {
    // 1. Настройки физики Surf
    CheckAndForce("sv_airaccelerate", 1000.0);
    CheckAndForce("sv_friction", 4.0); 
    
    // 2. Отключаем разминку
    CheckAndForce("mp_do_warmup_period", 0.0);
    CheckAndForce("mp_warmuptime", 0.0);
    
    // 3. Отключаем заморозку в начале раунда
    CheckAndForce("mp_freezetime", 0.0);
    
    // 4. Ставим раунды по 60 минут (для всех типов карт)
    CheckAndForce("mp_roundtime", 60.0);
    CheckAndForce("mp_roundtime_defuse", 60.0);
    CheckAndForce("mp_roundtime_hostage", 60.0);
    
    // 5. Бонус: делаем так, чтобы игра не заканчивалась после нескольких раундов
    CheckAndForce("mp_maxrounds", 0.0);
    CheckAndForce("mp_timelimit", 0.0);
}

public Action Timer_EnforceLimits(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            // Прячем радар и обнуляем стандартные деньги CS:GO для чистоты интерфейса
            SetEntProp(i, Prop_Send, "m_iHideHUD", HIDE_RADAR);
            SetEntProp(i, Prop_Send, "m_iAccount", 0); 
        }
    }
    return Plugin_Continue;
}

void CheckAndForce(const char[] name, float expected) {
    ConVar cv = FindConVar(name);
    if (cv != null) {
        // Отключаем уведомления об изменении, чтобы не спамить в чат
        cv.Flags &= ~(FCVAR_NOTIFY | FCVAR_CHEAT | FCVAR_REPLICATED);
        cv.SetBounds(ConVarBound_Upper, false); 
        cv.SetFloat(expected);
    }
}

// ==============================================================================
// МЕНЮ ВЫДАЧИ КРЕДИТОВ
// ==============================================================================

public Action Cmd_CredAdmin(int client, int args) { 
    BuildCredPlayerMenu(client); 
    return Plugin_Handled; 
}

void BuildCredPlayerMenu(int client) {
    Menu menu = new Menu(Handler_CredPlayer);
    menu.SetTitle("Выберите игрока:");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            char id[16], name[32]; 
            IntToString(GetClientUserId(i), id, sizeof(id)); 
            GetClientName(i, name, sizeof(name));
            menu.AddItem(id, name);
        }
    }
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_CredPlayer(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[16]; 
        menu.GetItem(item, info, sizeof(info));
        g_iCredTarget[client] = GetClientOfUserId(StringToInt(info));
        BuildCredAmountMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void BuildCredAmountMenu(int client) {
    Menu menu = new Menu(Handler_CredAmount);
    menu.SetTitle("Выдать сумму:");
    menu.AddItem("100000", "100,000$");
    menu.AddItem("1000000", "1,000,000$");
    menu.AddItem("10000000", "10,000,000$");
    menu.AddItem("50000000", "50,000,000$");
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_CredAmount(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[32]; 
        menu.GetItem(item, info, sizeof(info));
        if (g_iCredTarget[client] > 0 && IsClientInGame(g_iCredTarget[client])) {
            RPG_GiveCredits(g_iCredTarget[client], StringToInt(info));
            PrintToChat(client, "[\x04RPG\x01] Кредиты успешно выданы!");
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}