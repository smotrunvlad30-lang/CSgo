// ==============================================================================
// МОДУЛЬ 7: СКРЫТНОСТЬ И УЛЬТИМЕЙТЫ (rpg_skills_all.sp)
// Навыки: swap, rat, invis, ninja, spy, kamikaze, thanos, phoenix, holy_touch, mirror
// ==============================================================================

// Эта функция запускается один раз при старте сервера
void AllSkills_OnPluginStart() {
    // Нам не нужно хукать гранаты, так как они в 6-м модуле. 
    // Здесь мы просто будем использовать хук урона и таймеры.
}

// Вызывается, когда игрок заходит на сервер
void AllSkills_OnClientPutInServer(int client) {
    // Подключаем перехват урона, чтобы ловить ультимейты
    SDKHook(client, SDKHook_OnTakeDamage, AllSkills_OnTakeDamage);
}

// Вызывается при спавне игрока
void AllSkills_OnPlayerSpawn(int client) {
    // При спавне обновляем прозрачность (если куплена невидимость)
    AllSkills_UpdateInvis(client);
}

// --- ЛОГИКА ПРОЗРАЧНОСТИ ---
void AllSkills_UpdateInvis(int client) {
    int lvl = GetSkillLevel(client, "invis"); //[cite: 36]
    int alpha = 255; // 255 = полностью видимый
    
    if (lvl > 0) {
        float pwr = GetSkillPower("invis"); //[cite: 36]
        alpha = RoundToFloor(255.0 * (1.0 - (float(lvl) * pwr)));
        
        // Ставим лимит, чтобы игрок не стал 100% невидимым
        if (alpha < 30) alpha = 30; 
        
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, 255, 255, 255, alpha);
    } else {
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
}

// --- ЕЖЕСЕКУНДНЫЙ ЦИКЛ (Вызывается из rpg_core.sp) ---
void AllSkills_OnTick(int client) {
    if (!IsPlayerAlive(client)) return;

    // Навык: Ниндзя (Прозрачность при приседании)[cite: 36]
    if (GetSkillLevel(client, "ninja") > 0) {
        // Проверяем, нажата ли кнопка приседания (CTRL)
        if (GetClientButtons(client) & IN_DUCK) {
            SetEntityRenderMode(client, RENDER_TRANSCOLOR);
            SetEntityRenderColor(client, 255, 255, 255, 15); // Делаем почти полностью прозрачным
        } else {
            // Если встал — возвращаем обычную невидимость
            AllSkills_UpdateInvis(client); 
        }
    }
}

// --- ПЕРЕХВАТ УРОНА (Тут работают Ульты) ---
public Action AllSkills_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker)) return Plugin_Continue;
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return Plugin_Continue;
    if (attacker == victim) return Plugin_Continue;

    // 1. ЩЕЛЧОК ТАНОСА (Шанс убить одним ударом)[cite: 36]
    int thanosLvl = GetSkillLevel(attacker, "thanos");
    if (thanosLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(thanosLvl) * GetSkillPower("thanos"))) {
        damage = 99999.0;
        PrintToChat(attacker, "[\x04RPG\x01] \x02Вы использовали ЩЕЛЧОК ТАНОСА!");
        return Plugin_Changed;
    }

    // 2. СМЕНА ПОЗИЦИЙ (Swap)[cite: 36]
    int swapLvl = GetSkillLevel(victim, "swap");
    if (swapLvl > 0 && GetRandomFloat(0.0, 100.0) <= (float(swapLvl) * GetSkillPower("swap"))) {
        float vPos[3], aPos[3];
        GetClientAbsOrigin(victim, vPos);
        GetClientAbsOrigin(attacker, aPos);
        
        // Меняем местами
        TeleportEntity(victim, aPos, NULL_VECTOR, NULL_VECTOR);
        TeleportEntity(attacker, vPos, NULL_VECTOR, NULL_VECTOR);
        PrintToChat(victim, "[\x04RPG\x01] Вы поменялись местами с врагом!");
    }

    // 3. КРЫСА (ТП к врагу при атаке сидя)[cite: 36]
    int ratLvl = GetSkillLevel(attacker, "rat");
    if (ratLvl > 0 && (GetClientButtons(attacker) & IN_DUCK)) {
        if (GetRandomFloat(0.0, 100.0) <= (float(ratLvl) * GetSkillPower("rat"))) {
            float vPos[3]; GetClientAbsOrigin(victim, vPos);
            TeleportEntity(attacker, vPos, NULL_VECTOR, NULL_VECTOR);
            PrintToChat(attacker, "[\x04RPG\x01] Навык Крыса перенес вас к врагу!");
        }
    }

    // 4. ЗЕРКАЛО (Отражение урона)[cite: 36]
    int mirrorLvl = GetSkillLevel(victim, "mirror");
    if (mirrorLvl > 0 && !(damagetype & DMG_POISON)) { // Проверяем, чтобы зеркало не отражало яд (иначе будет бесконечный цикл)
        if (GetRandomFloat(0.0, 100.0) <= 50.0) { // Шанс 50%[cite: 36]
            float reflectMult = float(mirrorLvl) * GetSkillPower("mirror"); //[cite: 36]
            float reflectDmg = damage * reflectMult;
            SDKHooks_TakeDamage(attacker, victim, victim, reflectDmg, DMG_POISON);
        }
    }

    // 5. ПЕПЕЛ ФЕНИКСА (Бессмертие при смертельном ударе)[cite: 36]
    int phoenixLvl = GetSkillLevel(victim, "phoenix");
    if (phoenixLvl > 0 && damage >= GetClientHealth(victim)) { // Если удар смертельный
        if (GetRandomFloat(0.0, 100.0) <= 40.0) { // Шанс 40%[cite: 36]
            // Отменяем урон
            damage = 0.0;
            
            // Лечим жертву на половину ХП
            int maxHp = GetMaxHealth(victim);
            SetEntityHealth(victim, maxHp / 2);
            
            // Наносим урон атакующему равный ХП Феникса
            SDKHooks_TakeDamage(attacker, victim, victim, float(maxHp / 2), DMG_BLAST);
            
            PrintToChat(victim, "[\x04RPG\x01] \x0CПепел Феникса спас вас от смерти!");
            return Plugin_Changed;
        }
    }

    // 6. СВЯТОЕ КАСАНИЕ (Игнор урона + Инвиз + Клон)[cite: 36]
    int holyLvl = GetSkillLevel(victim, "holy_touch");
    if (holyLvl > 0 && GetRandomFloat(0.0, 100.0) <= 30.0) { // Шанс 30%[cite: 36]
        // Делаем игрока полностью невидимым на 2 секунды
        SetEntityRenderMode(victim, RENDER_TRANSCOLOR);
        SetEntityRenderColor(victim, 255, 255, 255, 0);
        CreateTimer(2.0, Timer_RestoreHolyInvis, GetClientUserId(victim));
        
        // Создаем клона
        float pos[3], ang[3];
        GetClientAbsOrigin(victim, pos);
        GetClientEyeAngles(victim, ang);
        ang[0] = 0.0; // Чтобы клон стоял ровно

        int clone = CreateEntityByName("prop_dynamic_override");
        if (IsValidEntity(clone)) {
            char model[128]; GetClientModel(victim, model, sizeof(model));
            SetEntityModel(clone, model);
            DispatchSpawn(clone);
            TeleportEntity(clone, pos, ang, NULL_VECTOR);
            
            // Удаляем клона через 2 секунды
            CreateTimer(2.0, Timer_RemoveHolyClone, EntIndexToEntRef(clone));
        }

        PrintToChat(victim, "[\x04RPG\x01] Святое касание активировано!");
        return Plugin_Handled; // Полностью блокируем этот урон
    }

    return Plugin_Continue;
}

// --- СОБЫТИЯ СМЕРТИ (Камикадзе и Шпион) ---
void AllSkills_OnPlayerDeath(int victim, int attacker) {
    
    // Навык: Камикадзе (Взрыв после смерти)[cite: 36]
    int kamLvl = GetSkillLevel(victim, "kamikaze");
    if (kamLvl > 0) {
        float pos[3]; GetClientAbsOrigin(victim, pos);
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(victim)) {
                float tPos[3]; GetClientAbsOrigin(i, tPos);
                if (GetVectorDistance(pos, tPos) <= 400.0) { // Радиус 400[cite: 36]
                    float dmg = float(kamLvl) * GetSkillPower("kamikaze"); //[cite: 36]
                    SDKHooks_TakeDamage(i, victim, victim, dmg, DMG_BLAST);
                }
            }
        }
    }
    
    // Навык: Шпион (Кража модели)[cite: 36]
    int spyLvl = GetSkillLevel(attacker, "spy");
    if (attacker > 0 && spyLvl > 0 && GetRandomFloat(0.0, 100.0) <= float(spyLvl)) {
        char model[128]; 
        GetEntPropString(victim, Prop_Data, "m_ModelName", model, sizeof(model));
        SetEntityModel(attacker, model);
        PrintToChat(attacker, "[\x04RPG\x01] Вы украли внешность врага!");
    }
}

// --- ТАЙМЕРЫ ---
public Action Timer_RestoreHolyInvis(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) {
        // Возвращаем обычную прозрачность (с учетом навыка Invis)
        AllSkills_UpdateInvis(client);
    }
    return Plugin_Stop;
}

public Action Timer_RemoveHolyClone(Handle timer, any entRef) {
    int ent = EntRefToEntIndex(entRef);
    if (ent > 0 && IsValidEntity(ent)) {
        AcceptEntityInput(ent, "Kill");
    }
    return Plugin_Stop;
}