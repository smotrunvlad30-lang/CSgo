// ==============================================================================
// МОДУЛЬ 4: АУРЫ И КОНТРОЛЬ ТЕРРИТОРИИ (rpg_skills_auras.sp)
// Навыки: spikes (Колючие шипы), barier (Барьер), slow_aura (Замедление)
// ==============================================================================

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Цвета для визуализации аур (Красный, Белый, Синий)
int G_ColorRed[] = {255, 0, 0, 255};
int G_ColorWhite[] = {255, 255, 255, 255};
int G_ColorBlue[] = {0, 150, 255, 255};

void Auras_OnPluginStart() {
    // Регистрируем команды для отрисовки кругов
    RegConsoleCmd("sm_spikes", Cmd_ShowSpikesRadius, "Показать радиус шипов");
    RegConsoleCmd("sm_barier", Cmd_ShowBarierRadius, "Показать радиус барьера");
    RegConsoleCmd("sm_slow", Cmd_ShowSlowRadius, "Показать радиус замедления");
}

// ------------------------------------------------------------------------------
// ФУНКЦИИ ВИЗУАЛИЗАЦИИ
// ------------------------------------------------------------------------------
public Action Cmd_ShowSpikesRadius(int client, int args) { 
    if(GetSkillLevel(client, "spikes") > 0) ShowAuraVisual(client, 110.0, G_ColorRed);
    return Plugin_Handled; 
}
public Action Cmd_ShowBarierRadius(int client, int args) { 
    if(GetSkillLevel(client, "barier") > 0) ShowAuraVisual(client, 160.0, G_ColorWhite);
    return Plugin_Handled; 
}
public Action Cmd_ShowSlowRadius(int client, int args) { 
    if(GetSkillLevel(client, "slow_aura") > 0) ShowAuraVisual(client, 180.0, G_ColorBlue);
    return Plugin_Handled; 
}

void ShowAuraVisual(int client, float radius, int color[4]) {
    if (IsPlayerAlive(client)) {
        float pos[3];
        GetClientAbsOrigin(client, pos);
        pos[2] += 5.0; // Слегка приподнимаем круг над землей
        
        // Рисуем лазерное кольцо
        TE_SetupBeamRingPoint(pos, 10.0, radius * 2.0, PrecacheModel("materials/sprites/laserbeam.vmt"), 0, 0, 0, 3.0, 2.0, 0.0, color, 10, 0);
        TE_SendToAll();
        PrintToChat(client, "[\x04RPG\x01] Вы визуализировали радиус ауры!");
    }
}

// ------------------------------------------------------------------------------
// ГЛАВНЫЙ ЦИКЛ АУР (Вызывается каждую секунду или тик из rpg_core.sp)
// ------------------------------------------------------------------------------
void Auras_OnTick(int client) {
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) return;

    int shipLvl = GetSkillLevel(client, "spikes");
    int barLvl  = GetSkillLevel(client, "barier");
    int slowLvl = GetSkillLevel(client, "slow_aura");

    // Если у игрока не прокачана ни одна аура — не тратим ресурсы сервера
    if (shipLvl <= 0 && barLvl <= 0 && slowLvl <= 0) return;

    float myPos[3], targetPos[3];
    GetClientAbsOrigin(client, myPos);

    for (int i = 1; i <= MaxClients; i++) {
        // ЖЕСТКАЯ ЗАЩИТА: Аура никогда не бьет своего владельца!
        if (i == client) continue;

        // Ищем живых врагов (на случай FFA серверов, i != client спасает)
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client)) {
            GetClientAbsOrigin(i, targetPos);
            float dist = GetVectorDistance(myPos, targetPos);

            // 1. КОЛЮЧИЕ ШИПЫ (Урон раз в 3 секунды, дистанция 110)
            if (shipLvl > 0 && dist <= 110.0 && (g_iTickCount % 3 == 0)) {
                
                // КОНТР-НАВЫК: Проверяем "Ловкость" у жертвы
                int agiLvl = GetSkillLevel(i, "agility"); 
                float dodgeChance = 0.0;
                
                if (agiLvl > 0) {
                    float agiPwr = GetSkillPower("agility");
                    if (agiPwr <= 0.0) agiPwr = 1.0; // 1% шанса уклониться за каждый лвл ловкости
                    dodgeChance = float(agiLvl) * agiPwr;
                }

                // Проверяем, уклонился ли враг
                bool bDodged = false;
                if (dodgeChance > 0.0 && GetRandomFloat(0.0, 100.0) <= dodgeChance) {
                    bDodged = true; // Враг оказался слишком ловким!
                }

                if (!bDodged) {
                    // Урон: +5 за каждый уровень (можно изменить через конфиг)
                    float dmgPwr = GetSkillPower("spikes");
                    if (dmgPwr <= 0.0) dmgPwr = 5.0; 

                    float dmg = float(shipLvl) * dmgPwr;
                    
                    // DMG_SLASH = Физический урон от шипов
                    SDKHooks_TakeDamage(i, client, client, dmg, DMG_SLASH);
                }
            }

            // 2. БАРЬЕР (Отталкивание раз в 2 секунды)
            if (barLvl > 0 && dist <= 160.0 && (g_iTickCount % 2 == 0)) {
                char weapon[32];
                GetClientWeapon(i, weapon, sizeof(weapon));
                if (IsBarierWeapon(weapon)) {
                    PushPlayerAway(client, i, float(barLvl) * 20.0);
                }
            }

            // 3. ЗАМЕДЛЕНИЕ (Постоянное действие)
            if (slowLvl > 0) {
                if (dist <= 180.0) {
                    float pwr = GetSkillPower("slow_aura");
                    if (pwr <= 0.0) pwr = 1.0;
                    float slowFactor = 1.0 - (float(slowLvl) * pwr / 100.0);
                    
                    // Не даем заморозить врага полностью (минимум 10% скорости)
                    if (slowFactor < 0.1) slowFactor = 0.1;
                    SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", slowFactor);
                } else {
                    // Если враг вышел из радиуса ауры, возвращаем ему ЕГО законную скорость
                    float currentSpeed = GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue");
                    if (currentSpeed < 1.0) {
                        float baseSpeed = 1.0 + (float(GetSkillLevel(i, "speed")) * GetSkillPower("speed") / 100.0);
                        float finalSpeed = baseSpeed * (1.0 + (g_fItem_SpeedPct[i] / 100.0));
                        
                        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", finalSpeed);
                    }
                }
            }
        }
    }
}

// ------------------------------------------------------------------------------
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ------------------------------------------------------------------------------
bool IsBarierWeapon(const char[] weapon) {
    // Список оружия, которое отталкивает Барьер
    return (StrContains(weapon, "knife") != -1 || StrContains(weapon, "shotgun") != -1 || 
            StrContains(weapon, "xm1014") != -1 || StrContains(weapon, "cz75a") != -1 || 
            StrContains(weapon, "tec9") != -1 || StrContains(weapon, "elite") != -1 || 
            StrContains(weapon, "taser") != -1 || StrContains(weapon, "grenade") != -1 ||
            StrContains(weapon, "molotov") != -1 || StrContains(weapon, "smoke") != -1);
}

void PushPlayerAway(int owner, int victim, float force) {
    float pos1[3], pos2[3], vel[3];
    GetClientAbsOrigin(owner, pos1);
    GetClientAbsOrigin(victim, pos2);
    
    // Вычисляем вектор направления от хозяина ауры к жертве
    MakeVectorFromPoints(pos1, pos2, vel);
    NormalizeVector(vel, vel);
    
    ScaleVector(vel, force + 300.0); // Толкаем
    vel[2] = 200.0; // Слегка подбрасываем вверх, чтобы трение о землю не мешало отлету
    
    TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vel);
}