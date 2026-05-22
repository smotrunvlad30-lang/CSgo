import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Reality: ClientCommand overlay is usually blocked by sv_cheats 0. Let's use standard CS:GO blind via m_flFlashDuration
reality_old = r'void Skill_Reality\(\) \{.*?(?=void Skill_MindControl)'
reality_new = """void Skill_Reality() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            // Ослепляем игроков на 7 секунд (Искажение реальности)
            SetEntPropFloat(i, Prop_Send, "m_flFlashDuration", 7.0);
            SetEntPropFloat(i, Prop_Send, "m_flFlashMaxAlpha", 255.0);
        }
    }
}
"""
content = re.sub(reality_old, reality_new, content, flags=re.DOTALL)

# MindControl: Let's do random damage and extreme slow + blind
mind_old = r'void Skill_MindControl\(\) \{.*?(?=void Skill_TimeRewind)'
mind_new = """void Skill_MindControl() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsPlayerAlive(i) && i != g_iBossClient) {
            if (GetRandomInt(1, 2) == 1) {
                // Сильно замедляем и наносим урон
                SetEntPropFloat(i, Prop_Send, "m_flVelocityModifier", 0.3);
                SetEntPropFloat(i, Prop_Send, "m_flFlashDuration", 3.0);
                SetEntPropFloat(i, Prop_Send, "m_flFlashMaxAlpha", 200.0);
                SDKHooks_TakeDamage(i, g_iBossClient, g_iBossClient, 100.0, DMG_SHOCK);
            }
        }
    }
}
"""
content = re.sub(mind_old, mind_new, content, flags=re.DOTALL)

# CosmicRift: Deal massive damage inside the rings
rift_old = r'void Skill_CosmicRift\(\) \{.*?(?=public Action Event_PlayerDeath)'
rift_new = """void Skill_CosmicRift() {
    for(int i=0; i<3; i++) {
        int target = GetRandomPlayer();
        if (target != -1) {
            float pPos[3]; GetClientAbsOrigin(target, pPos);
            TE_SetupBeamRingPoint(pPos, 10.0, 300.0, g_iLaserModel, g_iHaloModel, 0, 10, 2.0, 30.0, 0.0, {255, 0, 0, 255}, 10, 0);
            TE_SendToAll();

            // Наносим огромный урон всем, кто попал в зону взрыва
            for (int j = 1; j <= MaxClients; j++) {
                if (IsClientInGame(j) && IsPlayerAlive(j) && j != g_iBossClient) {
                    float victimPos[3]; GetClientAbsOrigin(j, victimPos);
                    if (GetVectorDistance(pPos, victimPos) <= 300.0) {
                        SDKHooks_TakeDamage(j, g_iBossClient, g_iBossClient, 600.0, DMG_BLAST);
                        float dir[3]; SubtractVectors(victimPos, pPos, dir);
                        NormalizeVector(dir, dir); ScaleVector(dir, 800.0); dir[2] = 400.0;
                        TeleportEntity(j, NULL_VECTOR, NULL_VECTOR, dir);
                    }
                }
            }
        }
    }
}
"""
content = re.sub(rift_old, rift_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
