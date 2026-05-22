import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove the #include "rpg_boss_drops.inc"
content = content.replace('#include "rpg_boss_drops.inc"', '')

# 2. Fix the bot spawning logic to avoid "CreateBot() failed"
spawn_old = r'void SpawnBossBot\(int rarity\) \{.*?(?=public Action Timer_RenameBot)'
spawn_new = """void SpawnBossBot(int rarity) {
    if (g_bBossActive) return;

    g_bBossActive = true;
    g_iBossRarity = rarity;
    g_iBossClient = -1;

    // Безопасный спавн бота
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_join_after_player 0");
    ServerCommand("bot_add_t");

    CreateTimer(1.5, Timer_RenameBot, _, TIMER_REPEAT);
}"""
content = re.sub(spawn_old, spawn_new + "\n\n", content, flags=re.DOTALL)


# 3. Fix EndBossFight to properly kick the bot without touching bot_quota directly
end_old = r'void EndBossFight\(\) \{.*?(?=void HandleRewards)'
end_new = """void EndBossFight() {
    g_bBossActive = false;

    if (g_iBossClient != -1 && IsClientInGame(g_iBossClient)) {
        ServerCommand("bot_kick %s", g_sBossName);
    }
    g_iBossClient = -1;

    if (g_hHudTimer != null) { KillTimer(g_hHudTimer); g_hHudTimer = null; }
    if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
    if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }
    if (g_hWarningTimer != null) { KillTimer(g_hWarningTimer); g_hWarningTimer = null; }
    ServerCommand("mp_ignore_round_win_conditions 0");
    CS_TerminateRound(5.0, CSRoundEnd_CTWin);
}"""
content = re.sub(end_old, end_new + "\n\n", content, flags=re.DOTALL)


# 4. Fix Skill_Snap to NEVER kill (if HP > 2)
snap_old = r'void Skill_Snap\(\) \{.*?(?=void Skill_CosmicRift)'
snap_new = """void Skill_Snap() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            if (GetRandomInt(1, 2) == 1) {
                int hp = GetClientHealth(i);
                if (hp > 2) {
                    SetEntityHealth(i, hp / 2);
                }
                float pPos[3]; GetClientAbsOrigin(i, pPos);
                TE_SetupSmoke(pPos, g_iSmokeModel, 50.0, 5); TE_SendToAll();
            }
        }
    }
}"""
content = re.sub(snap_old, snap_new + "\n\n", content, flags=re.DOTALL)

# 5. Inject a dynamic GetBossDropChance function at the very end of the file
get_drop_chance = """
float GetBossDropChance(int rarity) {
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rpg_boss_drops.txt");

    KeyValues kv = new KeyValues("BossDrops");
    if (!kv.ImportFromFile(path)) {
        delete kv;
        // Возвращаем дефолты если файла нет
        switch (rarity) {
            case 0: return 5.0;
            case 1: return 15.0;
            case 2: return 35.0;
            case 3: return 70.0;
        }
        return 1.0;
    }

    char key[16];
    Format(key, sizeof(key), "rarity_%d", rarity);
    float chance = kv.GetFloat(key, 1.0);
    delete kv;
    return chance;
}
"""
content += get_drop_chance

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
