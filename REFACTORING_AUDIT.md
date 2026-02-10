# Murmurix Refactoring Audit (Deep)

Дата: 2026-02-09  
Последнее обновление: 2026-02-09 15:42  
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
- [x] Убрать silent `try?` в критичных ветках cleanup/compress.
- [x] Добавить тест на fallback при ошибке компрессии.

## Фаза 1 (конкурентность и state machine)

- [x] `RecordingCoordinator` -> `@MainActor`.
- [x] Заменить `Task.detached` на structured concurrency.
- [x] Вынести transitions в отдельный reducer.
- [x] Добавить tests для toggle/cancel гонок.

## Фаза 2 (settings + hotkeys)

- [x] Внедрить `SettingsStore`.
- [x] Вынести единый `HotkeyCaptureService`.
- [x] Убрать global mutable flags из `GlobalHotkeyManager`.
- [x] Свести hotkey capture к одному reusable компоненту.

## Фаза 3 (cloud/domain boundaries)

- [x] Ввести порт `CloudTranscriptionClient` и адаптеры OpenAI/Gemini.
- [x] Нормализовать транспортные ошибки в доменные.
- [x] Вынести language/prompt policy из сервисов API.

## Фаза 4 (data layer hardening)

- [x] `throws`-based repository API.
- [x] SQLite migrations (`user_version`).
- [x] Полная диагностика SQLite-кодов в логах.

## Фаза 5 (test suite value shift)

- [x] Сократить дубли low-value тестов.
- [x] Добавить high-value сценарии orchestration.
- [x] Сохранить smoke UI tests и добавить 1-2 реальных пользовательских сценария.

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

### 10.4 Продолжение (текущий цикл рефакторинга)

- Уменьшена связность и дубли в orchestration-слое:
  - `Murmurix/Services/RecordingCoordinator.swift`
  - выделены отдельные этапы подготовки входного аудио и завершения транскрибации (success/failure).
- Нормализован `MenuBarManager`:
  - `Murmurix/App/MenuBarManager.swift`
  - переиспользуемые builders для local/cloud menu items и базовых пунктов меню.
- Упрощены сервисы API и модели:
  - `Murmurix/Services/OpenAITranscriptionService.swift` (общие multipart request/body builders),
  - `Murmurix/Services/TranscriptionService.swift` (единая проверка API key для cloud-провайдеров),
  - `Murmurix/Services/WhisperKitService.swift` (единый helper для unload pipeline),
  - `Murmurix/Services/Logger.swift` (централизация dispatch по уровням логирования).
- Усилена тестопригодность выбора пути моделей:
  - `Murmurix/App/AppConstants.swift`
  - `MurmurixTests/RefactoringTests.swift`
  - добавлены предметные тесты приоритета path selection:
    - `custom path` имеет приоритет над temp/debug,
    - `MURMURIX_USE_TEMP_MODEL_REPO=1` форсирует temp repo,
    - `MURMURIX_USE_TEMP_MODEL_REPO=0` форсирует persistent documents path.

### 10.5 Проверка стабильности (текущий цикл)

- Все прогоны выполнялись с:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1`
- Успешные targeted прогоны:
  - `AppConstantsTests`
  - `RefactoringTests`
  - `RecordingCoordinatorTests`
  - `GeneralSettingsViewModelModelTests`
  - `AudioCompressorErrorTests`
  - `OpenAITranscriptionServiceDITests`
  - `MockURLSessionTests`
  - `IntegrationTests`
  - `NewFunctionalityTests`

### 10.6 Последние коммиты (актуальная серия)

1. `464dbdf` `refactor: make model repo path resolution testable`
2. `4a7de44` `refactor: share whisper pipeline unload helper`
3. `2144c60` `refactor: deduplicate cloud api key checks in transcription service`
4. `a92efad` `refactor: share openai multipart request builders`
5. `0b8c9b1` `refactor: reuse local menu item builders in menu bar manager`
6. `9468a2d` `refactor: split transcription path resolution and completion handlers`
7. `abd4b5d` `refactor: centralize logger level dispatch helpers`
8. `27bc48f` `refactor: simplify model base path derivation`

### 10.7 Singleton surface reduction (дополнение)

- Убрана прямая зависимость `AppDelegate` от `WhisperKitService.shared`:
  - `Murmurix/App/AppDelegate.swift`
  - источник loaded models теперь берется через `TranscriptionServiceProtocol`.
- Расширен контракт транскрипционного сервиса:
  - `Murmurix/Services/Protocols.swift` (`loadedModelNames()`),
  - `Murmurix/Services/TranscriptionService.swift` (делегирование в `WhisperKitServiceProtocol`).
- Обновлены test doubles и интеграционный контрактный тест:
  - `MurmurixTests/Mocks.swift`,
  - `MurmurixTests/IntegrationTests.swift` (`loadedModelNamesReflectWhisperKitState`).
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/RecordingCoordinatorTests` -> `** TEST SUCCEEDED **`,
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/TranscriptionServiceIntegrationTests/loadedModelNamesReflectWhisperKitState` -> `** TEST SUCCEEDED **`.

### 10.8 AppDelegate как composition root (incremental)

- `AppDelegate` переведен на фабрики зависимостей:
  - `Murmurix/App/AppDelegate.swift`
  - добавлены `makeAudioRecorder` и `makeTranscriptionService`,
  - `init(...)` теперь принимает DI-параметры с безопасными дефолтами.
- Ослаблена связность по concrete types:
  - `audioRecorder` хранится как `any AudioRecorderProtocol`,
  - `transcriptionService` хранится как `any TranscriptionServiceProtocol`.
- `WindowManager` принимает протокол вместо concrete recorder:
  - `Murmurix/App/WindowManager.swift` (`showRecordingWindow(audioRecorder: any AudioRecorderProtocol, ...)`).
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/RecordingCoordinatorTests -only-testing:MurmurixTests/TranscriptionServiceIntegrationTests/loadedModelNamesReflectWhisperKitState` -> `** TEST SUCCEEDED **`.

### 10.9 Убраны singleton-дефолты в UI/ViewModel/Manager слоях

- Удалены скрытые `Settings.shared/HistoryService.shared` из default init-параметров:
  - `Murmurix/App/MenuBarManager.swift`
  - `Murmurix/Services/GlobalHotkeyManager.swift`
  - `Murmurix/ViewModels/SettingsStore.swift`
  - `Murmurix/ViewModels/HistoryViewModel.swift`
  - `Murmurix/Views/GeneralSettingsView.swift`
  - `Murmurix/Views/SettingsView.swift`
  - `Murmurix/Views/SettingsWindowController.swift`
  - `Murmurix/Views/HistoryView.swift`
  - `Murmurix/Views/HistoryWindowController.swift`
- Обновлены тесты, где раньше использовались неявные дефолтные зависимости:
  - `MurmurixTests/MurmurixTests.swift` (`GlobalHotkeyManagerTests` теперь используют `MockSettings`).
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/MurmurixTests -only-testing:MurmurixTests/SettingsStoreTests` -> `** TEST SUCCEEDED **`,
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/GlobalHotkeyManagerTests` -> `** TEST SUCCEEDED **`.

### 10.10 Явная DI-передача history service в window-layer

- Убрана скрытая зависимость `HistoryWindowController` от `HistoryService.shared`:
  - `Murmurix/Views/HistoryWindowController.swift` (обязательный `historyService` в init).
- `WindowManager` теперь принимает `HistoryServiceProtocol` в конструкторе и переиспользует его:
  - `Murmurix/App/WindowManager.swift`.
- `AppDelegate` передает `historyService` в `WindowManager` как часть composition root:
  - `Murmurix/App/AppDelegate.swift`.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HistoryViewModelTests -only-testing:MurmurixTests/HistoryServiceTests` -> `** TEST SUCCEEDED **`.

### 10.11 Вынесен live composition root в `AppDependencies`

- В `AppDelegate` введен структурный контейнер зависимостей:
  - `Murmurix/App/AppDelegate.swift` (`AppDependencies` + `AppDependencies.live()`).
- `AppDelegate` теперь инициализируется через единый контейнер:
  - `init(dependencies: AppDependencies = .live())`.
- Это устраняет рассыпанные default-параметры в конструкторе `AppDelegate` и упрощает future DI для интеграционных сценариев.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/RecordingCoordinatorTests -only-testing:MurmurixTests/HistoryViewModelTests` -> `** TEST SUCCEEDED **`.

### 10.12 HistoryViewModel: переход с GCD на structured concurrency

- Заменён механизм отложенного выбора записи:
  - `DispatchWorkItem + DispatchQueue.main.async`
  - на `Task<Void, Never> + cancel + Task.yield()`.
- Изменён файл:
  - `Murmurix/ViewModels/HistoryViewModel.swift`.
- Эффект:
  - единый async-подход в view-model слое,
  - более явная отмена pending update без GCD work item.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HistoryViewModelTests -only-testing:MurmurixTests/HistoryServiceTests` -> `** TEST SUCCEEDED **`.

### 10.13 Window layer: явная main-thread изоляция

- UI-оркестратор и window controllers зафиксированы как `@MainActor`:
  - `Murmurix/App/WindowManager.swift`
  - `Murmurix/Views/SettingsWindowController.swift`
  - `Murmurix/Views/HistoryWindowController.swift`
  - `Murmurix/Views/RecordingWindowController.swift`
  - `Murmurix/Views/ResultWindowController.swift`
- Эффект:
  - compile-time защита от случайных вызовов UI API вне main thread,
  - более явная actor-boundary для AppKit/SwiftUI окна слоя.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/MurmurixTests` -> `** TEST SUCCEEDED **`.
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/NewFunctionalityTests -only-testing:MurmurixTests/RecordingCoordinatorTests` -> `** TEST SUCCEEDED **`.

### 10.14 Observer lifecycle в window controllers

- Подписки на `appLanguageDidChange` в window-layer переведены на lifecycle окна:
  - подписка стартует в `showWindow`,
  - подписка снимается в `windowWillClose`.
- Изменены файлы:
  - `Murmurix/Views/SettingsWindowController.swift`
  - `Murmurix/Views/HistoryWindowController.swift`
- Эффект:
  - observer не живет дольше, чем открытое окно,
  - снижена вероятность накопления лишних подписок при повторных открытиях.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/MurmurixTests -only-testing:MurmurixTests/HistoryViewModelTests -only-testing:MurmurixTests/NewFunctionalityTests` -> `** TEST SUCCEEDED **`.

### 10.15 TranscriptionService: явная DI-конфигурация без скрытых singleton-дефолтов

- Убран singleton-based default init у `TranscriptionService`:
  - `Murmurix/Services/TranscriptionService.swift`
  - новый фабричный entry-point `TranscriptionService.live(settings:)`.
- Обновлен composition root и view-model fallback:
  - `Murmurix/App/AppDelegate.swift` (использует `TranscriptionService.live(settings:)`),
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift` (default factory теперь строится от переданного `settings`).
- Обновлены DI/интеграционные тесты на явные зависимости:
  - `MurmurixTests/IntegrationTests.swift`
  - `MurmurixTests/RefactoringTests.swift`
- Эффект:
  - меньше скрытых зависимостей от `shared`,
  - прозрачнее граница production wiring vs тестовые doubles.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/TranscriptionServiceIntegrationTests -only-testing:MurmurixTests/DependencyInjectionTests -only-testing:MurmurixTests/Phase3Tests` -> `** TEST SUCCEEDED **`.

### 10.16 GeneralSettingsViewModel: cancellable reset-status вместо GCD delay

- В `GeneralSettingsViewModel` заменен `DispatchQueue.main.asyncAfter` на cancellable `Task`:
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift`
  - добавлена карта `statusResetTasks` на модель и явная отмена pending reset при новом старте/отмене download.
- Эффект:
  - более предсказуемое поведение при повторных `startDownload/cancelDownload`,
  - единый structured-concurrency стиль в view-model слое.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/GeneralSettingsViewModelAPITests -only-testing:MurmurixTests/GeneralSettingsViewModelSettingsDITests` -> `** TEST SUCCEEDED **`.

### 10.17 UI delayed updates: перевод на cancellable Task

- `SettingsWindowController`:
  - убран `DispatchQueue.main.asyncAfter` для delayed model-status update,
  - добавлены cancellable задачи по модели (`modelStatusUpdateTasks`) и отмена pending tasks при закрытии окна/перезагрузке состояния.
- `HistoryDetailView`:
  - reset индикатора `copied` переведен с `DispatchQueue.main.asyncAfter` на `Task.sleep`,
  - добавлена отмена pending reset-task в `onDisappear`.
- Изменены файлы:
  - `Murmurix/Views/SettingsWindowController.swift`
  - `Murmurix/Views/History/HistoryDetailView.swift`
- Эффект:
  - меньше риска stale UI-апдейтов при быстрых повторных действиях,
  - более единообразный structured-concurrency подход в UI-слое.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/HistoryViewModelTests -only-testing:MurmurixTests/MurmurixTests` -> `** TEST SUCCEEDED **`.

### 10.18 HotkeyCaptureService: main-dispatch через structured concurrency

- В `HotkeyCaptureService` заменён `DispatchQueue.main.async` в monitor callbacks на `Task { @MainActor ... }`.
- Изменен файл:
  - `Murmurix/Services/HotkeyCaptureService.swift`
- Эффект:
  - единообразный concurrency-стиль без GCD в hotkey-capture path,
  - сохранено прежнее поведение доставки key events на main actor.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HotkeyCaptureServiceTests -only-testing:MurmurixTests/GlobalHotkeyManagerTests` -> `** TEST SUCCEEDED **`.

### 10.19 TextPaster: delayed paste-steps через Task.sleep

- В `TextPaster` helper `scheduleMain` переведен с `DispatchQueue.main.asyncAfter` на `Task { @MainActor } + Task.sleep`.
- Изменен файл:
  - `Murmurix/Services/TextPaster.swift`
- Эффект:
  - единый async-подход для delayed UI side-effects в paste flow.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/TextPasterTests -only-testing:MurmurixTests/MurmurixTests` -> `** TEST SUCCEEDED **`.

### 10.20 AudioRecorder: устранен последний main-dispatch через GCD

- В `AudioRecorder.runOnMain` заменен `DispatchQueue.main.async` на `Task { @MainActor ... }`.
- Изменен файл:
  - `Murmurix/Services/AudioRecorder.swift`
- Эффект:
  - единый подход доставки UI-bound обновлений через structured concurrency.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/AudioRecorderTests -only-testing:MurmurixTests/RecordingCoordinatorTests` -> `** TEST SUCCEEDED **`.
- Текущее состояние after-pass:
  - в прод-коде не осталось вхождений `DispatchQueue.main.async` и `DispatchQueue.main.asyncAfter`.

### 10.21 HistoryWindowController: убрать IUO в view model

- В `HistoryWindowController` удалён `HistoryViewModel!` и введён строго инициализируемый `let historyViewModel`.
- Инициализатор контроллера переписан с `convenience` на designated init с явной инициализацией зависимостей.
- Изменен файл:
  - `Murmurix/Views/HistoryWindowController.swift`
- Эффект:
  - исключен класс потенциальных runtime-ошибок из-за implicitly-unwrapped optional в window-layer.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HistoryViewModelTests -only-testing:MurmurixTests/HistoryServiceTests -only-testing:MurmurixTests/MurmurixTests` -> `** TEST SUCCEEDED **`.

### 10.22 RecordingWindowController: убрать IUO у audio observer

- В `RecordingWindowController` удалён `AudioLevelObserver!` и введён строго инициализируемый `let audioLevelObserver`.
- Создание observer перенесено в инициализацию свойства до `super.init`, чтобы исключить окно неконсистентного состояния.
- Изменен файл:
  - `Murmurix/Views/RecordingWindowController.swift`
- Эффект:
  - исключен класс потенциальных runtime-ошибок из-за implicitly-unwrapped optional в recording window-layer.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/RecordingCoordinatorTests -only-testing:MurmurixTests/RecordingCoordinatorModelControlTests` -> `** TEST SUCCEEDED **`.

### 10.23 AppDelegate runtime safety: убрать IUO-поля и token-based observer lifecycle

- В `AppDelegate` заменены IUO-поля runtime-объектов (`menuBarManager`, `windowManager`, `hotkeyManager`, `audioRecorder`, `transcriptionService`, `coordinator`) на безопасные optional-ссылки.
- Добавлен явный token lifecycle для language observer:
  - регистрация через `addObserver(forName:queue:using:)`,
  - удаление через `removeObserver(token)` в `applicationWillTerminate`.
- Все вызовы к runtime-сервисам переведены на безопасный доступ без implicit unwrap.
- Изменен файл:
  - `Murmurix/App/AppDelegate.swift`
- Эффект:
  - исключен класс потенциальных crash из-за IUO при ранних/поздних lifecycle-callbacks,
  - observer lifecycle стал детерминированным и локализованным в одном token.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/RecordingCoordinatorTests -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/AppConstantsTests` -> `** TEST SUCCEEDED **`.

### 10.24 Settings flow DI: явный factory для GeneralSettingsViewModel

- Добавлен explicit live-factory `GeneralSettingsViewModel.live(settings:)`.
- Вся settings-цепочка переведена на явную передачу фабрики view model:
  - `AppDelegate` (`AppDependencies`) -> `WindowManager` -> `SettingsWindowController` -> `SettingsView` -> `GeneralSettingsView`.
- Создание `GeneralSettingsViewModel` больше не зашито внутри `GeneralSettingsView`.
- Изменены файлы:
  - `Murmurix/App/AppDelegate.swift`
  - `Murmurix/App/WindowManager.swift`
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift`
  - `Murmurix/Views/GeneralSettingsView.swift`
  - `Murmurix/Views/SettingsView.swift`
  - `Murmurix/Views/SettingsWindowController.swift`
- Эффект:
  - уменьшена скрытая singleton-surface в settings view-layer,
  - live-конфигурация зависимостей для settings стала централизованной в composition root.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/SettingsTests -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/GeneralSettingsViewModelAPITests` -> `** TEST SUCCEEDED **`.

### 10.25 RefactoringTests: усилены WindowPositioner assertions

- Переписан блок `WindowPositionerTests` в `RefactoringTests`:
  - убраны smoke-тесты формата `doesNotCrash`,
  - добавлены проверки вычисляемых координат для `positionTopCenter`,
  - добавлены устойчивые проверки инвариантов для `center` и `centerAndActivate`.
- Изменен файл:
  - `MurmurixTests/RefactoringTests.swift`
- Эффект:
  - тесты проверяют наблюдаемое поведение позиционирования окна, а не только отсутствие падения.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/WindowPositionerTests` -> `** TEST SUCCEEDED **`.

### 10.26 MenuBarManager: убрать IUO у status item/menu

- В `MenuBarManager` убраны IUO-поля:
  - `statusItem: NSStatusItem!` -> `NSStatusItem?`
  - `menu: NSMenu!` -> `NSMenu?`
- Логика сборки меню переведена на безопасный доступ:
  - `setupMenu` собирает локальный `NSMenu` и атомарно присваивает `self.menu`,
  - `updateLocalModelMenuItems` работает только если меню уже инициализировано (`guard let menu`),
  - назначение меню для status item через optional chaining.
- Изменен файл:
  - `Murmurix/App/MenuBarManager.swift`
- Эффект:
  - исключен класс потенциальных runtime-crash из-за неинициализированных IUO в menu-bar lifecycle.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/AppConstantsTests -only-testing:MurmurixTests/RecordingCoordinatorTests` -> `** TEST SUCCEEDED **`.

### 10.27 GeneralSettingsViewModel init: убрать default singleton-зависимости

- В `GeneralSettingsViewModel` удалены default singleton-параметры из designated init:
  - теперь все зависимости (`whisperKit/openAI/gemini/settings/path closures`) передаются явно.
- Для сохранения удобства тестов добавлен единый тестовый helper:
  - `makeGeneralSettingsViewModel(...)` в `MurmurixTests/Mocks.swift`.
- Обновлены call-sites в тестах с прямого `GeneralSettingsViewModel(...)` на helper:
  - `MurmurixTests/Phase3Tests.swift`
  - `MurmurixTests/NewFunctionalityTests.swift`
- Изменены файлы:
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift`
  - `MurmurixTests/Mocks.swift`
  - `MurmurixTests/NewFunctionalityTests.swift`
  - `MurmurixTests/Phase3Tests.swift`
- Эффект:
  - в прод-коде исключены скрытые singleton defaults в VM initializer,
  - тестовая инициализация централизована и стала явно управляемой.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/GeneralSettingsViewModelAPITests -only-testing:MurmurixTests/Phase3GeneralSettingsViewModelTests` -> `** TEST SUCCEEDED **`.

### 10.28 OpenAI/Gemini services: убрать default singleton-зависимости в init

- В сервисах cloud-транскрибации удалены default singleton-параметры из designated init:
  - `OpenAITranscriptionService(session:promptPolicy:)`
  - `GeminiTranscriptionService(promptPolicy:)`
- `shared` сохранен, но теперь строится явно через конкретные зависимости:
  - `URLSession.shared`
  - `DefaultTranscriptionPromptPolicy.shared`
- Обновлены DI-тесты под новый явный контракт конструктора:
  - `MurmurixTests/Phase2Tests.swift`
- Изменены файлы:
  - `Murmurix/Services/OpenAITranscriptionService.swift`
  - `Murmurix/Services/GeminiTranscriptionService.swift`
  - `MurmurixTests/Phase2Tests.swift`
- Эффект:
  - снижена скрытая singleton-surface в domain/service слое,
  - конструкторы сервисов стали полностью явными и тесто-дружелюбными.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/OpenAITranscriptionServiceDITests -only-testing:MurmurixTests/GeminiModelTests` -> `** TEST SUCCEEDED **`.

### 10.29 GeneralSettingsViewModel: сделать transcriptionServiceFactory обязательной зависимостью

- В `GeneralSettingsViewModel` убран optional-fallback для `transcriptionServiceFactory`:
  - сигнатура init теперь принимает `@escaping () -> TranscriptionServiceProtocol` без `?` и без скрытого `TranscriptionService.live(...)`.
- В тестовом helper `makeGeneralSettingsViewModel(...)` задан явный default:
  - `transcriptionServiceFactory: { MockTranscriptionService() }`.
- Изменены файлы:
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift`
  - `MurmurixTests/Mocks.swift`
- Эффект:
  - устранен еще один скрытый singleton/live-fallback в VM-конструкторе,
  - контракт зависимостей VM полностью явный как в prod, так и в tests.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/GeneralSettingsViewModelAPITests -only-testing:MurmurixTests/Phase3GeneralSettingsViewModelTests` -> `** TEST SUCCEEDED **`.

### 10.30 HistoryService: убрать optional default-repository из init

- В `HistoryService` убран optional-параметр конструктора:
  - `init(repository: SQLiteTranscriptionRepository? = nil)` -> `init(repository: SQLiteTranscriptionRepository)`.
- `shared` сохранен через явную live-конфигурацию:
  - `HistoryService(repository: HistoryService.makeDefaultRepository())`.
- Изменен файл:
  - `Murmurix/Services/HistoryService.swift`
- Эффект:
  - убран скрытый fallback на дефолтный репозиторий из конструктора,
  - контракт DI для history-сервиса стал полностью явным.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HistoryServiceTests -only-testing:MurmurixTests/SQLiteTranscriptionRepositoryTests` -> `** TEST SUCCEEDED **`.

### 10.31 HotkeyCaptureService: убрать скрытую default-зависимость monitor manager

- В `HotkeyCaptureService` удален default-конструктор зависимости:
  - `init(monitorManager: HotkeyEventMonitorManaging = NSEventMonitorManager())`
  - заменен на явный `init(monitorManager:)`.
- Добавлен явный live-factory:
  - `HotkeyCaptureService.live()` -> `NSEventMonitorManager()`.
- Обновлен прод call-site в UI:
  - `HotkeyRecorderView` теперь использует `HotkeyCaptureService.live()` вместо неявного `HotkeyCaptureService()`.
- Изменены файлы:
  - `Murmurix/Services/HotkeyCaptureService.swift`
  - `Murmurix/Views/HotkeyRecorderView.swift`
- Эффект:
  - скрытый dependency fallback убран из hotkey-capture сервиса,
  - live wiring стало явным и согласованным с остальным DI-подходом.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HotkeyCaptureServiceTests -only-testing:MurmurixTests/GlobalHotkeyManagerTests` -> `** TEST SUCCEEDED **`.

### 10.32 AppDelegate init: сделать live-зависимости явными в main composition root

- В `AppDelegate` удален default `dependencies: .live()` из конструктора:
  - `init(dependencies: AppDependencies)` теперь требует явную передачу зависимостей.
- В `main.swift` явная инициализация делегата:
  - `AppDelegate(dependencies: .live())`.
- Изменены файлы:
  - `Murmurix/App/AppDelegate.swift`
  - `Murmurix/main.swift`
- Эффект:
  - composition root стал полностью явным,
  - убран еще один скрытый live-fallback в app entrypoint.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/RecordingCoordinatorTests -only-testing:MurmurixTests/AppConstantsTests` -> `** TEST SUCCEEDED **`.

### 10.33 Settings init: убрать default `.standard` из конструктора

- В `Settings` удален default `UserDefaults.standard` в конструкторе:
  - `init(defaults: UserDefaults)` теперь требует явную передачу storage.
- `shared` сохранен через явную live-конфигурацию:
  - `Settings(defaults: .standard)`.
- Изменен файл:
  - `Murmurix/Models/Settings.swift`
- Эффект:
  - убран скрытый fallback на `.standard` внутри init,
  - контракт инициализации settings стал полностью явным и стабильным для тестов/DI.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/SettingsTests -only-testing:MurmurixTests/Phase4Tests` -> `** TEST SUCCEEDED **`.

### 10.34 Preview isolation: убрать shared storage/services из SwiftUI previews

- В `SettingsView` preview убрана привязка к `Settings.shared`:
  - preview теперь использует отдельный `UserDefaults` suite и `Settings(defaults:)`.
- В `HistoryView` preview убрана привязка к `HistoryService.shared`:
  - preview теперь использует отдельный временный SQLite-файл и локальный `HistoryService(repository:)`.
- Изменены файлы:
  - `Murmurix/Views/SettingsView.swift`
  - `Murmurix/Views/HistoryView.swift`
- Эффект:
  - SwiftUI previews перестали опираться на production shared storage/history,
  - снижены риски побочных эффектов на рабочие данные во время разработки.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/AppConstantsTests` -> `** TEST SUCCEEDED **`.

### 10.35 Settings flow factories: убрать лишний проброс settings через AppDelegate -> Window layer

- Упрощены фабрики в `AppDependencies`:
  - `makeTranscriptionService` теперь `() -> TranscriptionServiceProtocol`,
  - `makeGeneralSettingsViewModel` теперь `@MainActor () -> GeneralSettingsViewModel`.
- В `AppDependencies.live()` обе фабрики захватывают `settings` из composition root напрямую.
- Соответственно обновлены сигнатуры в window-layer:
  - `WindowManager.showSettingsWindow(... makeGeneralSettingsViewModel: @MainActor () -> GeneralSettingsViewModel, ...)`
  - `SettingsWindowController` вызывает `makeGeneralSettingsViewModel()` без повторного проброса `settings`.
- Изменены файлы:
  - `Murmurix/App/AppDelegate.swift`
  - `Murmurix/App/WindowManager.swift`
  - `Murmurix/Views/SettingsWindowController.swift`
- Эффект:
  - устранен лишний plumbing одного и того же `settings` по нескольким слоям,
  - уменьшена вероятность рассинхронизации настроек между сервисным и window-слоем.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/AppConstantsTests -only-testing:MurmurixTests/SettingsTests` -> `** TEST SUCCEEDED **`.

### 10.36 Service live wiring: убрать скрытый `.shared` внутри live-фабрик сервисов и VM

- Убрано чтение singleton-зависимостей изнутри `live`-фабрик доменного/VM-слоя:
  - `TranscriptionService.live(...)` теперь принимает все сервисы явно,
  - `GeneralSettingsViewModel.live(...)` теперь принимает сервисы явно и строит `transcriptionServiceFactory` через переданные зависимости.
- Явное live-связывание вынесено в composition root:
  - `AppDependencies.live()` теперь один раз создает `WhisperKitService`, `OpenAITranscriptionService`, `GeminiTranscriptionService` и передает их в фабрики `TranscriptionService` и `GeneralSettingsViewModel`.
- Preview тоже переведен на явное wiring:
  - `SettingsView` preview теперь создает те же live-сервисы явно и передает их в `GeneralSettingsViewModel.live(...)`.
- Изменены файлы:
  - `Murmurix/Services/TranscriptionService.swift`
  - `Murmurix/ViewModels/GeneralSettingsViewModel.swift`
  - `Murmurix/App/AppDelegate.swift`
  - `Murmurix/Views/SettingsView.swift`
- Эффект:
  - уменьшена singleton-surface в сервисном и viewmodel-слое,
  - live-конфигурация централизована в composition root,
  - поведение осталось прежним (включая временный репозиторий моделей для тестов/разработки).
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/TranscriptionServiceIntegrationTests -only-testing:MurmurixTests/GeneralSettingsViewModelAPITests -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/AppConstantsTests` -> `** TEST SUCCEEDED **`.

### 10.37 AppDependencies bootstrap: убрать `shared` из live-композиции и стабилизировать language observer без sendable-warning

- `HistoryService` получил явный live-factory:
  - `HistoryService.live()` добавлен как основной способ собрать production instance,
  - `HistoryService.shared` теперь делегирует в `live()`.
- В `AppDependencies.live()` убраны прямые обращения к singleton storage/service:
  - `Settings.shared` -> `Settings(defaults: .standard)`,
  - `HistoryService.shared` -> `HistoryService.live()`.
- `AppDelegate` language observer переведен на selector-based API `NotificationCenter`:
  - убран closure-callback с `Task` и захватом `self`,
  - удален token-based `languageObserver` storage,
  - cleanup выполняется через `removeObserver(self, name: .appLanguageDidChange, ...)`.
- Изменены файлы:
  - `Murmurix/Services/HistoryService.swift`
  - `Murmurix/App/AppDelegate.swift`
- Эффект:
  - composition root стал менее зависим от singleton-глобалей,
  - устранен sendable-warning в `AppDelegate` observer path,
  - runtime-поведение (включая модельные пути для dev/test) сохранено.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/HistoryServiceTests -only-testing:MurmurixTests/SettingsTests -only-testing:MurmurixTests/RecordingCoordinatorTests -only-testing:MurmurixTests/AppConstantsTests` -> `** TEST SUCCEEDED **`.
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/AppConstantsTests` (после фикса observer API) -> `** TEST SUCCEEDED **`.

### 10.38 Удаление неиспользуемых singleton entrypoints после переноса DI в composition root

- Удалены неиспользуемые `static shared` entrypoints у сервисов/storage, которые больше не участвуют в runtime wiring:
  - `Settings.shared`,
  - `HistoryService.shared`,
  - `WhisperKitService.shared`,
  - `OpenAITranscriptionService.shared`,
  - `GeminiTranscriptionService.shared`.
- При этом сохранены явные live-конструкторы/инициализация через composition root:
  - `HistoryService.live()` оставлен как основной production factory,
  - `AppDependencies.live()` продолжает создавать и передавать concrete сервисы явно.
- Изменены файлы:
  - `Murmurix/Models/Settings.swift`
  - `Murmurix/Services/HistoryService.swift`
  - `Murmurix/Services/WhisperKitService.swift`
  - `Murmurix/Services/OpenAITranscriptionService.swift`
  - `Murmurix/Services/GeminiTranscriptionService.swift`
- Эффект:
  - уменьшена мертвая глобальная поверхность,
  - снижена вероятность случайного обхода composition root в будущем.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/Phase2Tests -only-testing:MurmurixTests/TranscriptionServiceIntegrationTests -only-testing:MurmurixTests/GeneralSettingsViewModelModelTests -only-testing:MurmurixTests/SettingsTests -only-testing:MurmurixTests/HistoryServiceTests` -> `** TEST SUCCEEDED **`.

### 10.39 Prompt policy wiring: убрать singleton-паттерн у `DefaultTranscriptionPromptPolicy`

- Удален `DefaultTranscriptionPromptPolicy.shared`.
- Все call-sites переведены на явное создание value-типа:
  - `DefaultTranscriptionPromptPolicy()` в `AppDependencies.live()` и preview wiring,
  - тесты `Phase2` и `TranscriptionPromptPolicyTests` обновлены соответственно.
- Изменены файлы:
  - `Murmurix/Services/TranscriptionPromptPolicy.swift`
  - `Murmurix/App/AppDelegate.swift`
  - `Murmurix/Views/SettingsView.swift`
  - `MurmurixTests/Phase2Tests.swift`
  - `MurmurixTests/TranscriptionPromptPolicyTests.swift`
- Эффект:
  - singleton-surface сокращена еще на один системный компонент,
  - DI-контур для prompt policy полностью явный.
- Проверка:
  - `MURMURIX_USE_TEMP_MODEL_REPO=1 ... xcodebuild ... test -only-testing:MurmurixTests/Phase2Tests -only-testing:MurmurixTests/TranscriptionPromptPolicyTests -only-testing:MurmurixTests/AppConstantsTests` -> `** TEST SUCCEEDED **`.
