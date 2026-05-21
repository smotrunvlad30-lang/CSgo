// ==============================================================================
// МОДУЛЬ: BOSS SYSTEM (BOSS)
// Автор: Skvirt
// ==============================================================================

#include <mapchooser>

// --- ПЕРЕМЕННЫЕ BOSS ---
bool g_bEliteWeaponBoss[MAXPLAYERS + 1]; 
bool g_bBoostCreditsBoss[MAXPLAYERS + 1];
bool g_bBoostXPBoss[MAXPLAYERS + 1];
bool g_bNoRecoilBoss[MAXPLAYERS + 1];

// --- КУЛДАУНЫ (В РАУНДАХ) ---
int g_iAkCooldownBoss[MAXPLAYERS + 1];
int g_iM4CooldownBoss[MAXPLAYERS + 1];
int g_iCredCooldownBoss[MAXPLAYERS + 1];
int g_iXpCooldownBoss[MAXPLAYERS + 1];
int g_iNoRecoilCooldownBoss[MAXPLAYERS + 1];

// --- ДЛЯ ПРЫЖКОВ ---
int g_iJumpsBoss[MAXPLAYERS + 1];
int g_iLastButtonsBoss[MAXPLAYERS + 1];

/**
 * Проверка доступа. 
 * Флаг 'q' (Custom3) или 'z' (Root).
 */
bool IsBoss(int client) {
    if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return false;
    
    int flags = GetUserFlagBits(client);
    if (flags & ADMFLAG_ROOT || flags & ADMFLAG_CUSTOM3 || CheckCommandAccess(client, "sm_boss_flag", ADMFLAG_CUSTOM3)) {
        return true;
    }
    return false;
}

void Boss_OnPluginStart() {
    RegConsoleCmd("sm_sbos", Cmd_BossMenu, "Открыть меню БОССА");
}

void Boss_OnPlayerSpawn(int client) {
    if (client > 0 && IsBoss(client)) {
        g_bEliteWeaponBoss[client] = false;
        // СООБЩЕНИЕ О ДОСТУПНОСТИ МЕНЮ УДАЛЕНО ПО ПРОСЬБЕ АВТОРА[cite: 9]
    }
}

void Boss_OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, Boss_OnTakeDamage);
    
    g_bEliteWeaponBoss[client] = false;
    g_bBoostCreditsBoss[client] = false;
    g_bBoostXPBoss[client] = false;
    g_bNoRecoilBoss[client] = false;
    
    g_iAkCooldownBoss[client] = 0;
    g_iM4CooldownBoss[client] = 0;
    g_iCredCooldownBoss[client] = 0;
    g_iXpCooldownBoss[client] = 0;
    g_iNoRecoilCooldownBoss[client] = 0;
    
    g_iJumpsBoss[client] = 0;
    g_iLastButtonsBoss[client] = 0;
}

void Boss_Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    #pragma unused event, name, dontBroadcast

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (g_iAkCooldownBoss[i] > 0) g_iAkCooldownBoss[i]--;
            if (g_iM4CooldownBoss[i] > 0) g_iM4CooldownBoss[i]--;
            if (g_iCredCooldownBoss[i] > 0) g_iCredCooldownBoss[i]--;
            if (g_iXpCooldownBoss[i] > 0) g_iXpCooldownBoss[i]--;
            if (g_iNoRecoilCooldownBoss[i] > 0) g_iNoRecoilCooldownBoss[i]--;
            
            g_bBoostCreditsBoss[i] = false;
            g_bBoostXPBoss[i] = false;
            g_bNoRecoilBoss[i] = false;
        }
    }
}

void Boss_Event_Death(Event event, const char[] name, bool dontBroadcast) {
    #pragma unused name, dontBroadcast

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (victim > 0 && victim <= MaxClients) {
        g_bNoRecoilBoss[victim] = false;
    }
    
    if (attacker > 0 && attacker != victim && IsClientInGame(attacker) && IsBoss(attacker)) {
        if (g_bBoostCreditsBoss[attacker]) {
            g_iMoney[attacker] += 6000;
            PrintToChat(attacker, "[\x07BOSS\x01] Буст: \x04+6000 Кредитов\x01 за убийство!");
        }
        
        if (g_bBoostXPBoss[attacker]) {
            AddXP(attacker, 8000, "BOSS Буст Опыта");
            PrintToChat(attacker, "[\x07BOSS\x01] Буст: \x04+8000 XP\x01 за убийство!");
        }
    }
}

public Action Cmd_BossMenu(int client, int args) {
    #pragma unused args
    if (client == 0) return Plugin_Handled;

    if (!IsBoss(client)) {
        PrintToChat(client, "[\x07BOSS\x01] Доступ закрыт! Необходима привилегия БОССА.");
        return Plugin_Handled;
    }

    BuildBossMenu(client);
    return Plugin_Handled;
}

void BuildBossMenu(int client) {
    Menu menu = new Menu(Handler_BossMain);
    menu.SetTitle("МЕНЮ БОССА:\n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯");
    
    char buf[64];

    if (g_iAkCooldownBoss[client] > 0) Format(buf, sizeof(buf), "Boss AK-47 [КД: %d р.]", g_iAkCooldownBoss[client]);
    else Format(buf, sizeof(buf), "Boss AK-47 (+30%% урона)");
    menu.AddItem("ak47", buf, g_iAkCooldownBoss[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if (g_iM4CooldownBoss[client] > 0) Format(buf, sizeof(buf), "Boss M4A1-S [КД: %d р.]", g_iM4CooldownBoss[client]);
    else Format(buf, sizeof(buf), "Boss M4A1-S (+30%% урона)");
    menu.AddItem("m4a1", buf, g_iM4CooldownBoss[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    // ИСПРАВЛЕНО: Теперь отображается "Кредитов" вместо "$"[cite: 9]
    if (g_iCredCooldownBoss[client] > 0) Format(buf, sizeof(buf), "Буст: 6000 Кред. за килл [КД: %d р.]", g_iCredCooldownBoss[client]);
    else if (g_bBoostCreditsBoss[client]) Format(buf, sizeof(buf), "Буст: 6000 Кред. (АКТИВЕН)");
    else Format(buf, sizeof(buf), "Буст: 6000 Кредитов на 1 раунд");
    menu.AddItem("credits", buf, (g_iCredCooldownBoss[client] > 0 || g_bBoostCreditsBoss[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if (g_iXpCooldownBoss[client] > 0) Format(buf, sizeof(buf), "Буст: +8000 XP за килл [КД: %d р.]", g_iXpCooldownBoss[client]);
    else if (g_bBoostXPBoss[client]) Format(buf, sizeof(buf), "Буст: +8000 XP (АКТИВЕН)");
    else Format(buf, sizeof(buf), "Буст: +8000 XP на 1 раунд");
    menu.AddItem("xp", buf, (g_iXpCooldownBoss[client] > 0 || g_bBoostXPBoss[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    
    if (g_iNoRecoilCooldownBoss[client] > 0) Format(buf, sizeof(buf), "Антиразброс [КД: %d р.]", g_iNoRecoilCooldownBoss[client]);
    else if (g_bNoRecoilBoss[client]) Format(buf, sizeof(buf), "Антиразброс (АКТИВЕН)");
    else Format(buf, sizeof(buf), "Взять Антиразброс");
    menu.AddItem("norecoil", buf, (g_iNoRecoilCooldownBoss[client] > 0 || g_bNoRecoilBoss[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    menu.AddItem("rtv", "Принудительно сменить карту (RTV)");
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_BossMain(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        
        if (StrEqual(info, "ak47")) {
            GiveEliteWeaponBoss(client, "weapon_ak47");
            g_iAkCooldownBoss[client] = 3; 
        } else if (StrEqual(info, "m4a1")) {
            GiveEliteWeaponBoss(client, "weapon_m4a1_silencer");
            g_iM4CooldownBoss[client] = 3; 
        } else if (StrEqual(info, "credits")) {
            g_bBoostCreditsBoss[client] = true;
            g_iCredCooldownBoss[client] = 10; 
            PrintToChat(client, "[\x07BOSS\x01] Вы активировали \x04Буст 6000 Кредитов\x01!");
        } else if (StrEqual(info, "xp")) {
            g_bBoostXPBoss[client] = true;
            g_iXpCooldownBoss[client] = 10; 
            PrintToChat(client, "[\x07BOSS\x01] Вы активировали \x04Буст 8000 Опыта\x01!");
        } else if (StrEqual(info, "norecoil")) {
            g_bNoRecoilBoss[client] = true;
            g_iNoRecoilCooldownBoss[client] = 7; 
            PrintToChat(client, "[\x07BOSS\x01] Вы активировали \x04Антиразброс\x01!");
        } else if (StrEqual(info, "rtv")) {
            if (LibraryExists("mapchooser") && CanMapChooserStartVote()) {
                InitiateMapChooserVote(MapChange_MapEnd);
                PrintToChatAll("[\x07BOSS\x01] \x04БОСС %N\x01 принудительно запустил голосование!", client);
            }
        }
        if (!StrEqual(info, "rtv")) BuildBossMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void GiveEliteWeaponBoss(int client, const char[] weapon) {
    if (!IsPlayerAlive(client)) return;
    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (primary != -1) {
        RemovePlayerItem(client, primary);
        AcceptEntityInput(primary, "Kill");
    }
    GivePlayerItem(client, weapon);
    g_bEliteWeaponBoss[client] = true;
    PrintToChat(client, "[\x07BOSS\x01] Вы получили оружие (+30%% Dmg).");
}

public Action Boss_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    #pragma unused victim, inflictor, damagetype

    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
        if (g_bEliteWeaponBoss[attacker] && IsBoss(attacker)) {
            char wpn[32]; GetClientWeapon(attacker, wpn, sizeof(wpn));
            if (StrContains(wpn, "ak47") != -1 || StrContains(wpn, "m4a1") != -1) {
                damage *= 1.30;
                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}

void Boss_OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    #pragma unused impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse
    
    if (!IsPlayerAlive(client) || !IsBoss(client)) return;

    if (g_bNoRecoilBoss[client]) {
        float punch[3] = {0.0, 0.0, 0.0};
        SetEntPropVector(client, Prop_Send, "m_aimPunchAngle", punch);
        SetEntPropVector(client, Prop_Send, "m_aimPunchAngleVel", punch);
        SetEntPropVector(client, Prop_Send, "m_viewPunchAngle", punch);
        
        int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if (activeWeapon != -1 && IsValidEntity(activeWeapon)) {
            SetEntPropFloat(activeWeapon, Prop_Send, "m_fAccuracyPenalty", 0.0);
        }
    }

    int flags = GetEntityFlags(client);
    if (flags & FL_ONGROUND) {
        g_iJumpsBoss[client] = 0;
    } else if ((buttons & IN_JUMP) && !(g_iLastButtonsBoss[client] & IN_JUMP)) {
        if (g_iJumpsBoss[client] < 6) {
            g_iJumpsBoss[client]++;
            float currentVel[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentVel);
            currentVel[2] = 260.0; 
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentVel);
        }
    }
    g_iLastButtonsBoss[client] = buttons;
}