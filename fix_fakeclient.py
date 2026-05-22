import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Fix SpawnBossBot
spawn_old = r'void SpawnBossBot\(int rarity\) \{.*?(?=public Action Timer_RenameBot)'
spawn_new = """void SpawnBossBot(int rarity) {
    if (g_bBossActive) return;

    g_bBossActive = true;
    g_iBossRarity = rarity;

    int bot = CreateFakeClient("THANOS_BOSS");
    if (bot > 0) {
        CreateTimer(0.2, Timer_RenameBot, GetClientUserId(bot));
    } else {
        g_bBossActive = false;
        PrintToServer("[RPG Boss] Ошибка CreateFakeClient()!");
    }
}"""
content = re.sub(spawn_old, spawn_new + "\n\n", content, flags=re.DOTALL)

# Fix Timer_RenameBot to match original Timer_SetupBot logic
timer_old = r'public Action Timer_RenameBot\(Handle timer\) \{.*?(?=void SetupBoss)'
timer_new = """public Action Timer_RenameBot(Handle timer, any userid) {
    int bot = GetClientOfUserId(userid);
    if (bot > 0 && IsClientInGame(bot)) {
        CS_SwitchTeam(bot, CS_TEAM_T);
        CS_RespawnPlayer(bot);
        g_iBossClient = bot;
        SetupBoss(bot);
    }
    return Plugin_Stop;
}"""
content = re.sub(timer_old, timer_new + "\n\n", content, flags=re.DOTALL)

# Fix EndBossFight (remove bot_kick and bot_quota logic)
end_old = r'void EndBossFight\(\) \{.*?(?=void HandleRewards)'
end_new = """void EndBossFight() {
    g_bBossActive = false;

    if (g_iBossClient != -1 && IsClientInGame(g_iBossClient)) {
        KickClient(g_iBossClient, "Танос повержен");
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

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
