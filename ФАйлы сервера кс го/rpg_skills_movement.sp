// ==============================================================================
// МОДУЛЬ 3: ПЕРЕДВИЖЕНИЕ И ПРЫЖКИ (rpg_skills_movement.sp)
// Навыки: speed, grav, long_jmp, climber, heavy_jmp
// ==============================================================================

#include <sourcemod>
#include <sdktools>

int g_iLastFlagsMove[MAXPLAYERS + 1];
bool g_bWasInAir[MAXPLAYERS + 1];
float g_fFallVelocity[MAXPLAYERS + 1];

// ПРЕДОХРАНИТЕЛЬ ДЛЯ ПРЫЖКА
bool g_bDidJumpBoost[MAXPLAYERS + 1];
// КЕШ СКОРОСТИ И ГРАВИТАЦИИ
float g_fSpeedCache[MAXPLAYERS + 1];
float g_fGravCache[MAXPLAYERS + 1];

void Movement_OnPlayerSpawn(int client) {
    if (IsPlayerAlive(client)) {
        g_bWasInAir[client] = false;
        g_fFallVelocity[client] = 0.0;
        g_bDidJumpBoost[client] = false;
        
        // Ждем загрузки профиля, чтобы статы не обнулились
        CreateTimer(0.2, Timer_WaitRPG_Movement, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_WaitRPG_Movement(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return Plugin_Stop;

    if (g_bLoaded[client]) {
        Movement_ApplyStatsFromItems(client);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

void Movement_OnWeaponSwitchPost(int client, int weapon) {
    #pragma unused weapon
    if (IsPlayerAlive(client)) {
        // Задержка 0.1 сек, потому что CS:GO сбрасывает скорость не сразу после смены оружия
        CreateTimer(0.1, Timer_ApplyWeaponSpeed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_ApplyWeaponSpeed(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client) && IsPlayerAlive(client)) {
        Movement_ApplyStatsFromItems(client);
    }
    return Plugin_Stop;
}

// Рассчитывает значения скорости и гравитации
void Movement_ApplyStatsFromItems(int client) { 
    if (!IsPlayerAlive(client) || !g_bLoaded[client]) return;

    // --- 1. СКОРОСТЬ ---
    int spdLvl = GetSkillLevel(client, "speed");      
    float spdPower = GetSkillPower("speed");
    if (spdPower <= 0.0) spdPower = 0.8; 

    float rpgSpeedBonus = (float(spdLvl) * spdPower) / 100.0;
    float itemSpeedBonus = g_fItem_SpeedPct[client] / 100.0;
    
    g_fSpeedCache[client] = 1.0 + rpgSpeedBonus + itemSpeedBonus;

    // --- 2. ГРАВИТАЦИЯ ---
    int gLvl = GetSkillLevel(client, "grav"); 
    float gravPower = GetSkillPower("grav");
    if (gravPower <= 0.0) gravPower = 5.0; 

    float rpgGravReduction = (float(gLvl) * gravPower) / 800.0;
    float itemGravReduction = g_fItem_GravityFlat[client] / 800.0;
    
    g_fGravCache[client] = 1.0 - rpgGravReduction - itemGravReduction;

    // Лимиты безопасности
    if (g_fGravCache[client] < 0.1) g_fGravCache[client] = 0.1; 
    if (g_fGravCache[client] > 1.0) g_fGravCache[client] = 1.0;

    // ПРИНУДИТЕЛЬНО ПРИМЕНЯЕМ СРАЗУ
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeedCache[client]);
    SetEntityGravity(client, g_fGravCache[client]);
}

// Главная функция, которая вызывается каждый игровой тик
public void Movement_OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    #pragma unused impulse, angles, weapon, subtype, cmdnum, tickcount, seed, mouse
    
    if (!IsPlayerAlive(client) || !g_bLoaded[client]) return;
    int flags = GetEntityFlags(client);

    // ==============================================================================
    // ВЫЗОВ ИЗОЛИРОВАННОГО БЛОКА ФИЗИКИ И АНТИТРЯСКИ (ПЕРЕДАЕМ vel)
    // ==============================================================================
    AntiShake_ProcessJump(client, buttons, flags, vel);

    // --- СКАЛОЛАЗ ---
    if (GetEntityMoveType(client) == MOVETYPE_LADDER) {
        int climbLvl = GetSkillLevel(client, "climber");
        if (climbLvl > 0) {
            float climbPwr = GetSkillPower("climber");
            if (climbPwr <= 0.0) climbPwr = 1.0;

            float climbMult = 1.0 + ((float(climbLvl) * climbPwr) / 100.0);
            vel[0] *= climbMult;
            vel[1] *= climbMult;
        }
    }

    // --- ТЯЖЕЛЫЙ ПРЫЖОК ---
    float currentZVel = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
    bool bIsOnGround = (flags & FL_ONGROUND) != 0;
    
    if (!bIsOnGround) {
        g_bWasInAir[client] = true;
        if (currentZVel < g_fFallVelocity[client]) {
            g_fFallVelocity[client] = currentZVel;
        }
    } 
    else if (bIsOnGround && g_bWasInAir[client]) {
        int heavyLvl = GetSkillLevel(client, "heavy_jmp");
        if (heavyLvl > 0 && g_fFallVelocity[client] < -300.0) {
            float heavyPwr = GetSkillPower("heavy_jmp");
            if (heavyPwr <= 0.0) heavyPwr = 1.0;

            float fallDmg = float(heavyLvl) * heavyPwr;
            float myPos[3]; 
            GetClientAbsOrigin(client, myPos);
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client)) {
                    float targetPos[3];
                    GetClientAbsOrigin(i, targetPos);
                    
                    if (GetVectorDistance(myPos, targetPos) <= 250.0) {
                        SDKHooks_TakeDamage(i, client, client, fallDmg, DMG_CRUSH);
                    }
                }
            }
        }
        g_bWasInAir[client] = false;
        g_fFallVelocity[client] = 0.0;
    }

    g_iLastFlagsMove[client] = flags;
}

// ==============================================================================
// ИЗОЛИРОВАННАЯ ФУНКЦИЯ: ФИКС ТРЯСКИ В ВОЗДУХЕ И СИНХРОНИЗАЦИЯ ФИЗИКИ
// ==============================================================================
void AntiShake_ProcessJump(int client, int buttons, int flags, float vel[3]) {
    bool bIsOnGround = (flags & FL_ONGROUND) != 0;
    bool bWasOnGround = (g_iLastFlagsMove[client] & FL_ONGROUND) != 0;

    // 1. ПЛАВНАЯ СКОРОСТЬ
    if (g_fSpeedCache[client] > 0.0) {
        float currentSpeed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
        if (currentSpeed != g_fSpeedCache[client]) {
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeedCache[client]);
        }
    }

    // 2. ПЛАВНАЯ ГРАВИТАЦИЯ
    if (g_fGravCache[client] > 0.0) {
        float currentGrav = GetEntityGravity(client);
        if (currentGrav != g_fGravCache[client]) {
            SetEntityGravity(client, g_fGravCache[client]);
        }
    }

    // 3. СБРОС ПРЕДОХРАНИТЕЛЯ
    if (bIsOnGround) {
        g_bDidJumpBoost[client] = false;
    }

    // 4. ДЛИННЫЙ ПРЫЖОК (Гладкий метод через vel и TeleportEntity)
    int ljLvl = GetSkillLevel(client, "long_jmp");
    if (!bIsOnGround && bWasOnGround && (buttons & IN_JUMP) && !g_bDidJumpBoost[client]) {
        
        float ljPwr = GetSkillPower("long_jmp");
        if (ljPwr <= 0.0) ljPwr = 1.0;

        float jumpMult = 1.0 + ((float(ljLvl) * ljPwr) / 100.0) + (g_fItem_JumpPower[client] / 100.0);
        if (jumpMult > 1.0) {
            float vecVelocity[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVelocity);
            
            vecVelocity[0] *= jumpMult;
            vecVelocity[1] *= jumpMult;
            
            // Лимит скорости, чтобы сервер не крашнулся
            float speedXY = SquareRoot(vecVelocity[0]*vecVelocity[0] + vecVelocity[1]*vecVelocity[1]);
            if (speedXY > 3500.0) {
                float reduce = 3500.0 / speedXY;
                vecVelocity[0] *= reduce;
                vecVelocity[1] *= reduce;
            }

            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
            g_bDidJumpBoost[client] = true;
        }
    }
}