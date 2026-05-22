import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# Replace SetupBoss to fetch HP dynamically
setup_old = r'void SetupBoss\(int client\) \{.*?g_iBossHP = 50000 \+ \(g_iBossRarity \* 50000\);.*?g_iBossMaxHP = g_iBossHP;'
setup_new = """void SetupBoss(int client) {
    g_iBossHP = GetBossConfigHP(g_iBossRarity);
    g_iBossMaxHP = g_iBossHP;"""
content = re.sub(setup_old, setup_new, content, flags=re.DOTALL)

# Add GetBossConfigHP method
get_hp_func = """
int GetBossConfigHP(int rarity) {
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/rpg_boss_drops.txt");

    KeyValues kv = new KeyValues("BossDrops");
    if (!kv.ImportFromFile(path)) {
        delete kv;
        switch (rarity) {
            case 0: return 500000;
            case 1: return 1500000;
            case 2: return 3000000;
            case 3: return 8000000;
        }
        return 500000;
    }

    char key[16];
    Format(key, sizeof(key), "hp_%d", rarity);
    int hp = kv.GetNum(key, 500000);
    delete kv;
    return hp;
}
"""
content += get_hp_func

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
