import re

with open("ФАйлы сервера кс го/rpg_skills_attack.sp", "r", encoding="utf-8") as f:
    content = f.read()

bleed_old = r'public Action Timer_BleedTick\(Handle timer, any userid\) \{.*?(?=public Action Timer_ResetItemSpeed)'
bleed_new = """public Action Timer_BleedTick(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsPlayerAlive(client) && GetEngineTime() < g_flBleedTime[client]) {
        int hp = GetClientHealth(client);
        if (hp > 5) {
            SetEntityHealth(client, hp - 5);
        } else {
            SDKHooks_TakeDamage(client, 0, 0, 999.0, DMG_GENERIC);
        }
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

"""
content = re.sub(bleed_old, bleed_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_skills_attack.sp", "w", encoding="utf-8") as f:
    f.write(content)
