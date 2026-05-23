// Настройка шансов дропа в зависимости от редкости босса
// 0 - Обычный
// 1 - Редкий
// 2 - Легендарный
// 3 - МИФИЧЕСКИЙ

stock float GetBossDropChance(int rarity) {
    switch (rarity) {
        case 0: return 5.0;   // Обычный
        case 1: return 15.0;  // Редкий
        case 2: return 35.0;  // Легендарный
        case 3: return 70.0;  // МИФИЧЕСКИЙ
    }
    return 1.0;
}
