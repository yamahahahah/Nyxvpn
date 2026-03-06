#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Начинаем проверку подписок...${NC}"

# Текущая дата в секундах
current_date=$(date +%s)
echo -e "📅 Текущая дата: $(date)"

# Создаём папки если их нет
mkdir -p users/active users/expired logs

# Счётчики
reminded_count=0
deleted_count=0

# Проходим по всем активным подпискам
for user_file in users/active/*.txt; do
    if [ ! -f "$user_file" ]; then
        continue
    fi
    
    filename=$(basename "$user_file" .txt)
    echo -e "\n${YELLOW}📄 Проверяем: $filename${NC}"
    
    # Ищем строку с expire=
    expire_line=$(grep "#subscription-userinfo:" "$user_file" || echo "")
    
    if [[ -n "$expire_line" ]]; then
        # Вытаскиваем дату окончания
        if [[ $expire_line =~ expire=([0-9]+) ]]; then
            expire_date="${BASH_REMATCH[1]}"
            expire_human=$(date -d @$expire_date "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            
            # Вычисляем разницу в днях
            days_left=$(( ($expire_date - $current_date) / 86400 ))
            
            echo -e "   📆 Истекает: $expire_human (осталось дней: $days_left)"
            
            # Получаем username из имени файла (если файл назван по юзернейму)
            username=$(echo "$filename" | cut -d'_' -f1)
            
            # ⏰ ЗА 2 ДНЯ ДО ОКОНЧАНИЯ - НАПОМИНАНИЕ
            if [ $days_left -eq 2 ]; then
                echo -e "   ${YELLOW}⏰ Осталось 2 ДНЯ! Отправляем напоминание${NC}"
                
                # Проверяем, не отправляли ли уже сегодня
                if ! grep -q "$(date +%Y-%m-%d) $filename" logs/reminders.log 2>/dev/null; then
                    echo "$(date +%Y-%m-%d) $filename (осталось 2 дня)" >> logs/reminders.log
                    reminded_count=$((reminded_count + 1))
                    
                    # Здесь будет отправка в Telegram (через GitHub Actions)
                    echo "   📱 Напоминание для @$username"
                fi
            fi
            
            # ❌ ЕСЛИ СРОК ПРОШЁЛ - ОТКЛЮЧАЕМ ПОДПИСКУ
            if [ $current_date -gt $expire_date ]; then
                echo -e "   ${RED}❌ СРОК ИСТЁК! Перемещаем в expired${NC}"
                
                # Сохраняем в лог
                echo "$(date): Истёк пользователь $filename (срок был $expire_human)" >> logs/deletions.log
                
                # Перемещаем файл в папку expired (отключаем подписку)
                mv "$user_file" "users/expired/${filename}_$(date +%Y%m%d).txt"
                deleted_count=$((deleted_count + 1))
                
                echo "   📦 Файл перемещён в users/expired/"
            fi
        fi
    else
        echo "   ⚠️ Нет информации о сроке в файле"
    fi
done

# Считаем остатки
active_count=$(ls -1 users/active/*.txt 2>/dev/null | wc -l)
expired_count=$(ls -1 users/expired/*.txt 2>/dev/null | wc -l)

echo -e "\n${GREEN}✅ Проверка завершена!${NC}"
echo "📊 Статистика:"
echo "   🟢 Активных: $active_count"
echo "   🔴 Истёкших: $expired_count"
echo "   ⏰ Напоминаний отправлено: $reminded_count"
echo "   ❌ Отключено сегодня: $deleted_count"

# Сохраняем статистику
echo "$(date): active=$active_count, expired=$expired_count, reminded=$reminded_count, deleted=$deleted_count" >> logs/stats.log