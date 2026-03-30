#!/bin/bash
# Использование:
#   ./plan.sh "задача"
#   ./plan.sh local "задача"
#   ./plan.sh openrouter "задача"
#
# Режим планирования — модель анализирует проект и возвращает план выполнения.
# Файлы не меняются. План читаешь, при необходимости правишь, затем скармливаешь агенту.
#
# Подход plan → review → execute:
#   1. ./plan.sh "задача"    — получить план, прочитать, проверить
#   2. Скорректировать план если нужно
#   3. ./agent.sh "план"     — скормить готовый план агенту
#
# Зачем это нужно:
#   Агент без плана может затронуть лишние файлы, пойти не в ту сторону
#   архитектурно, сделать коммиты которые придётся откатывать.
#   План даёт контроль над тем ЧТО будет сделано до того как агент
#   начал менять файлы.
#
# Флаги aider:
#   --edit-format ask       режим только ответа — нет агентского цикла,
#                           нет повторных запросов, нет дублирования вывода
#   --yes-always            автоподтверждение всех вопросов
#   --no-auto-commits       не коммитить — файлы не меняются
#   --dry-run               двойная защита — даже если модель попытается
#                           что-то записать, изменения не применятся
#   --map-tokens 4096       увеличенный repo-map — модель видит больше файлов
#                           проекта для более точного планирования
#   --cache-prompts         кешировать системный промпт
#   --cache-keepalive-pings количество пингов для удержания кеша
#   --no-check-update       не проверять обновления aider при старте
#   --model-settings-file   путь к файлу настроек модели
#   --model-metadata-file   путь к файлу метаданных модели
#   --input-history-file    история введённых команд
#   --chat-history-file     история диалога в markdown
#   --llm-history-file      сырая история запросов/ответов к LLM — для отладки
#   --read                  файл добавляется в контекст read-only
#   --message               задача передаётся напрямую

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

if [ "$1" = "openrouter" ]; then
    ENV_FILE="$SCRIPT_DIR/env.openrouter"
    MODEL=openrouter/deepseek/deepseek-v3.2
    TASK="$2"
else
    ENV_FILE="$SCRIPT_DIR/env.local"
    MODEL=openai/Qwen3.5-35B
    if [ "$1" = "local" ]; then
        TASK="$2"
    else
        TASK="$1"
    fi
fi

PROMPT="Задача: $TASK.

Составь точный план выполнения. Формат:

## Контекст
Одна строка — что и зачем.

## Файлы
### путь/к/файлу (создать|изменить)
- конкретное действие с именами классов, методов, полей

## Порядок
Пронумерованный список с учётом зависимостей.

## Не трогать
Что должно остаться без изменений."

echo ""
echo "[PLAN] Model   : $MODEL"
echo "[PLAN] Task    : $TASK"
echo "[PLAN] Dry-run — файлы не будут изменены"
echo ""

docker compose --project-directory "$DOCKER_DIR" --env-file "$ENV_FILE" run --rm --no-deps aider \
  --model               "$MODEL"                                     \
  --no-show-model-warnings                                           \
  --model-settings-file /project/.aider.model.settings.yml          \
  --model-metadata-file /project/.aider.model.metadata.json         \
  --edit-format         ask                                          \
  --yes-always                                                       \
  --no-auto-commits                                                  \
  --dry-run                                                          \
  --cache-prompts                                                    \
  --cache-keepalive-pings 2                                          \
  --no-check-update                                                  \
  --map-tokens          4096                                         \
  --input-history-file  /project/llm_history/.aider.input.history   \
  --chat-history-file   /project/llm_history/.aider.chat.history.md \
  --llm-history-file    /project/llm_history/.aider.llm.history     \
  --read                /project/wal.md                             \
  --message             "$PROMPT"