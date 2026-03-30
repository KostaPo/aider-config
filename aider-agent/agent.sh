#!/bin/bash
# Использование:
#   ./agent.sh "задача"             — локальная LLM (по умолчанию)
#   ./agent.sh local "задача"       — локальная LLM
#   ./agent.sh openrouter "задача"  — OpenRouter
#
# Агентский режим — модель самостоятельно определяет какие файлы создать
# или изменить и применяет правки. Используй для создания новых сервисов,
# классов, модулей — когда файлы ещё не существуют или список неизвестен.
#
# Флаги aider:
#   --yes-always            автоподтверждение всех вопросов — агент работает без остановок
#   --auto-commits          каждое изменение файла коммитится автоматически в git
#   --git                   включить git-интеграцию
#   --stream                стримить ответ по мере генерации
#   --show-diffs            показывать diff после каждого изменённого файла
#   --cache-prompts         кешировать системный промпт — экономит токены при повторных запросах
#   --cache-keepalive-pings количество пингов для удержания кеша между запросами
#   --no-check-update       не проверять обновления aider при старте
#   --model-settings-file   путь к файлу настроек модели (температура, контекст и тд)
#   --model-metadata-file   путь к файлу метаданных модели (лимиты токенов и тд)
#   --input-history-file    история введённых команд (как ~/.bash_history)
#   --chat-history-file     история диалога в markdown — удобно читать что делал агент
#   --llm-history-file      сырая история запросов/ответов к LLM — для отладки
#   --read                  файл добавляется в контекст read-only (агент не меняет его)
#   --message               задача передаётся напрямую — не нужен интерактивный ввод

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

if [ "$1" = "openrouter" ]; then
    ENV_FILE="$SCRIPT_DIR/env.openrouter"
    MODEL=openrouter/qwen/qwen3-coder
    TASK="$2"
    SHOW_METRICS=false
else
    ENV_FILE="$SCRIPT_DIR/env.local"
    MODEL=openai/Qwen3.5-35B
    TASK="${2:-$1}"
    SHOW_METRICS=true
fi

echo ""
echo "[AGENT] Model : $MODEL"
echo "[AGENT] Task  : $TASK"
echo ""

docker compose --project-directory "$DOCKER_DIR" --env-file "$ENV_FILE" run --rm --no-deps aider \
  --model               "$MODEL"                                    \
  --no-show-model-warnings                                          \
  --model-settings-file /project/.aider.model.settings.yml          \
  --model-metadata-file /project/.aider.model.metadata.json         \
  --yes-always                                                      \
  --auto-commits                                                    \
  --git                                                             \
  --stream                                                          \
  --show-diffs                                                      \
  --cache-prompts                                                   \
  --cache-keepalive-pings 2                                         \
  --no-check-update                                                 \
  --input-history-file  /project/llm_history/.aider.input.history   \
  --chat-history-file   /project/llm_history/.aider.chat.history.md \
  --llm-history-file    /project/llm_history/.aider.llm.history     \
  --read                /project/wal.md                             \
  --message             "$TASK"

if [ "$SHOW_METRICS" = true ]; then
    echo ""
    METRICS=$(curl -s http://localhost:1234/metrics)
    PROMPT_TOKENS=$(echo "$METRICS" | grep -E "^llamacpp:prompt_tokens_total "      | awk '{print $2}')
    PROMPT_SPEED=$(echo "$METRICS"  | grep -E "^llamacpp:prompt_tokens_seconds "    | awk '{printf "%.1f", $2}')
    GEN_TOKENS=$(echo "$METRICS"    | grep -E "^llamacpp:tokens_predicted_total "   | awk '{print $2}')
    GEN_SPEED=$(echo "$METRICS"     | grep -E "^llamacpp:predicted_tokens_seconds " | awk '{printf "%.1f", $2}')
    echo "━━━ llama.cpp stats ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  Prompt (input):    %6s tok  %6s t/s\n" "$PROMPT_TOKENS" "$PROMPT_SPEED"
    printf "  Generate (output): %6s tok  %6s t/s\n" "$GEN_TOKENS"    "$GEN_SPEED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi