// ==============================================================================
// МОДУЛЬ 5: ФАРМ И ОПЫТ (rpg_skills_farm.sp)
// Навыки: blood_drain, farm_duals, farm_knife, wise_knife, farm_mag7, farm_zeus, wise_zeus
// ==============================================================================

void Farm_OnPlayerDeath(int attacker, int victim, const char[] weapon) {
    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker)) return;
    if (attacker == victim) return;

    // --- 1. НАВЫК: КРОВОСТОК (blood_drain) ДЛЯ ЖЕРТВЫ ---
    if (victim > 0 && IsClientInGame(victim)) {
        int bloodLvl = GetSkillLevel(victim, "blood_drain");
        if (bloodLvl > 0) {
            // Жертва получает опыт за то, что ее убили
            int expReward = RoundToFloor(float(bloodLvl) * GetSkillPower("blood_drain"));
            AddXP(victim, expReward, "Кровосток (Жертва)");

            // Убийца получает кровотечение (используем переменную и таймер из модуля атаки)
            g_flBleedTime[attacker] = GetEngineTime() + 5.0;
            CreateTimer(1.0, Timer_BleedTick, GetClientUserId(attacker), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            PrintToChat(attacker, "[\x04RPG\x01] Вы были прокляты Кровостоком!");
        }
    }

    // Получаем активное оружие в руках убийцы[cite: 24]
    char activeWeapon[64];
    GetClientWeapon(attacker, activeWeapon, sizeof(activeWeapon));

    // Узнаем множитель кредитов от надетых предметов с сайта (например, +10% = 1.10)
    float credMult = 1.0 + (g_fItem_BonusCredits[attacker] / 100.0);

    // --- 44. Счастливые беретты (farm_duals) ---
    // Срабатывает, если в руках Dual Berettas[cite: 24]
    int dualsLvl = GetSkillLevel(attacker, "farm_duals");
    if (dualsLvl > 0 && StrContains(activeWeapon, "elite") != -1) {
        int baseMoney = RoundToFloor(float(dualsLvl) * GetSkillPower("farm_duals"));
        int bonusMoney = RoundToFloor(float(baseMoney) * credMult); // Умножаем на бонус от вещей
        g_iMoney[attacker] += bonusMoney;
        PrintToChat(attacker, "[\x04RPG\x01] Счастливые беретты: \x04+%d$\x01", bonusMoney);
    }

    // --- 45 и 46. Золотой и Мудрый нож (farm_knife, wise_knife) ---
    // Ловим любые типы ножей[cite: 24]
    if (StrContains(weapon, "knife") != -1 || StrContains(weapon, "bayonet") != -1) {
        
        // Золотой нож: Кредиты[cite: 24]
        int goldKnife = GetSkillLevel(attacker, "farm_knife");
        if (goldKnife > 0) {
            int baseMoney = RoundToFloor(float(goldKnife) * GetSkillPower("farm_knife"));
            int bonus = RoundToFloor(float(baseMoney) * credMult);
            g_iMoney[attacker] += bonus;
            PrintToChat(attacker, "[\x04RPG\x01] Золотой нож: \x04+%d$\x01", bonus);
        }
        
        // Мудрый нож: Опыт[cite: 24]
        int wiseKnife = GetSkillLevel(attacker, "wise_knife");
        if (wiseKnife > 0) {
            int bonusXp = RoundToFloor(float(wiseKnife) * GetSkillPower("wise_knife"));
            AddXP(attacker, bonusXp, "Мудрый нож");
        }
    }

    // --- 47. Золотой МАГ-7 (farm_mag7) ---
    if (StrContains(weapon, "mag7") != -1) {
        int goldMag = GetSkillLevel(attacker, "farm_mag7");
        if (goldMag > 0) {
            int baseMoney = RoundToFloor(float(goldMag) * GetSkillPower("farm_mag7"));
            int bonus = RoundToFloor(float(baseMoney) * credMult);
            g_iMoney[attacker] += bonus;
            PrintToChat(attacker, "[\x04RPG\x01] Золотой MAG-7: \x04+%d$\x01", bonus);
        }
    }

    // --- 48 и 49. Золотой и Мудрый зевс (farm_zeus, wise_zeus) ---
    // В CS:GO зевс пишется как "taser"[cite: 24]
    if (StrContains(weapon, "taser") != -1) {
        // Золотой Зевс: Кредиты[cite: 24]
        int goldZeus = GetSkillLevel(attacker, "farm_zeus");
        if (goldZeus > 0) {
            int baseMoney = RoundToFloor(float(goldZeus) * GetSkillPower("farm_zeus"));
            int bonus = RoundToFloor(float(baseMoney) * credMult);
            g_iMoney[attacker] += bonus;
            PrintToChat(attacker, "[\x04RPG\x01] Золотой Zeus: \x04+%d$\x01", bonus);
        }
        
        // Мудрый Зевс: Опыт[cite: 24]
        int wiseZeus = GetSkillLevel(attacker, "wise_zeus");
        if (wiseZeus > 0) {
            int bonusXp = RoundToFloor(float(wiseZeus) * GetSkillPower("wise_zeus"));
            AddXP(attacker, bonusXp, "Мудрый Zeus");
        }
    }
}