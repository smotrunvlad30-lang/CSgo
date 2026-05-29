#!/bin/bash

# Скрипт настройки базовой защиты iptables для сервера CS:GO
# Внимание: Выполнять от имени root (sudo)
# Убедитесь, что ваш игровой порт 27015. Если другой - измените переменную.

PORT=27015

echo "Установка правил iptables для порта $PORT..."

# Очистка старых правил для этого порта (опционально, закомментировано для безопасности)
# iptables -D INPUT -p udp --dport $PORT -j DROP 2>/dev/null || true

# 1. Ограничение количества новых подключений с одного IP-адреса
# Защита от спама фейковыми клиентами
iptables -A INPUT -p udp --dport $PORT -m state --state NEW -m recent --set
iptables -A INPUT -p udp --dport $PORT -m state --state NEW -m recent --update --seconds 1 --hitcount 5 -j DROP

# 2. Лимитирование запросов информации о сервере (A2S_INFO)
# |ffffffff54| - это hex-представление заголовка запроса A2S_INFO
# Блокируем IP, если он посылает более 3 запросов за 2 секунды
iptables -A INPUT -p udp --dport $PORT -m string --hex-string "|ffffffff54|" --algo bm -m recent --set --name a2sinfo
iptables -A INPUT -p udp --dport $PORT -m string --hex-string "|ffffffff54|" --algo bm -m recent --update --seconds 2 --hitcount 3 --name a2sinfo -j DROP

# Разрешаем легитимный трафик
iptables -A INPUT -p udp --dport $PORT -j ACCEPT

echo "Правила применены. Для их сохранения после перезагрузки используйте iptables-save."
