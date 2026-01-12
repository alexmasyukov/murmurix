# Промпт для продолжения рефакторинга Murmurix

## Контекст

Murmurix - macOS Menu Bar приложение для голосовой транскрипции (Whisper, OpenAI, Gemini).

## Что было сделано

### Phase 1 ✅ DONE (код + тесты)

1. **Добавлены моки** в `MurmurixTests/Mocks.swift`:
   - `MockDaemonManager`
   - `MockHotkeyManager`
   - `MockTranscriptionRepository`

2. **Созданы утилиты**:
   - `Models/APITestResult.swift` - enum результата теста API
   - `Services/AudioTestUtility.swift` - генерация WAV файлов
   - `Services/MIMETypeResolver.swift` - определение MIME типов

3. **DRY рефакторинг**:
   - Hotkey методы в `Settings.swift` (private helpers)
   - Удален дублированный код из `OpenAITranscriptionService` и `GeminiTranscriptionService`

4. **Протоколы**:
   - `TranscriptionRepositoryProtocol` в `Repository.swift`

5. **Тесты** в `MurmurixTests/Phase1Tests.swift`:
   - AudioTestUtilityTests (13 тестов)
   - MIMETypeResolverTests (12 тестов)
   - APITestResultTests (8 тестов)
   - MockDaemonManager tests (8 тестов)
   - MockHotkeyManager tests (6 тестов)
   - MockTranscriptionRepository tests (8 тестов)

## Что нужно сделать

### Phase 2 (Improve Testability)
```
1. Абстрагировать URLSession (протокол + мок)
2. Извлечь UnixSocketClient из TranscriptionService/DaemonManager
3. Убрать Settings.shared из GeneralSettingsView (использовать DI)
4. Перенести testLocalModel/testOpenAI/testGemini из View в ViewModel
```

### Phase 3 (Code Quality)
```
1. Разбить GeneralSettingsView на секции (656 строк)
2. Убрать @unchecked Sendable (4 места)
3. Добавить Process/FileManager абстракции
```

## Ключевые файлы

- `REFACTORING_PLAN.md` - полный план с деталями
- `MurmurixTests/Phase1Tests.swift` - тесты Phase 1
- `MurmurixTests/Mocks.swift` - все моки

## Команда для запуска тестов

```bash
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix -destination 'platform=macOS' test
```

## Начни с

```
Прочитай REFACTORING_PLAN.md и начни Phase 2 с абстракции URLSession
```
