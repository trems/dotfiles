# Как патчить agy (Antigravity CLI) — знания и методика

Всё, что нужно, чтобы адаптировать патчер под свежую версию agy. Составлено
2026-11-12 после полного реверса 1.5.6 (см. также HANDOFF.md — хронология).

## Архитектура патчера

- agy — Go-бинарь (Mach-O arm64; x64 собирается отдельно Google'ом).
- Патч = байт-сигнатуры (`Gate`/`MultiGate` в `darwin/antigravity-patch.py (Gate-классы и сигнатуры)`):
  regex по машинному коду, замена 4 байт, ad-hoc re-sign (`codesign -f -s -`).
- Бэкап чистого бинаря: `<path>.agybak`, снимается только с unpatched-файла.
- `darwin/antigravity-patch.py` — неинтерактивный драйвер для nix-darwin activation hook.

## Гейт eligibility: семантика

Единственный обязательный гейт. Google-сервер по региону аккаунта отвечает
"not eligible"; клиент локально это проверяет и блокирует запуск/ходы. Патч
заставляет клиент считать аккаунт eligible. Сервер при этом НЕ блокирует ни
инференс, ни каталог моделей — только вердикт onboarding'а.

### Где искать в новой версии

Патч-сайты между версиями переезжают. Метод поиска:

1. **Найти функции через Go pclntab.** Секция `__lrodata_gopcln` (otool -l),
   формат Go 1.24. Парсер: см. `HANDOFF.md` (session 1-2) — бинарный поиск по
   таблице `entryoff uint32` + `funcoff uint32`, имена в `funcnametab`.
   ⚠️ Имена из pclntab иногда врут (тяжёлый инлайнинг) — не доверять слепо,
   проверять дизассемблер капстоуна.
2. **Якорные строки** (file offset через `mmap.find`, VA = 0x100000000 + off
   для __text; __rodata: VA = 0x10389b7c0 + (off - 59357120) — смещения для
   1.5.6, у других сборок свои; брать из `otool -l`):
   - `"Eligibility check failed: %w"` — оборачивание вердикта в fetchPlanTier
     closure.
   - `"Account ineligible: %s"` — лог при доставке вердикта.
   - `"Auth mode is unspecified, skipping fetchAvailableModels"` — гейт
     каталога моделей в `codeassistclient.getModelCatalog` (НЕ патчить —
     при живом auth он не срабатывает; см. "Ловушки").
3. **Искомый паттерн** (semantics одного и того же чека во всех версиях):

   ```
   cbnz x1, error      ; x1 != 0 -> err path (b5)
   cbz  x0, eligible   ; x0 == 0 -> eligible (b4)
   ldrb wN, [x0, #8]   ; флаг eligible в вердикт-структуре (+8)
   tbnz wN, #0, eligible
   ```

   Патч: `ldrb` -> `mov wN, #1` (`N 00 80 52`), tbnz становится безусловным.
   Пример на 1.5.6 arm64: инструкция по file offset 0x2af0868, сигнал:
   `\x81.{2}\xb5\x80.{2}\xb4\x02\x20\x40\x39\x42.{2}\x37` (re.S), offset=8.

4. **Проверить уникальность сигнатуры** в новой сборке И отсутствие матчей в
   старой (см. тест в конце файла).

### История сайтов

| Версия | Сайт | Что патчим |
|---|---|---|
| 1.0.3 | `backend.(*ServerBackend).applyAuthResult`, inline | `ldrb w1,[x0,#8]; tbnz` → `mov w1,#1` |
| 1.5.6 | closure `fetchPlanTier` (0x2af05e0..0x2af0c50), file off 0x2af0868 | `ldrb w2,[x0,#8]; tbnz` → `mov w2,#1` |

## Ловушки (проверено на практике, НЕ повторять)

1. **Глушить `validateEligibilityWithRetry` целиком (ret nil) НЕЛЬЗЯ** —
   вместе с проверкой умирают сайд-эффекты: `agy models` зависает (timeout),
   print mode падает с "plan model not specified". Патчить только байт
   вердикта в месте доставки/проверки.
2. **Форсить байт eligible в месте ДОСТАВКИ вердикта** (`strb wzr,[x?,#0x70]`
   в 1.5.6, file off 0x2af09d0/0x2af0a00) НЕЛЬЗЯ — для ineligible-аккаунта
   tier-данные от сервера отсутствуют, `printmode.waitForEligibility`
   (printmode.go:517) разыменовывает nil → fatal signal.
3. Правильный сайт — проверка вердикта КОНСЮМЕРОМ (шаг 3 выше): структура
   вердикта остаётся настоящей, все данные на месте, меняется только решение.
4. `agy models` и print mode (`agy -p`) — обязательные тесты ПОСЛЕ патча;
   `models` чует сломанный plan-tier flow, `-p` — крэши.

## Факты о сервере (проверено curl'ом 2026-11-12)

Токен: `security find-generic-password -s gemini -a antigravity -w` →
`go-keyring-base64:<b64>` → JSON с `access_token`, `refresh_token`, `expiry`.

- `POST https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist`
  — тиры аккаунта (`paidTier`, `ineligibleTiers` с UNSUPPORTED_LOCATION).
- `POST .../v1internal:fetchAvailableModels` — каталог моделей. **Гейт по
  User-Agent: префикс `antigravity` → 200, иначе 403 PERMISSION_DENIED.**
  Родной gRPC UA клиента проходит.
- Каталог НЕ урезан по региону: 16 моделей, из них ~10 Google. Но состав
  переименовывается: в 1.5.6 эпохе Gemini 3.8 Flash — это одна запись
  `gemini-3.8-flash-tiered` (без displayName), которую клиент разворачивает в
  High/Medium/Low. Старые клиенты (1.0.3) tiered-разворот не умеют → у них
  пикер без Gemini. Вывод: при "пропавших моделях" сначала смотреть на
  версии клиента и переименования, а не на патч.
- Инференс для ineligible-аккаунта сервер НЕ блокирует (1.0.3 с патченным
  гейтом ходит тем же токеном).

## Полезное окружение

- `AGY_CLI_DISABLE_AUTO_UPDATE=1` — убить самообновление (у нас в
  /etc/zshrc + fish через dotfiles; self-update затирал патченный бинарь
  трижды за день). Плюс `chflags uchg` на /opt/homebrew/bin/agy как
  страховку (снимать через `chflags nouchg`).
- Прочее: `AGY_LLM_GATEWAY_URL/HEADERS/CA_CERT` (enterprise gateway — свой
  endpoint инференса), `AGY_ADC_AUTH`, `AGY_CA_CERTS`.
- Логи: `~/.gemini/antigravity-cli/log/cli-*.log`; ключевые строки:
  `printmode.go:208` (старт, модель), `model_configs.go:201`, `server.go:2274`
  (auth ok), `http_helpers.go:182` (исходящие URL).
- Состояние: `~/.gemini/antigravity-cli/{settings.json,jetski_state.pbtxt}`.

## Чек-лист адаптации к новой версии

1. Сохранить новый бинарь (`/tmp/agy-new`), найти `__lrodata_gopcln` off.
2. Через pclntab найти `fetchPlanTier`/`applyAuthResult`-аналог и строки-
   якоря; капстоуном найти паттерн `cbnz/cbz/ldrb[x0,#8]/tbnz`.
3. Собрать Gate с новым сигналом; убедиться в уникальности (новый бинарь:
   1 матч; 1.0.3 и 1.5.6: 0 матчей).
4. Пропатчить копию, `codesign -f -s -`, протестировать:
   - `printf '' | agy -p "Reply with exactly: ok"` → `ok`
   - `agy models` → список с Gemini
   - TUI в pty (winsize обязателен! `TIOCSWINSZ`, иначе пустой экран):
     `/model` → пикер с Gemini; отправить промпт → ответ.
5. Обновить Gate в `darwin/antigravity-patch.py (Gate-классы и сигнатуры)`, прогнать
   `darwin/antigravity-patch.py`, закоммитить.

## Ограничения

- V3-гейт arm64-only и специфичен для 1.5.6: на новых сборках патчер
  пропускает бинарь с "[!] signature not found" и ненулевым exit.
- x64-сборки agy не тестировались (нет машины).

---

## История (кратко)

- До 2026-11-12 патчер жил в `~/antigravity-patcheer/open-antigravity-patcher`
  (форк мёртвого AvenCores/open-antigravity-patcher, удалён — не нужен, всё
  важное перенесено сюда). Хронология реверса 1.5.6 — в git-истории того репо
  (коммит 763a8bc), копия полной хронологии — ниже.
- agy самообновлялся и затирал патченный бинарь трижды за день; лечится
  `AGY_CLI_DISABLE_AUTO_UPDATE=1` (уже в /etc/zshrc и fish из этого дотфайлса)
  + `chflags uchg` на бинарь.

## Хронология реверса 1.5.6 (офсеты и находки)

- Binary: /opt/homebrew/Caskroom/antigravity-cli/1.5.6-era arm64, 233.5 MB.
  __lrodata_gopcln: addr 0x10463d0c0, file offset 73650368, nfunc=185555,
  Go 1.24 pclntab (magic 0xfffffff1, textStart=0; entryoff = VA-0x100000000).
- Eligibility verdict closure (fetchPlanTier): file 0x2af05e0..0x2af0c50.
  Патч-сайт: 0x2af0868 (cbnz x1; cbz x0; ldrb w2,[x0,#8]; tbnz w2,#0).
- Delivery-байты вердикта: strb wzr,[x2,#0x70] @0x2af09d0, strb wzr,[x0,#0x70]
  @0x2af0a00 — форсить их НЕЛЬЗЯ (crash printmode.waitForEligibility,
  printmode.go:517, nil tier data).
- validateEligibilityWithRetry: entry 0x2ae7250 (prologue
  `900b40f9 ff6330eb c9110054`), ret-nil патч ломает поток моделей.
- getModelCatalog (codeassistclient): 0x20bb980..0x20bbe20; auth-mode чекает
  строки "business"/"paygo"/"adc", "consumer" НЕ проходит → при старте TUI,
  пока auth не устаканился, пишет "Auth mode is unspecified, skipping
  fetchAvailableModels". При живом токене каталог всё равно загружается —
  не патчить.
- constructFromCustomModelConfig: 0x2abded0..0x2abe420 — путь кастомных
  моделей (settings key customModelsConfig, валидация
  "customModels[%s]: modelName is required"), не понадобился.
- Модельный состав сервера на 2026-11-12: gemini-3.8-flash-tiered (без
  displayName; клиент 1.5.6 разворачивает в H/M/L), gemini-3-flash,
  gemini-3.5-flash-lite, gemini-3.1-flash-lite/image, gemini-2.5-pro/flash*,
  claude-sonnet/opus-4-6(-thinking), gpt-oss-120b-medium, chat_*/tab_*.
