import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Fix SpawnBossBot
spawn_new = """void SpawnBossBot(int rarity) {
    if (g_bBossActive) return;

    g_bBossActive = true;
    g_iBossRarity = rarity;
    g_iBossClient = -1;

    // Спавним бота
    ServerCommand("bot_quota_mode normal");
    int currentQuota = GetConVarInt(FindConVar("bot_quota"));
    SetConVarInt(FindConVar("bot_quota"), currentQuota + 1);
    ServerCommand("bot_add_t");

    CreateTimer(1.0, Timer_RenameBot, _, TIMER_REPEAT);
}"""
content = re.sub(r'void SpawnBossBot\(int rarity\) \{.*?(?=public Action Timer_RenameBot)', spawn_new + "\n\n", content, flags=re.DOTALL)


# Fix EndBossFight to properly kick and reduce quota
end_new = """void EndBossFight() {
    g_bBossActive = false;

    if (g_iBossClient != -1 && IsClientInGame(g_iBossClient)) {
        KickClient(g_iBossClient, "Танос повержен");
    }
    g_iBossClient = -1;

    int currentQuota = GetConVarInt(FindConVar("bot_quota"));
    if (currentQuota > 0) SetConVarInt(FindConVar("bot_quota"), currentQuota - 1);

    if (g_hHudTimer != null) { KillTimer(g_hHudTimer); g_hHudTimer = null; }
    if (g_hRespawnTimer != null) { KillTimer(g_hRespawnTimer); g_hRespawnTimer = null; }
    if (g_hSkillTimer != null) { KillTimer(g_hSkillTimer); g_hSkillTimer = null; }
    if (g_hWarningTimer != null) { KillTimer(g_hWarningTimer); g_hWarningTimer = null; }
    ServerCommand("mp_ignore_round_win_conditions 0");
    CS_TerminateRound(5.0, CSRoundEnd_CTWin);
}"""
content = re.sub(r'void EndBossFight\(\) \{.*?(?=void HandleRewards)', end_new + "\n\n", content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
