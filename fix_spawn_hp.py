import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

spawn_old = r'public Action Event_PlayerSpawn\(Event event, const char\[\] name, bool dontBroadcast\) \{.*?(?=void EndBossFight)'
spawn_new = """public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_bBossActive && client == g_iBossClient) {
        StripAllWeapons(client);
        GivePlayerItem(client, "weapon_knife");
        SetEntityModel(client, g_sBossModel);

        // CS:GO сбрасывает ХП до 100 при спавне игрока/бота.
        // Принудительно ставим огромное количество ХП сразу после спавна,
        // чтобы бот не умирал с 1 пули.
        SetEntityHealth(client, 9999999);
    }
    return Plugin_Continue;
}

"""
content = re.sub(spawn_old, spawn_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
