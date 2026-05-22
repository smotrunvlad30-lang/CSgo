import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

snap_old = r'void Skill_Snap\(\) \{.*?(?=void Skill_CosmicRift)'
snap_new = """void Skill_Snap() {
    PrintToChatAll(" \\x04[Танос] \\x02*Щелчок*");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            // 50% шанс мгновенной смерти для каждого игрока
            if (GetRandomInt(1, 2) == 1) {
                float pPos[3]; GetClientAbsOrigin(i, pPos);
                TE_SetupSmoke(pPos, g_iSmokeModel, 50.0, 5); TE_SendToAll();

                // Убиваем игрока
                SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 9999999.0, DMG_DISSOLVE);
            }
        }
    }
}"""

content = re.sub(snap_old, snap_new + "\n\n", content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
