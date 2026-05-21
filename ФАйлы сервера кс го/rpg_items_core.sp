// ==============================================================================
// МОДУЛЬ: ЭКИПИРОВКА И ПРЕДМЕТЫ (Читает JSON из БД и хранит статы)
// ==============================================================================

void Items_OnPluginStart() {
    // Ядро вызывает это при старте. Тут ничего хукать не нужно, все делает rpg_core.sp
}

// Вызывается при каждом спавне игрока
void Items_OnPlayerSpawn(int client) {
    if (client < 1 || !IsClientInGame(client)) return;
    
    // 1. Сбрасываем все старые бонусы перед загрузкой новых
    ResetItemStats(client);
    
    // 2. Запрашиваем из базы надетые предметы
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    
    char query[1024];
    // Соединяем инвентарь игрока со списком предметов, чтобы сразу получить stats_json
    Format(query, sizeof(query), 
        "SELECT l.stats_json FROM rpg_inventory i JOIN rpg_items_list l ON i.item_id = l.id WHERE i.steamid = '%s' AND i.is_equipped = 1", 
        sSteamID);
        
    if (g_DB != null) {
        g_DB.Query(SQL_Callback_LoadItems, query, GetClientUserId(client));
    }
}

public void SQL_Callback_LoadItems(Database db, DBResultSet results, const char[] error, any data) {
    int client = GetClientOfUserId(data);
    if (client == 0 || !IsClientInGame(client) || results == null || error[0] != '\0') return;

    // Читаем все надетые шмотки
    while (results.FetchRow()) {
        char jsonString[2048];
        results.FetchString(0, jsonString, sizeof(jsonString));
        
        // Парсим JSON строку и плюсуем статы игроку
        ParseItemStats(client, jsonString);
    }
    
    // После загрузки предметов, просим модуль здоровья обновить макс ХП и Броню
    Health_ApplyStatsFromItems(client);
    Movement_ApplyStatsFromItems(client);
}

// ==============================================================================
// НАШ КАСТОМНЫЙ ПАРСЕР JSON (Без сторонних плагинов)
// ==============================================================================
void ParseItemStats(int client, const char[] jsonString) {
    if (strlen(jsonString) < 5) return; // Пустая строка или битый JSON

    char buffer[2048];
    strcopy(buffer, sizeof(buffer), jsonString);

    // Очищаем JSON от лишних символов: оставляем только ключи и значения
    ReplaceString(buffer, sizeof(buffer), "{", "");
    ReplaceString(buffer, sizeof(buffer), "}", "");
    ReplaceString(buffer, sizeof(buffer), "\"", "");
    ReplaceString(buffer, sizeof(buffer), " ", ""); 

    // Теперь строка выглядит так: hp_flat:50.0,dmg_pct:10.0,burn_chance:15.0
    char pairs[35][64]; // До 35 параметров
    int count = ExplodeString(buffer, ",", pairs, sizeof(pairs), sizeof(pairs[]));

    for (int i = 0; i < count; i++) {
        char kv[2][32];
        if (ExplodeString(pairs[i], ":", kv, sizeof(kv), sizeof(kv[])) == 2) {
            char key[32];
            strcopy(key, sizeof(key), kv[0]);
            float val = StringToFloat(kv[1]);

            // Плюсуем характеристику к общей сумме игрока
            if (StrEqual(key, "hp_flat")) g_fItem_HpFlat[client] += val;
            else if (StrEqual(key, "hp_pct")) g_fItem_HpPct[client] += val;
            else if (StrEqual(key, "dmg_flat")) g_fItem_DmgFlat[client] += val;
            else if (StrEqual(key, "dmg_pct")) g_fItem_DmgPct[client] += val;
            else if (StrEqual(key, "armor_flat")) g_fItem_ArmorFlat[client] += val;
            else if (StrEqual(key, "armor_pct")) g_fItem_ArmorPct[client] += val;
            else if (StrEqual(key, "speed_pct")) g_fItem_SpeedPct[client] += val;
            else if (StrEqual(key, "gravity_flat")) g_fItem_GravityFlat[client] += val;
            else if (StrEqual(key, "crit_chance")) g_fItem_CritChance[client] += val;
            else if (StrEqual(key, "vampirism")) g_fItem_Vampirism[client] += val;
            else if (StrEqual(key, "low_hp_bonus")) g_fItem_LowHpBonus[client] += val;
            else if (StrEqual(key, "full_hp_bonus")) g_fItem_FullHpBonus[client] += val;
            else if (StrEqual(key, "bonus_credits")) g_fItem_BonusCredits[client] += val;
            else if (StrEqual(key, "bonus_xp")) g_fItem_BonusXp[client] += val;
            else if (StrEqual(key, "drop_chance")) g_fItem_DropChance[client] += val;
            else if (StrEqual(key, "rare_drop_chance")) g_fItem_RareDropChance[client] += val;
            else if (StrEqual(key, "reflect_chance")) g_fItem_ReflectChance[client] += val;
            else if (StrEqual(key, "slow_chance")) g_fItem_SlowChance[client] += val;
            else if (StrEqual(key, "heal_on_kill")) g_fItem_HealOnKill[client] += val;
            else if (StrEqual(key, "heal_on_hit")) g_fItem_HealOnHit[client] += val;
            else if (StrEqual(key, "hp_regen")) g_fItem_HpRegen[client] += val;
            else if (StrEqual(key, "push_chance")) g_fItem_PushChance[client] += val;
            else if (StrEqual(key, "stun_chance")) g_fItem_StunChance[client] += val;
            else if (StrEqual(key, "bleed_chance")) g_fItem_BleedChance[client] += val;
            else if (StrEqual(key, "burn_chance")) g_fItem_BurnChance[client] += val;
            else if (StrEqual(key, "jump_power")) g_fItem_JumpPower[client] += val;
            else if (StrEqual(key, "dmg_reduction")) g_fItem_DmgReduction[client] += val;
            else if (StrEqual(key, "block_chance")) g_fItem_BlockChance[client] += val;
            else if (StrEqual(key, "dodge_chance")) g_fItem_DodgeChance[client] += val;
            else if (StrEqual(key, "hs_bonus")) g_fItem_HsBonus[client] += val;
            else if (StrEqual(key, "backstab_bonus")) g_fItem_BackstabBonus[client] += val;
        }
    }
}

// ==============================================================================
// ЛОГИКА ПРЕДМЕТОВ
// ==============================================================================
void Items_OnTick(int client) {
    if (g_fItem_HpRegen[client] > 0.0 && GetGameTime() >= g_flNextItemRegenTick[client]) {
        HealPlayer(client, RoundToFloor(g_fItem_HpRegen[client]));
        g_flNextItemRegenTick[client] = GetGameTime() + 1.0;
    }
}

void Items_OnPlayerDeath(int victim, int attacker) {
    if (attacker > 0 && attacker <= MaxClients && attacker != victim) {
        if (g_fItem_HealOnKill[attacker] > 0.0) {
            HealPlayer(attacker, RoundToFloor(g_fItem_HealOnKill[attacker]));
        }
    }
}

void ResetItemStats(int client) {
    g_fItem_HpFlat[client] = 0.0;
    g_fItem_HpPct[client] = 0.0;
    g_fItem_DmgFlat[client] = 0.0;
    g_fItem_DmgPct[client] = 0.0;
    g_fItem_ArmorFlat[client] = 0.0;
    g_fItem_ArmorPct[client] = 0.0;
    g_fItem_SpeedPct[client] = 0.0;
    g_fItem_GravityFlat[client] = 0.0;
    g_fItem_CritChance[client] = 0.0;
    g_fItem_Vampirism[client] = 0.0;
    g_fItem_LowHpBonus[client] = 0.0;
    g_fItem_FullHpBonus[client] = 0.0;
    g_fItem_BonusCredits[client] = 0.0;
    g_fItem_BonusXp[client] = 0.0;
    g_fItem_DropChance[client] = 0.0;
    g_fItem_RareDropChance[client] = 0.0;
    g_fItem_ReflectChance[client] = 0.0;
    g_fItem_SlowChance[client] = 0.0;
    g_fItem_HealOnKill[client] = 0.0;
    g_fItem_HealOnHit[client] = 0.0;
    g_fItem_HpRegen[client] = 0.0;
    g_fItem_PushChance[client] = 0.0;
    g_fItem_StunChance[client] = 0.0;
    g_fItem_BleedChance[client] = 0.0;
    g_fItem_BurnChance[client] = 0.0;
    g_fItem_JumpPower[client] = 0.0;
    g_fItem_DmgReduction[client] = 0.0;
    g_fItem_BlockChance[client] = 0.0;
    g_fItem_DodgeChance[client] = 0.0;
    g_fItem_HsBonus[client] = 0.0;
    g_fItem_BackstabBonus[client] = 0.0;
}