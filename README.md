# Aider CLI AI-агент

Инструмент для автоматического написания и рефакторинга кода с помощью LLM.
Поддерживает локальную модель (llama.cpp) и облачную (OpenRouter).

---

## Структура проекта
```
aider-config/
├── aider-agent/
│   ├── docker/
│   │   ├── Dockerfile          — образ с aider
│   │   ├── docker-compose.yml  — llama.cpp + aider
│   │   └── .env                — заглушка для IDE
│   ├── agent.sh                — агент сам решает какие файлы трогать
│   ├── agent-files.sh          — агент с явным списком файлов
│   ├── ask.sh                  — вопрос по проекту без изменений
│   ├── plan.sh                 — план без изменений файлов
│   ├── rollback.sh             — откат коммитов
│   ├── env.local               — переменные для локальной LLM
│   └── env.openrouter          — переменные для OpenRouter
├── llm_history/                — логи диалогов с агентом
├── src/                        — исходный код проекта
├── .aider.model.settings.yml   — настройки поведения модели
├── .aider.model.metadata.json  — размер контекста и стоимость
├── .aiderignore                — что агент не трогает
├── .gitignore
├── pom.xml
├── wal.md                      — архитектурные решения и контекст проекта
└── README.md
```

---

## Быстрый старт

### 1. Создай и заполни env файлы

**`aider-agent/env.local`** — для локальной LLM:
```env
PROJECT_PATH=/home/user/IdeaProjects/aider-config
OPENAI_API_BASE=http://host.docker.internal:1234/v1
OPENAI_API_KEY=not-needed
OPENROUTER_API_KEY=
```

**`aider-agent/env.openrouter`** — для OpenRouter:
```env
PROJECT_PATH=/home/user/IdeaProjects/aider-config
OPENAI_API_BASE=
OPENAI_API_KEY=
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxx
```

### 2. Запусти контейнеры с Aider и локальной LLM
```bash
cd aider-config/aider-agent/docker
docker compose up -d
```

### 3. Дай права на запуск скриптов
```bash
chmod +x aider-agent/ask.sh aider-agent/agent.sh aider-agent/agent-files.sh aider-agent/plan.sh aider-agent/rollback.sh
```

---

## Скрипты и когда использовать

| Скрипт | Меняет файлы | Когда использовать |
|---|---|---|
| `ask.sh` | нет | вопрос по проекту, анализ, поиск багов |
| `plan.sh` | нет | узнать что будет затронуто перед выполнением |
| `agent.sh` | да | создать новое — сервис, модуль, эндпоинт |
| `agent-files.sh` | да | изменить конкретные существующие файлы |
| `rollback.sh` | да (git) | откатить коммиты агента |

---

## Использование

### `ask.sh` — вопрос по проекту

Только ответ. Файлы не меняются.
```bash
./ask.sh "как работает авторизация в проекте?"
./ask.sh local "найди потенциальные проблемы в UserService"
./ask.sh openrouter "объясни архитектуру модуля auth"
```

### `plan.sh` — план без изменений

Анализирует задачу и возвращает детальный план: что создать, что изменить,
в каком порядке. Файлы не трогает. Читаешь план, при необходимости правишь,
затем передаёшь агенту.
```bash
./plan.sh "добавить регистрацию пользователя"
./plan.sh openrouter "добавить регистрацию пользователя"
```

### `agent.sh` — агентский режим

Агент сам определяет какие файлы создать или изменить.
Используй когда файлы ещё не существуют или список неизвестен.
```bash
./agent.sh "добавь сервис регистрации пользователя"
./agent.sh local "создай модуль импорта CSV"
./agent.sh openrouter "реализуй JWT авторизацию"
```

### `agent-files.sh` — агент с явными файлами

Агент видит и меняет только те файлы которые ты передал.
Быстрее и дешевле по токенам — нет поиска по repo-map.
```bash
./agent-files.sh "отрефактори" src/main/java/ru/kostapo/service/UserService.java

./agent-files.sh "добавь эндпоинт" \
  src/main/java/ru/kostapo/controller/UserController.java \
  src/main/java/ru/kostapo/service/UserService.java

./agent-files.sh openrouter "добавь javadoc" src/main/java/ru/kostapo/controller/HelloController.java
```

### `rollback.sh` — откат коммитов
```bash
./rollback.sh       # откатить последний коммит
./rollback.sh 3     # откатить последние 3 коммита
```

---

## Рекомендуемый workflow

### Простая задача — известные файлы
```bash
./agent-files.sh "добавь валидацию email" \
  src/main/java/ru/kostapo/service/UserService.java
```

### Новый функционал — неизвестные файлы
```bash
# Шаг 1 — получить план
./plan.sh "добавить регистрацию пользователя"

# Шаг 2 — прочитать план, убедиться что всё верно

# Шаг 3 — скормить план агенту
./agent.sh "добавить регистрацию пользователя согласно плану: ..."
```

### Что-то пошло не так
```bash
# Посмотреть что сделал агент
git diff HEAD~1

# Откатить
./rollback.sh

# Написать в wal.md почему не подошло и запустить снова
```

---

## Провайдеры

| Провайдер | Аргумент | Модель | Когда использовать |
|---|---|---|---|
| Локальная LLM | пусто / `local` | Qwen3.5-35B | Быстро, бесплатно, офлайн |
| OpenRouter | `openrouter` | qwen3-coder | Сложные задачи, точнее следует инструкциям |

---

## Настройки модели

### `.aider.model.settings.yml`
```yaml
- name: openai/Qwen3.5-35B
  edit_format: whole       # переписывает файл целиком (надёжнее для локальных моделей)
  use_repo_map: true       # видит структуру всего проекта
  streaming: true
  use_system_prompt: true
  use_temperature: true
  examples_as_sys_msg: false
  extra_params:
    max_tokens: 8192
```

### `.aider.model.metadata.json`
```json
{
  "openai/Qwen3.5-35B": {
    "max_tokens": 16384,
    "max_input_tokens": 131072,  // должен совпадать с -c 131072 в docker-compose.yml
    "max_output_tokens": 16384,
    "input_cost_per_token": 0,
    "output_cost_per_token": 0,
    "litellm_provider": "openai"
  }
}
```

---

## wal.md — архитектурный журнал

Файл который агент **читает но не меняет**. Содержит стек, архитектурные решения,
соглашения по коду и ограничения. Пиши сюда всё что агент должен учитывать.
Чем точнее wal.md — тем меньше правок и откатов.

---

## Важные замечания

- Секреты (`env.local`, `env.openrouter`) в `.gitignore` — не попадут в репозиторий
- Коммиты от агента подписаны как `aider-agent` — в `git log` видно кто автор
- Метрики llama.cpp накопительные — сбрасываются только перестартом контейнера
- `plan.sh` на локальной модели может выдавать неточные пути — для планирования предпочтительнее `openrouter`