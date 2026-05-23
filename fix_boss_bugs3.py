import re

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Randomize Movement Buttons in OnPlayerRunCmd
runcmd_old = r'if \(g_bMindControlled\[client\]\) \{.*?(?=if \(client \!\= g_iBossClient\))'
runcmd_new = """if (g_bMindControlled[client]) {
        int originalButtons = buttons;
        int newButtons = buttons;

        // Очищаем кнопки движения
        newButtons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);

        // Рандомно перемешиваем нажатия
        if (originalButtons & IN_FORWARD) {
            int rand = GetRandomInt(0, 3);
            if (rand == 0) newButtons |= IN_BACK;
            else if (rand == 1) newButtons |= IN_MOVELEFT;
            else if (rand == 2) newButtons |= IN_MOVERIGHT;
            else newButtons |= IN_FORWARD;
        }
        if (originalButtons & IN_BACK) {
            int rand = GetRandomInt(0, 3);
            if (rand == 0) newButtons |= IN_FORWARD;
            else if (rand == 1) newButtons |= IN_MOVELEFT;
            else if (rand == 2) newButtons |= IN_MOVERIGHT;
            else newButtons |= IN_BACK;
        }
        if (originalButtons & IN_MOVELEFT) {
            int rand = GetRandomInt(0, 3);
            if (rand == 0) newButtons |= IN_MOVERIGHT;
            else if (rand == 1) newButtons |= IN_FORWARD;
            else if (rand == 2) newButtons |= IN_BACK;
            else newButtons |= IN_MOVELEFT;
        }
        if (originalButtons & IN_MOVERIGHT) {
            int rand = GetRandomInt(0, 3);
            if (rand == 0) newButtons |= IN_MOVELEFT;
            else if (rand == 1) newButtons |= IN_FORWARD;
            else if (rand == 2) newButtons |= IN_BACK;
            else newButtons |= IN_MOVERIGHT;
        }

        buttons = newButtons;
        return Plugin_Changed;
    }

    """
content = re.sub(runcmd_old, runcmd_new, content, flags=re.DOTALL)

with open("ФАйлы сервера кс го/rpg_boss_system.sp", "w", encoding="utf-8") as f:
    f.write(content)
