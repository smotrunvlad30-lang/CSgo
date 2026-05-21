#pragma semicolon 1
#include <sourcemod>

public Plugin myinfo =
{
    name = "ONYX Economy Announcer",
    author = "Skvirt",
    description = "Анонс магазина и монет за онлайн",
    version = "1.0",
    url = "giveawayland.online"
};

public void OnMapStart()
{
    // Запускаем таймер на 60 секунд после старта карты
    // Флаг TIMER_FLAG_NO_MAPCHANGE отменит таймер, если карта вдруг сменится быстрее чем за минуту
    CreateTimer(60.0, Timer_Announce, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Announce(Handle timer)
{
    // \x01 - Белый, \x02 - Красный, \x04 - Зеленый, \x06 - Желтый, \x0C - Синий
    PrintToChatAll(" \x04[ONYX]\x01 Играй на сервере и получай донат-\x06Монеты\x01 за онлайн!");
    PrintToChatAll(" \x04[ONYX]\x01 Курс: \x021 минута игры = 1 монета\x01.");
    PrintToChatAll(" \x04[ONYX]\x01 Покупай VIP, Скины и RPG-Кредиты на сайте: \x0Cgiveawayland.online");

    return Plugin_Stop; // Останавливаем таймер, чтобы он сработал только 1 раз
}