# Murmurix Refactoring Audit (Deep)

Дата: 2026-02-09  
Последнее обновление: 2026-02-09 06:36  
Ветка: `refactor/phase0-language-flow`  
Проект: `Murmurix` (macOS menubar, Swift/AppKit/SwiftUI)

## 1. Цель документа

Подготовить практичный план рефакторинга, который:

- снижает риск регрессий в основном пользовательском потоке (record -> transcribe -> paste/result),
- уменьшает связность между UI и сервисным слоем,
- повышает наблюдаемость ошибок и предсказуемость конкурентного поведения,
- сохраняет текущий темп разработки фич.

## 2. Методика анализа

Проведен аудит по всему репозиторию:

- Прод-код: `Murmurix/App`, `Murmurix/Services`, `Murmurix/Models`, `Murmurix/ViewModels`, `Murmurix/Views`
- Тесты: `MurmurixTests`, `MurmurixUITests`
- Конфигурация сборки и пакеты: `Murmurix.xcodeproj/project.pbxproj`, `Murmurix.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Entitlements: `Murmurix/Murmurix.entitlements`

Проверка на рабочем дереве:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix \
-destination 'platform=macOS' -derivedDataPath /tmp/murmurix-dd test
```

Результат: `** TEST SUCCEEDED **` (2026-02-09, около 05:28 локального времени).

## 3. Снимок текущего состояния

### 3.1 Объем и структура

- Прод-файлы Swift: `57`
- Прод-код: `6070` строк
- Тесты Swift (`MurmurixTests`): `4120` строк
- Unit/Integration тесты: `298` (`@Test`)
- UI тесты: `3`
- Уникальные тест-кейсы в `xcresult` DB: `301`
- Выполненные test runs: `302`
- Падений: `0`
- Code coverage в последнем прогона (по LogStoreManifest): `~12.90%`

### 3.2 Ключевые метрики техдолга

- `try?` в прод-коде: `0`
- `as!` в прод-коде: `0`
- `first!` в прод-коде: `0`
- `Task.detached`: `0`
- Singleton-паттерн `static let shared`: `5`

### 3.3 Крупнейшие файлы (hotspots по размеру)

- `Murmurix/Views/GeneralSettingsView.swift` — 368 строк
- `Murmurix/Views/Components/WhisperModelCardView.swift` — 362 строки
- `Murmurix/Services/RecordingCoordinator.swift` — 256 строк
- `Murmurix/App/AppDelegate.swift` — 256 строк
- `Murmurix/ViewModels/GeneralSettingsViewModel.swift` — 231 строка

## 4. Что уже отрефакторено в этой ветке

### 4.1 Исправлен критичный дефект propagation языка

Ранее язык распознавания мог "залипать" и не соответствовать актуальному `settings.language`. В этой ветке исправлено:

- Протокол изменен на явную передачу языка:
  - `Murmurix/Services/Protocols.swift:26`
- Сервис транскрибации больше не держит язык как скрытое состояние:
  - `Murmurix/Services/TranscriptionService.swift:44`
- Координатор передает язык из `SettingsStorageProtocol` в каждый вызов:
  - `Murmurix/Services/RecordingCoordinator.swift:178`
- Обновлены call-sites в `GeneralSettingsViewModel`:
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift:170`
- Усилены моки и интеграционные тесты на propagation языка:
  - `MurmurixTests/Mocks.swift`
  - `MurmurixTests/IntegrationTests.swift`

### 4.2 Улучшена наблюдаемость UI-инфраструктуры

- Убран `print` из Lottie-компонента, ошибка теперь идет в централизованный логгер:
  - `Murmurix/Views/Components/LottieView.swift:56`

## 5. Приоритетные проблемы (после Phase 0)

## P0

### 5.1 Конкурентность и состояние в `RecordingCoordinator`

Симптом:

- mutable state (`state`, `currentAudioURL`, `transcriptionTask`) + `Task.detached` + ручные прыжки на `MainActor`.
- файл: `Murmurix/Services/RecordingCoordinator.swift:56`, `Murmurix/Services/RecordingCoordinator.swift:158`, `Murmurix/Services/RecordingCoordinator.swift:187`.

Риск:

- гонки при `toggle/cancel/toggle`,
- сложная диагностика отмены и повторного запуска.

Решение:

- сделать `RecordingCoordinator` `@MainActor`,
- заменить `Task.detached` на structured concurrency (`Task {}`),
- отделить state machine (чистый reducer/event model).

### 5.2 Немая обработка ошибок (`try?`) в критичном пути

Симптом:

- удаление файлов, компрессия, загрузка моделей в ряде мест выполняются через `try?` без контекста ошибки.
- примеры: `Murmurix/Services/RecordingCoordinator.swift:97`, `Murmurix/Services/RecordingCoordinator.swift:167`, `Murmurix/ViewModels/GeneralSettingsViewModel.swift:132`.

Риск:

- тихие деградации (невидимые ошибки cleanup/compress/load),
- трудно понять причину пользовательских проблем.

Решение:

- ввести helper-обертки cleanup/load с логированием причин,
- оставить `try?` только там, где ошибка действительно не влияет на UX/state.

## P1

### 5.3 Размытые границы ответственности `AppDelegate`

Симптом:

- `AppDelegate` совмещает wiring, orchestration, hotkey flow, UI window control и часть продуктовой логики.
- файл: `Murmurix/App/AppDelegate.swift:9`.

Риск:

- рост когнитивной сложности,
- высокая цена точечных изменений.

Решение:

- оставить в `AppDelegate` только composition root,
- выделить `RecordingFlowController` (orchestration),
- изолировать side-effects в адаптеры (paste/window/menu).

### 5.4 Дублирование hotkey capture и глобальное mutable состояние

Симптом:

- почти идентичная логика захвата клавиш в:
  - `Murmurix/Views/HotkeyRecorderView.swift:98`
  - `Murmurix/Views/Components/WhisperModelCardView.swift:156`
- оба места используют общий `GlobalHotkeyManager.isRecordingHotkey`.

Риск:

- рассинхрон поведения,
- сложный lifecycle мониторов NSEvent.

Решение:

- выделить `HotkeyCaptureService` (единый capture lifecycle),
- UI оставить только как биндинг + callback,
- убрать static-флаги из `GlobalHotkeyManager`.

### 5.5 Несколько источников истины для settings в UI

Симптом:

- `GeneralSettingsView` одновременно использует `@AppStorage`, `Settings.shared` и `viewModel.settings`.
- файл: `Murmurix/Views/GeneralSettingsView.swift:9`, `Murmurix/Views/GeneralSettingsView.swift:38`, `Murmurix/Views/GeneralSettingsView.swift:104`.

Риск:

- рассинхронизация состояния,
- усложнение тестирования UI.

Решение:

- внедрить единый `SettingsStore` (observable + DI),
- убрать прямые обращения к singleton из View.

### 5.6 Data layer: silent-failure API

Симптом:

- `SQLiteDatabase`/`Repository` используют `Bool`/`void` и не отдают типизированные ошибки наружу.
- файл: `Murmurix/Services/Repository.swift:40`, `Murmurix/Services/Repository.swift:116`.

Риск:

- невозможность нормального recovery,
- потеря контекста SQLite ошибок.

Решение:

- перейти на `throws` + `DatabaseError` с кодами SQLite,
- добавить versioned migrations (`PRAGMA user_version`).

### 5.7 Swift 6 readiness: `Sendable` предупреждение в сборке

Симптом:

- при `xcodebuild test` появляется предупреждение:
  - `stored property 'settings' of 'Sendable'-conforming class 'TranscriptionService' has non-Sendable type 'any SettingsStorageProtocol'`
- источник:
  - `Murmurix/Services/TranscriptionService.swift:10`
  - `Murmurix/Services/Protocols.swift:53`

Риск:

- при переходе на Swift 6 mode предупреждение станет ошибкой сборки.

Решение:

- зафиксировать actor-boundary для `TranscriptionService` (например, `@MainActor`) либо
- пересмотреть необходимость `Sendable` для класса и/или
- сделать зависимости потокобезопасными и явно совместимыми с `Sendable`.

## P2

### 5.8 Небезопасные касты и force unwrap в инфраструктуре

Симптом:

- `as!` в `TextPaster` и `first!` в path resolution.
- файлы:
  - `Murmurix/Services/TextPaster.swift:30`
  - `Murmurix/Services/TextPaster.swift:55`
  - `Murmurix/Services/HistoryService.swift:24`
  - `Murmurix/App/AppConstants.swift:107`

Решение:

- заменить на безопасные `guard let` и fallback-ветки с логированием.

### 5.9 Жизненный цикл observers

Симптом:

- `addObserver` с closure без явного token lifecycle management.
- файлы:
  - `Murmurix/App/AppDelegate.swift:34`
  - `Murmurix/Views/SettingsWindowController.swift:48`
  - `Murmurix/Views/HistoryWindowController.swift:29`

Решение:

- хранить tokens и корректно удалять в deinit/close,
- либо централизовать language-change propagation.

### 5.10 Тестовая матрица: много low-value тестов

Симптом:

- заметная доля тестов проверяет enum/cases/constants/"does not crash".
- по последнему прогону: 296 из 302 test-runs имеют `duration = 0` в `xcresult` DB.

Риск:

- метрика количества тестов высокая, но реальная защита критичных сценариев ограничена.

Решение:

- добавить сценарии гонок и отмены,
- усилить контрактные тесты orchestration-path,
- оставить smoke UI tests и убрать часть дублей по enum/const.

### 5.11 Entitlements требуют ревизии для релизной политики

Файл: `Murmurix/Murmurix.entitlements`

Включены:

- `com.apple.security.app-sandbox = false`
- `com.apple.security.cs.allow-unsigned-executable-memory = true`
- `com.apple.security.cs.disable-library-validation = true`
- `com.apple.security.automation.apple-events = true`

Риск:

- повышенная поверхность для distribution/review/security.

Решение:

- зафиксировать threat model и минимальный набор entitlement для release.

## 6. Целевая архитектура (без овер-инжиниринга)

Слой `App`:

- `AppDelegate` как composition root,
- wiring зависимостей, lifecycle hooks.

Слой `Domain`:

- `RecordingFlowStateMachine`,
- use-cases: `StartRecording`, `StopAndTranscribe`, `CancelRecording`, `CancelTranscription`,
- доменные ошибки и политики.

Слой `Infrastructure`:

- audio, db, keychain, cloud clients, whisper adapter.

Слой `Presentation`:

- SwiftUI/AppKit, тонкие view models,
- никакой прямой работы с singleton внутри View.

## 7. План внедрения (инкрементально)

## Фаза 0 (быстрые исправления)

- [x] Исправить propagation языка в транскрибации.
- [x] Убрать `print` из Lottie и перевести в `Logger`.
- [ ] Убрать silent `try?` в критичных ветках cleanup/compress.
- [ ] Добавить тест на fallback при ошибке компрессии.

## Фаза 1 (конкурентность и state machine)

- [ ] `RecordingCoordinator` -> `@MainActor`.
- [ ] Заменить `Task.detached` на structured concurrency.
- [ ] Вынести transitions в отдельный reducer.
- [ ] Добавить tests для toggle/cancel гонок.

## Фаза 2 (settings + hotkeys)

- [ ] Внедрить `SettingsStore`.
- [ ] Вынести единый `HotkeyCaptureService`.
- [ ] Убрать global mutable flags из `GlobalHotkeyManager`.
- [ ] Свести hotkey capture к одному reusable компоненту.

## Фаза 3 (cloud/domain boundaries)

- [ ] Ввести порт `CloudTranscriptionClient` и адаптеры OpenAI/Gemini.
- [ ] Нормализовать транспортные ошибки в доменные.
- [ ] Вынести language/prompt policy из сервисов API.

## Фаза 4 (data layer hardening)

- [ ] `throws`-based repository API.
- [ ] SQLite migrations (`user_version`).
- [ ] Полная диагностика SQLite-кодов в логах.

## Фаза 5 (test suite value shift)

- [ ] Сократить дубли low-value тестов.
- [ ] Добавить high-value сценарии orchestration.
- [ ] Сохранить smoke UI tests и добавить 1-2 реальных пользовательских сценария.

## 8. Definition of Done

1. Язык распознавания всегда соответствует текущим настройкам пользователя.
2. Поток `recording -> transcribing -> idle` детерминирован и устойчив к отменам/повторным нажатиям.
3. Нет критичных silent-failure в cleanup/compress/model lifecycle.
4. Settings и hotkey capture имеют единый источник истины.
5. Data layer отдает типизированные ошибки, миграции версионированы.
6. Тестовая матрица защищает критичные сценарии, а не только enum/constant проверки.

## 9. Краткий action list на следующий коммит

1. Заменить `#expect(true)`-smoke проверки в `RefactoringTests` на более предметные assertions.
2. Добавить targeted тесты для release/debug выбора `ModelPaths.repoDir` в отдельных test runs.
3. Продолжить уменьшение поверхностей singleton-доступа в `AppDelegate` и View-layer.
4. Подготовить PR-пачку по конкурентности (`RecordingCoordinator` reducer/event-model).

## 10. Прогресс этой сессии (после первичного аудита)

### 10.1 Рефакторинг и тесты

- Изолирована и упрощена логика выбора директории моделей:
  - `Murmurix/App/AppConstants.swift`
  - поведение сохранено: `custom env` > `temp env/debug` > `release documents`.
- Улучшена диагностика сериализации settings:
  - `Murmurix/Models/Settings.swift`
  - `Murmurix/Services/Logger.swift` (добавлен `Logger.Settings`).
- Убран silent-failure в проверке содержимого директории модели:
  - `Murmurix/Models/WhisperModel.swift` (добавлен debug-лог).
- Уточнены операции SQLite:
  - `Murmurix/Services/Repository.swift` (`_ = step(...)` для явного намерения).
- Усилены тесты и устранены test warnings:
  - `MurmurixTests/RefactoringTests.swift` (добавлен `settingsLoggerDoesNotCrash`, исправлены `step`-вызовы).

### 10.2 Проверка стабильности

- Полный прогон:  
  `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test`  
  результат: `** TEST SUCCEEDED **`.
- Targeted прогоны (все успешны):
  - `SettingsTests`
  - `GeneralSettingsViewModelModelTests`
  - `RefactoringAppPathsAndConstantsTests`
  - `HistoryServiceTests`
  - `SQLiteTranscriptionRepositoryTests`
  - `SQLiteDatabaseTests`
  - `LoggerTests`

### 10.3 Последние коммиты ветки

1. `02924af` `test: make sqlite step results explicit in refactoring tests`
2. `41c1182` `test: cover settings logger category`
3. `3d38cc0` `refactor: simplify model repository path selection logic`
4. `923fc06` `refactor: make sqlite delete step result explicit`
5. `526a833` `refactor: add settings logging for serialization failures`
6. `fe6c09d` `refactor: log whisper model directory read failures`
7. `3a41282` `refactor: deduplicate settings serialization helpers`
8. `0be8d56` `refactor: log audio compressor file ops failures`
