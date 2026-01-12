# Промпт для продолжения рефакторинга Murmurix

## Контекст

Murmurix - macOS Menu Bar приложение для голосовой транскрипции (Whisper, OpenAI, Gemini).

## Что было сделано

### Phase 1 ✅ DONE (код + тесты)

1. **Моки** в `MurmurixTests/Mocks.swift`:
   - MockDaemonManager, MockHotkeyManager, MockTranscriptionRepository

2. **Утилиты**:
   - `Models/APITestResult.swift`
   - `Services/AudioTestUtility.swift`
   - `Services/MIMETypeResolver.swift`

3. **DRY рефакторинг**: hotkey методы, удален дублированный код

4. **Тесты** в `MurmurixTests/Phase1Tests.swift` - 55 тестов

### Phase 2 ✅ DONE (код + тесты)

1. **URLSession абстракция**:
   - `URLSessionProtocol` в `Protocols.swift`
   - DI в `OpenAITranscriptionService`
   - `MockURLSession` в `Mocks.swift`

2. **UnixSocketClient**:
   - `Services/UnixSocketClient.swift` - SocketClientProtocol, SocketError
   - DI в `TranscriptionService` и `DaemonManager`
   - `MockSocketClient` в `Mocks.swift`

3. **Тесты** в `MurmurixTests/Phase2Tests.swift` - 20 тестов

## Что нужно сделать

### Phase 3 (Code Quality + Deferred)
```
1. Remove Settings.shared from Views (use DI)
2. Move test logic from GeneralSettingsView to ViewModel
3. Split GeneralSettingsView into sections (~656 lines)
4. Remove @unchecked Sendable (4 места)
5. Add Process/FileManager abstractions
```

### Phase 4 (Polish)
```
1. Documentation (DocC comments)
2. Keychain key enum
3. Swift 6 strict concurrency preparation
```

## Ключевые файлы

- `REFACTORING_PLAN.md` - полный план
- `MurmurixTests/Phase1Tests.swift` - тесты Phase 1
- `MurmurixTests/Phase2Tests.swift` - тесты Phase 2
- `MurmurixTests/Mocks.swift` - все моки
- `Murmurix/Services/UnixSocketClient.swift` - сокет-клиент

## Статистика тестов

| Файл | Тестов |
|------|--------|
| Phase1Tests.swift | 55 |
| Phase2Tests.swift | 20 |
| Всего новых | 75 |

## Команда для запуска тестов

```bash
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix -destination 'platform=macOS' test
```

## Начни с

```
Прочитай REFACTORING_PLAN.md и начни Phase 3 с удаления Settings.shared из GeneralSettingsView
```
