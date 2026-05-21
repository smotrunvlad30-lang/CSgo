#pragma semicolon 1
#include <sourcemod>

public Plugin myinfo = 
{
    name = "Map Time Vote",
    author = "ONYX",
    description = "Голосование за лимит времени карты (20-70 мин) через 3 минуты после старта",
    version = "1.0"
};

public void OnMapStart()
{
    // Запускаем таймер на 3 минуты (180 секунд)
    CreateTimer(180.0, Timer_StartTimeVote, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_StartTimeVote(Handle timer)
{
    // Проверяем, есть ли на сервере реальные игроки
    if (GetRealClientCount() == 0) {
        PrintToServer("[Map Time Vote] Голосование отменено (нет игроков).");
        return Plugin_Continue;
    }

    // Создаем меню голосования
    Menu menu = new Menu(MenuHandler_TimeVote);
    menu.SetTitle("Сколько минут играем на этой карте?\n ");
    menu.AddItem("20", "20 Минут");
    menu.AddItem("30", "30 Минут");
    menu.AddItem("40", "40 Минут");
    menu.AddItem("50", "50 Минут");
    menu.AddItem("60", "60 Минут");
    menu.AddItem("70", "70 Минут");
    menu.ExitButton = false;
    
    // Показываем меню всем на 20 секунд
    menu.DisplayVoteToAll(20);

    PrintToChatAll(" \x04[ONYX]\x01 Началось голосование за время игры на этой карте!");
    
    return Plugin_Continue;
}

public int MenuHandler_TimeVote(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_VoteEnd)
    {
        char item[32], display[32];
        float percent;
        int votes, totalVotes;

        GetMenuVoteInfo(param2, votes, totalVotes);
        menu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));

        // Получаем победившее время
        int timeLimit = StringToInt(item);
        
        // Устанавливаем лимит времени карты
        ServerCommand("mp_timelimit %d", timeLimit);
        
        // Оповещаем игроков
        PrintToChatAll(" \x04[ONYX]\x01 Голосование завершено! Мы будем играть эту карту \x04%d минут\x01.", timeLimit);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

// Вспомогательная функция для подсчета реальных игроков (без ботов)
int GetRealClientCount()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            count++;
        }
    }
    return count;
}