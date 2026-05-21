#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

// --- ПЕРЕМЕННЫЕ ОРУЖИЯ ---
bool g_bEliteWeapon[MAXPLAYERS + 1]; 
bool g_bHasNuke[MAXPLAYERS + 1];

// --- КУЛДАУНЫ (В РАУНДАХ) ---
int g_iAkCooldown[MAXPLAYERS + 1];
int g_iM4Cooldown[MAXPLAYERS + 1];
int g_iNadeCooldown[MAXPLAYERS + 1];

// --- ВОЗРОЖДЕНИЯ ---
int g_iRespawnsLeft[MAXPLAYERS + 1];
bool g_bAutoRespawn[MAXPLAYERS + 1];

// --- ДЛЯ ПРЫЖКОВ ---
int g_iJumps[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];

public Plugin myinfo = {
    name = "Elite VIP System",
    author = "Skvirt",
    version = "3.1"
};

/**
 * Проверка доступа. 
 * Если у игрока есть флаг 'o', 'z' или любая админка - пустит.
 */
bool IsVip(int client) {
    if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return false;
    
    int flags = GetUserFlagBits(client);
    if (flags & ADMFLAG_ROOT || flags & ADMFLAG_CUSTOM1 || CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)) {
        return true;
    }
    return false;
}

public void OnPluginStart() {
    RegConsoleCmd("sm_vip", Cmd_VipMenu, "Открыть меню VIP");
    
    HookEvent("player_spawn", Event_Spawn);
    HookEvent("player_death", Event_Death);
    HookEvent("round_start", Event_RoundStart);
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public void OnClientPutInServer(int client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    
    g_bEliteWeapon[client] = false;
    g_bHasNuke[client] = false;
    
    g_iAkCooldown[client] = 0;
    g_iM4Cooldown[client] = 0;
    g_iNadeCooldown[client] = 0;
    
    g_iRespawnsLeft[client] = 3;
    g_bAutoRespawn[client] = true; // Авто-возрождение включено по умолчанию
    
    g_iJumps[client] = 0;
    g_iLastButtons[client] = 0;
}

// --- СНИЖЕНИЕ КУЛДАУНОВ КАЖДЫЙ РАУНД ---
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (g_iAkCooldown[i] > 0) g_iAkCooldown[i]--;
            if (g_iM4Cooldown[i] > 0) g_iM4Cooldown[i]--;
            if (g_iNadeCooldown[i] > 0) g_iNadeCooldown[i]--;
        }
    }
}

// --- СПАВН ИГРОКА ---
public void Event_Spawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && IsVip(client)) {
        g_bEliteWeapon[client] = false;
        g_bHasNuke[client] = false;
        g_iRespawnsLeft[client] = 3; // Восстанавливаем 3 возрождения на раунд
        
        PrintToChat(client, "[\x04VIP\x01] VIP меню доступно: \x03!vip");
    }
}

// --- ВОЗРОЖДЕНИЕ ПРИ СМЕРТИ ---
public void Event_Death(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (client > 0 && IsClientInGame(client) && IsVip(client)) {
        if (g_bAutoRespawn[client] && g_iRespawnsLeft[client] > 0) {
            g_iRespawnsLeft[client]--;
            PrintToChat(client, "[\x04VIP\x01] Авто-возрождение! Осталось: \x04%d/3\x01", g_iRespawnsLeft[client]);
            CreateTimer(1.5, Timer_RespawnPlayer, GetClientUserId(client));
        }
    }
}

public Action Timer_RespawnPlayer(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && !IsPlayerAlive(client)) {
        CS_RespawnPlayer(client);
    }
    return Plugin_Stop;
}

// --- МЕНЮ VIP ---
public Action Cmd_VipMenu(int client, int args) {
    if (client == 0) return Plugin_Handled;

    if (!IsVip(client)) {
        PrintToChat(client, "[\x02VIP\x01] Доступ закрыт! Необходим статус VIP.");
        return Plugin_Handled;
    }

    BuildVipMenu(client);
    return Plugin_Handled;
}

void BuildVipMenu(int client) {
    Menu menu = new Menu(Handler_VipMain);
    menu.SetTitle("VIP МЕНЮ:\n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯");
    
    char buf[64];

    // Elite AK-47
    if (g_iAkCooldown[client] > 0) Format(buf, sizeof(buf), "Elite AK-47 [КД: %d р.]", g_iAkCooldown[client]);
    else Format(buf, sizeof(buf), "Elite AK-47 (+5%% урона)");
    menu.AddItem("ak47", buf, g_iAkCooldown[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    // Elite M4A1-S
    if (g_iM4Cooldown[client] > 0) Format(buf, sizeof(buf), "Elite M4A1-S [КД: %d р.]", g_iM4Cooldown[client]);
    else Format(buf, sizeof(buf), "Elite M4A1-S (+5%% урона)");
    menu.AddItem("m4a1", buf, g_iM4Cooldown[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    // Nuke Grenade
    if (g_iNadeCooldown[client] > 0) Format(buf, sizeof(buf), "Nuke Граната 3000 DMG [КД: %d р.]", g_iNadeCooldown[client]);
    else Format(buf, sizeof(buf), "Nuke Граната (3000 Урона)");
    menu.AddItem("nuke", buf, g_iNadeCooldown[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    // Авто-Возрождение
    Format(buf, sizeof(buf), "Авто-Возрождение: [%s] (%d/3)", g_bAutoRespawn[client] ? "ВКЛ" : "ВЫКЛ", g_iRespawnsLeft[client]);
    menu.AddItem("respawn", buf);
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_VipMain(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        
        if (StrEqual(info, "ak47")) {
            GiveEliteWeapon(client, "weapon_ak47");
            g_iAkCooldown[client] = 3; // КД 3 раунда
            
        } else if (StrEqual(info, "m4a1")) {
            GiveEliteWeapon(client, "weapon_m4a1_silencer");
            g_iM4Cooldown[client] = 3; // КД 3 раунда
            
        } else if (StrEqual(info, "nuke")) {
            GivePlayerItem(client, "weapon_hegrenade");
            g_bHasNuke[client] = true;
            g_iNadeCooldown[client] = 10; // КД 10 раундов
            PrintToChat(client, "[\x04VIP\x01] Вы получили \x02Nuke Гранату\x01!");
            
        } else if (StrEqual(info, "respawn")) {
            g_bAutoRespawn[client] = !g_bAutoRespawn[client];
            PrintToChat(client, "[\x04VIP\x01] Авто-возрождение %s.", g_bAutoRespawn[client] ? "\x04ВКЛЮЧЕНО\x01" : "\x02ВЫКЛЮЧЕНО\x01");
            BuildVipMenu(client); // Обновляем меню
        }
        
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void GiveEliteWeapon(int client, const char[] weapon) {
    if (!IsPlayerAlive(client)) return;

    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (primary != -1) {
        RemovePlayerItem(client, primary);
        AcceptEntityInput(primary, "Kill");
    }

    GivePlayerItem(client, weapon);
    g_bEliteWeapon[client] = true;
    
    if (StrContains(weapon, "ak47") != -1) PrintToChat(client, "[\x04VIP\x01] Вы получили \x03Elite AK-47\x01.");
    else PrintToChat(client, "[\x04VIP\x01] Вы получили \x03Elite M4A1-S\x01.");
}

// --- ЛОГИКА УРОНА (+5% и Nuke) ---
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
        
        // Проверка Nuke Гранаты
        if (g_bHasNuke[attacker]) {
            char inflictorName[32];
            if (inflictor > 0 && IsValidEdict(inflictor)) {
                GetEdictClassname(inflictor, inflictorName, sizeof(inflictorName));
                if (StrEqual(inflictorName, "hegrenade_projectile")) {
                    damage = 3000.0;
                    
                    // СБРОС БОНУСА: Граната сработала 1 раз, больше бонуса нет.
                    g_bHasNuke[attacker] = false; 
                    
                    return Plugin_Changed;
                }
            }
        }
        
        // Проверка Elite оружия (+5%)
        if (g_bEliteWeapon[attacker] && IsVip(attacker)) {
            char wpn[32];
            GetClientWeapon(attacker, wpn, sizeof(wpn));
            
            // Если игрок стреляет именно из элитной пушки
            if (StrContains(wpn, "ak47") != -1 || StrContains(wpn, "m4a1") != -1) {
                damage *= 1.05; 
                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}

// --- 3 ПРЫЖКА ДЛЯ VIP ---
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if (!IsPlayerAlive(client) || !IsVip(client)) return Plugin_Continue;

    int flags = GetEntityFlags(client);
    
    // Сбрасываем счетчик прыжков, если стоим на земле
    if (flags & FL_ONGROUND) {
        g_iJumps[client] = 0;
    } 
    // Если игрок нажал прыжок в воздухе, а до этого кнопка была отпущена
    else if ((buttons & IN_JUMP) && !(g_iLastButtons[client] & IN_JUMP)) {
        // Разрешаем 2 дополнительных прыжка в воздухе (в сумме 3)
        if (g_iJumps[client] < 2) {
            g_iJumps[client]++;
            
            float currentVel[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentVel);
            currentVel[2] = 260.0; // Высота стандартного прыжка CS:GO
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentVel);
        }
    }
    
    g_iLastButtons[client] = buttons;
    return Plugin_Continue;
}