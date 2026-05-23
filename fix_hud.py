import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

hud_old = r'ShowSyncHudText\(i, g_hHudSync, "ТАНОС \[%s\]\nХП: %d / %d\nОсталось: %02d:%02d", rName, currentHP, g_iBossMaxHP, timeLeft / 60, timeLeft % 60\);'
hud_new = r'ShowSyncHudText(i, g_hHudSync, "ТАНОС [%s]\\nХП: %d / %d\\nОсталось: %02d:%02d", rName, g_iBossHP, g_iBossMaxHP, timeLeft / 60, timeLeft % 60);'

# Replace any explicit literal newlines in case it was written that way
content = re.sub(r'ShowSyncHudText\(i, g_hHudSync, "ТАНОС \[\%s\]\nХП: \%d / \%d\nОсталось: \%02d:\%02d"',
                 r'ShowSyncHudText(i, g_hHudSync, "ТАНОС [%s]\\nХП: %d / %d\\nОсталось: %02d:%02d"', content)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
