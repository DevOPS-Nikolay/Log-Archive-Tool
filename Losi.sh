#!/bin/bash

# Функция для запроса ввода пользователя с опцией по умолчанию
prompt_for_input() {
    read -r -p "$1 [$2]: " input
    echo "${input:-$2}"
}

# Функция для проверки числового ввода
validate_numeric_input() {
    local input=$1
    local prompt_text=$2
    while ! [[ "$input" =~ ^[0-9]+$ ]]; do
        echo "Ошибка: Пожалуйста, введите допустимое число."
        read -r -p "$prompt_text" input
    done
    echo "$input"
}

# Функция для настройки задания cron
setup_cron() {
    read -r -p "Хотите добавить этот скрипт в cron для ежедневного выполнения? (y/n) " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        local hour=$(validate_numeric_input "$(prompt_for_input "Введите час для задания cron (0-23)" "2")" "Введите час для задания cron (0-23) [2]: ")
        local minute=$(validate_numeric_input "$(prompt_for_input "Введите минуту для задания cron (0-59)" "0")" "Введите минуту для задания cron (0-59) [0]: ")
        local cron_line="$minute $hour * * * /usr/local/bin/log-archive.sh"
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
        if [[ $? -eq 0 ]]; then
            echo "Задание cron добавлено: $cron_line"
        else
            echo "Ошибка: Не удалось добавить задание cron."
        fi
    else
        echo "Задание cron не добавлено."
    fi
}

# Функция для архивации логов
archive_logs() {
    local log_dir=$1
    local days_to_keep_logs=$2
    local days_to_keep_backups=$3

    local archive_dir="$log_dir/archive"
    mkdir -p "$archive_dir"

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_file="$archive_dir/logs_archive_$timestamp.tar.gz"

    echo "Архивация логов старше $days_to_keep_logs дней."
    find "$log_dir" -type f -mtime +"$days_to_keep_logs" -print0 | tar -czf "$archive_file" --null -T -

    if [ -f "$archive_file" ]; then
        echo "Логи архивированы в $archive_file на $(date)" >> "$archive_dir/archive_log.txt"
        find "$log_dir" -type f -mtime +"$days_to_keep_logs" -exec rm -f {} \;
        echo "Архивация завершена: $archive_file"
        echo "Удаление резервных копий старше $days_to_keep_backups дней."
        find "$archive_dir" -type f -name "*.tar.gz" -mtime +"$days_to_keep_backups" -exec rm -f {} \;
        echo "Резервные копии старше $days_to_keep_backups дней были удалены."
    else
        echo "Ошибка: Архив не был создан успешно."
    fi
}

# Главный интерактивный цикл
while true; do
    echo "1. Указать каталог логов"
    echo "2. Указать количество дней для хранения логов"
    echo "3. Указать количество дней для хранения резервных копий"
    echo "4. Запустить процесс архивации логов"
    echo "5. Выйти"
    echo ""

    read -r -p "Выберите опцию [1-5]: " choice

    case $choice in
        1)
            log_dir=$(prompt_for_input "Введите каталог логов" "/var/log")
            if [ ! -d "$log_dir" ]; then
                echo "Ошибка: Каталог логов не существует."
                log_dir=""
            else
                echo "Каталог логов установлен на $log_dir"
            fi
            ;;
        2)
            days_to_keep_logs=$(validate_numeric_input "$(prompt_for_input "Сколько дней хранить логи?" "7")" "Сколько дней хранить логи? [7]: ")
            echo "Логи старше $days_to_keep_logs дней будут архивированы."
            ;;
        3)
            days_to_keep_backups=$(validate_numeric_input "$(prompt_for_input "Сколько дней хранить резервные копии?" "30")" "Сколько дней хранить резервные копии? [30]: ")
            echo "Резервные копии старше $days_to_keep_backups дней будут удалены."
            ;;
        4)
            if [ -z "$log_dir" ]; then
                echo "Ошибка: Каталог логов не установлен. Пожалуйста, установите его сначала."
            else
                archive_logs "$log_dir" "$days_to_keep_logs" "$days_to_keep_backups"
            fi
            ;;
        5)
            echo "Выход..."
            break
            ;;
        *)
            echo "Недопустимая опция. Пожалуйста, выберите номер от 1 до 5."
            ;;
    esac
done

# Вызов функции настройки cron
setup_cron
