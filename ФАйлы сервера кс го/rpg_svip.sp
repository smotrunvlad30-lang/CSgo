// ==============================================================================
// МОДУЛЬ: SUPER VIP SYSTEM (SVIP)
// ==============================================================================

// --- ПЕРЕМЕННЫЕ SVIP ---
bool g_bEliteWeaponSVIP[MAXPLAYERS + 1]; 
bool g_bBoostCredits[MAXPLAYERS + 1];
bool g_bBoostXP[MAXPLAYERS + 1];

// --- КУЛДАУНЫ (В РАУНДАХ) ---
int g_iAkCooldownSVIP[MAXPLAYERS + 1];
int g_iM4CooldownSVIP[MAXPLAYERS + 1];
int g_iCredCooldown[MAXPLAYERS + 1];
int g_iXpCooldown[MAXPLAYERS + 1];

// --- ДЛЯ ПРЫЖКОВ ---
int g_iJumpsSVIP[MAXPLAYERS + 1];
int g_iLastButtonsSVIP[MAXPLAYERS + 1];

/**
 * Проверка доступа. 
 * Флаг 'p' (Custom2) или 'z' (Root).
 */
bool IsSVip(int client) {
    if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return false;
    
    int flags = GetUserFlagBits(client);
    if (flags & ADMFLAG_ROOT || flags & ADMFLAG_CUSTOM2 || CheckCommandAccess(client, "sm_svip_flag", ADMFLAG_CUSTOM2)) {
        return true;
    }
    return false;
}

void SVip_OnPluginStart() {
    RegConsoleCmd("sm_svip", Cmd_SVipMenu, "Открыть меню SUPER VIP");
}

// Вызывается из ядра при спавне
void SVip_OnPlayerSpawn(int client) {
    if (client > 0 && IsSVip(client)) {
        g_bEliteWeaponSVIP[client] = false;
       
    }
}

void SVip_OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, SVip_OnTakeDamage);
    
    g_bEliteWeaponSVIP[client] = false;
    g_bBoostCredits[client] = false;
    g_bBoostXP[client] = false;
    
    g_iAkCooldownSVIP[client] = 0;
    g_iM4CooldownSVIP[client] = 0;
    g_iCredCooldown[client] = 0;
    g_iXpCooldown[client] = 0;
    
    g_iJumpsSVIP[client] = 0;
    g_iLastButtonsSVIP[client] = 0;
}

// УБРАНЫ ВАРНИНГИ: Добавлена очистка всех неиспользуемых аргументов события
void SVip_Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    #pragma unused event, name, dontBroadcast
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (g_iAkCooldownSVIP[i] > 0) g_iAkCooldownSVIP[i]--;
            if (g_iM4CooldownSVIP[i] > 0) g_iM4CooldownSVIP[i]--;
            if (g_iCredCooldown[i] > 0) g_iCredCooldown[i]--;
            if (g_iXpCooldown[i] > 0) g_iXpCooldown[i]--;
            
            g_bBoostCredits[i] = false;
            g_bBoostXP[i] = false;
        }
    }
}

// УБРАНЫ ВАРНИНГИ: Очистка аргументов
void SVip_Event_Death(Event event, const char[] name, bool dontBroadcast) {
    #pragma unused name, dontBroadcast
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (attacker > 0 && attacker != victim && IsClientInGame(attacker) && IsSVip(attacker)) {
        // 1. БУСТ КРЕДИТОВ (RPG)
        if (g_bBoostCredits[attacker]) {
            g_iMoney[attacker] += 3000;
            PrintToChat(attacker, "[\x0ESVIP\x01] Буст: \x04+3000 RPG Кредитов\x01 за убийство!");
        }
        
        // 2. БУСТ ОПЫТА (RPG)
        if (g_bBoostXP[attacker]) {
            AddXP(attacker, 5000, "SVIP Буст Опыта");
            PrintToChat(attacker, "[\x0ESVIP\x01] Буст: \x04+5000 XP\x01 за убийство!");
        }
    }
}

// --- МЕНЮ SVIP ---
public Action Cmd_SVipMenu(int client, int args) {
    #pragma unused args
    if (client == 0) return Plugin_Handled;

    if (!IsSVip(client)) {
        PrintToChat(client, "[\x0ESVIP\x01] Доступ закрыт! Необходим статус SUPER VIP.");
        return Plugin_Handled;
    }

    BuildSVipMenu(client);
    return Plugin_Handled;
}

void BuildSVipMenu(int client) {
    Menu menu = new Menu(Handler_SVipMain);
    menu.SetTitle("SUPER VIP МЕНЮ:\n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯");
    
    char buf[64];
    if (g_iAkCooldownSVIP[client] > 0) Format(buf, sizeof(buf), "Elite AK-47 [КД: %d р.]", g_iAkCooldownSVIP[client]);
    else Format(buf, sizeof(buf), "Elite AK-47 (+10%% урона)");
    menu.AddItem("ak47", buf, g_iAkCooldownSVIP[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if (g_iM4CooldownSVIP[client] > 0) Format(buf, sizeof(buf), "Elite M4A1-S [КД: %d р.]", g_iM4CooldownSVIP[client]);
    else Format(buf, sizeof(buf), "Elite M4A1-S (+10%% урона)");
    menu.AddItem("m4a1", buf, g_iM4CooldownSVIP[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if (g_iCredCooldown[client] > 0) Format(buf, sizeof(buf), "Буст: 3000 Кредитов за килл [КД: %d р.]", g_iCredCooldown[client]);
    else if (g_bBoostCredits[client]) Format(buf, sizeof(buf), "Буст: 3000 Кредитов (АКТИВЕН)");
    else Format(buf, sizeof(buf), "Взять Буст: 3000 Кредитов (на 1 раунд)");
    menu.AddItem("credits", buf, (g_iCredCooldown[client] > 0 || g_bBoostCredits[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if (g_iXpCooldown[client] > 0) Format(buf, sizeof(buf), "Буст: +5000 XP за килл [КД: %d р.]", g_iXpCooldown[client]);
    else if (g_bBoostXP[client]) Format(buf, sizeof(buf), "Буст: +5000 XP (АКТИВЕН)");
    else Format(buf, sizeof(buf), "Взять Буст: +5000 XP (на 1 раунд)");
    menu.AddItem("xp", buf, (g_iXpCooldown[client] > 0 || g_bBoostXP[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_SVipMain(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        
        if (StrEqual(info, "ak47")) {
            GiveEliteWeaponSVIP(client, "weapon_ak47");
            g_iAkCooldownSVIP[client] = 3; 
        } else if (StrEqual(info, "m4a1")) {
            GiveEliteWeaponSVIP(client, "weapon_m4a1_silencer");
            g_iM4CooldownSVIP[client] = 3; 
        } else if (StrEqual(info, "credits")) {
            g_bBoostCredits[client] = true;
            g_iCredCooldown[client] = 10; 
            PrintToChat(client, "[\x0ESVIP\x01] Вы активировали \x04Буст Кредитов\x01!");
        } else if (StrEqual(info, "xp")) {
            g_bBoostXP[client] = true;
            g_iXpCooldown[client] = 10; 
            PrintToChat(client, "[\x0ESVIP\x01] Вы активировали \x04Буст Опыта\x01!");
        }
        BuildSVipMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void GiveEliteWeaponSVIP(int client, const char[] weapon) {
    if (!IsPlayerAlive(client)) return;
    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (primary != -1) {
        RemovePlayerItem(client, primary);
        AcceptEntityInput(primary, "Kill");
    }
    GivePlayerItem(client, weapon);
    g_bEliteWeaponSVIP[client] = true;
    PrintToChat(client, "[\x0ESVIP\x01] Вы получили оружие.");
}

// УБРАНЫ ВАРНИНГИ: Добавлена очистка victim, inflictor и damagetype
public Action SVip_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    #pragma unused victim, inflictor, damagetype

    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
        if (g_bEliteWeaponSVIP[attacker] && IsSVip(attacker)) {
            char wpn[32];
            GetClientWeapon(attacker, wpn, sizeof(wpn));
            if (StrContains(wpn, "ak47") != -1 || StrContains(wpn, "m4a1") != -1) {
                damage *= 1.10; 
                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}

// --- 5 ПРЫЖКОВ ДЛЯ SVIP ---
void SVip_OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    // УБРАНЫ ВАРНИНГИ: Очистка неиспользуемых аргументов
    #pragma unused impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse
    
    if (!IsPlayerAlive(client) || !IsSVip(client)) return;

    int flags = GetEntityFlags(client);
    if (flags & FL_ONGROUND) {
        g_iJumpsSVIP[client] = 0;
    } 
    else if ((buttons & IN_JUMP) && !(g_iLastButtonsSVIP[client] & IN_JUMP)) {
        if (g_iJumpsSVIP[client] < 4) {
            g_iJumpsSVIP[client]++;
            float currentVel[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentVel);
            currentVel[2] = 260.0; 
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentVel);
        }
    }
    g_iLastButtonsSVIP[client] = buttons;
}