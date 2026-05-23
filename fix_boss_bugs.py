import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# 1. HP System Rewrite: Completely decouple g_iBossHP from GetClientHealth to prevent 100 HP bugs
damage_old = r'g_iBossHP = GetClientHealth\(victim\) \- RoundFloat\(damage\);'
damage_new = r'g_iBossHP -= RoundFloat(damage);'
content = content.replace(damage_old, damage_new)

# Force huge engine HP in Spawn to prevent early death by engine
spawn_old = r'SetEntityModel\(client, g_sBossModel\);'
spawn_new = """SetEntityModel(client, g_sBossModel);
        SetEntityHealth(client, 9999999);"""
content = content.replace(spawn_old, spawn_new)

# Also force huge engine HP in SetupBoss
setup_old = r'SetEntityHealth\(client, g_iBossHP\);\n    SetEntProp\(client, Prop_Data, "m_iMaxHealth", g_iBossHP\);'
setup_new = """SetEntityHealth(client, 9999999);"""
content = re.sub(setup_old, setup_new, content)

# 2. Mind Control fix: Instead of modifying vel and returning Plugin_Changed (which might fight player client inputs), modify purely buttons/angles or use velocity modifier + reverse buttons
runcmd_old = r'if \(g_bMindControlled\[client\]\) \{.*?(?=if \(client \!\= g_iBossClient\))'
runcmd_new = """if (g_bMindControlled[client]) {
        int newButtons = buttons;

        // Инвертируем только если нажата кнопка
        if (buttons & IN_FORWARD) { newButtons &= ~IN_FORWARD; newButtons |= IN_BACK; }
        else if (buttons & IN_BACK) { newButtons &= ~IN_BACK; newButtons |= IN_FORWARD; }

        if (buttons & IN_MOVELEFT) { newButtons &= ~IN_MOVELEFT; newButtons |= IN_MOVERIGHT; }
        else if (buttons & IN_MOVERIGHT) { newButtons &= ~IN_MOVERIGHT; newButtons |= IN_MOVELEFT; }

        // Инвертируем мышь/взгляд
        float newAngles[3];
        newAngles[0] = angles[0]; // Pitch
        newAngles[1] = angles[1] + 180.0; // Yaw (отзеркаливаем)
        if (newAngles[1] > 180.0) newAngles[1] -= 360.0;

        angles = newAngles;
        buttons = newButtons;
        vel[0] = -vel[0];
        vel[1] = -vel[1];

        return Plugin_Changed;
    }

    """
content = re.sub(runcmd_old, runcmd_new, content, flags=re.DOTALL)

# 3. Cosmic Rift Color
rift_old = r'\{255, 0, 0, 255\}'
rift_new = r'{128, 0, 128, 255}'
content = content.replace(rift_old, rift_new)

# 4. Boss Speed Update
speed_old = r'float speedMult = 0\.7;'
speed_new = r'float speedMult = 1.3;'
content = content.replace(speed_old, speed_new)

# Also adjust velocity application logic
run_vel_old = r'vel\[0\] = 200\.0 \* speedMult;'
run_vel_new = r'vel[0] = 300.0 * speedMult;'
content = content.replace(run_vel_old, run_vel_new)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
