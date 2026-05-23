import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

rift_old = r'void Skill_CosmicRift\(\) \{.*?(?=public Action Event_PlayerDeath)'
rift_new = """void Skill_CosmicRift() {
    for(int i=0; i<3; i++) {
        int target = GetRandomPlayer();
        if (target != -1) {
            float pPos[3]; GetClientAbsOrigin(target, pPos);
            TE_SetupBeamRingPoint(pPos, 10.0, 300.0, g_iLaserModel, g_iHaloModel, 0, 10, 2.0, 30.0, 0.0, {255, 0, 0, 255}, 10, 0);
            TE_SendToAll();

            DataPack pack = new DataPack();
            pack.WriteFloat(pPos[0]);
            pack.WriteFloat(pPos[1]);
            pack.WriteFloat(pPos[2]);
            CreateTimer(2.0, Timer_RiftDamage, pack);
        }
    }
}

public Action Timer_RiftDamage(Handle timer, DataPack pack) {
    pack.Reset();
    float pPos[3];
    pPos[0] = pack.ReadFloat();
    pPos[1] = pack.ReadFloat();
    pPos[2] = pack.ReadFloat();
    delete pack;

    TE_SetupSmoke(pPos, g_iSmokeModel, 300.0, 10);
    TE_SendToAll();

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
    return Plugin_Stop;
}
"""
content = re.sub(rift_old, rift_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
