# Dual Local Models — план

## Идея

Два слота локальных моделей: **Local Fast** (tiny/small) для быстрых коротких фраз и **Local Full** (medium/large) для серьёзных распознаваний. Каждый со своей горячей клавишей и своим WhisperKit пайплайном в памяти.

## Текущее состояние

- 1 `WhisperKitService` с одним `WhisperKit` пайплайном в памяти
- 1 горячая клавиша для локальной модели (`^C`)
- 1 настройка `whisperModel` в Settings

## Ключевые изменения

### 1. WhisperKitService — два пайплайна

Сейчас один `whisperKit: WhisperKit?`. Нужно:

```swift
pipelines: [String: WhisperKit]   // "tiny" → pipeline, "medium" → pipeline
```

Методы `loadModel`/`unloadModel`/`transcribe` принимают имя модели и работают с нужным пайплайном.

### 2. Память

| Конфигурация | RAM |
|---|---|
| tiny + medium | ~200MB + ~1.5GB = ~1.7GB |
| small + medium | ~500MB + ~1.5GB = ~2GB |
| tiny + small | ~200MB + ~500MB = ~700MB |

На Mac с 16GB+ это нормально.

### 3. Settings — два слота

```swift
whisperModelFast: String    // "tiny"
whisperModelFull: String    // "medium"
keepFastModelLoaded: Bool
keepFullModelLoaded: Bool
```

### 4. Горячие клавиши — 5 вместо 4

| Клавиша | Действие |
|---|---|
| `^C` | Local Fast (tiny) |
| `^V` или другая | Local Full (medium) |
| `^D` | OpenAI |
| `^G` | Gemini |
| `Esc` | Cancel |

### 5. TranscriptionMode — расширить

Сейчас: `.local`, `.openai`, `.gemini`

Варианты:
- **Вариант А**: `.localFast`, `.localFull`, `.openai`, `.gemini` — просто, понятно
- **Вариант Б**: `.local(model: String)` — гибче, но ассоциированное значение усложнит Equatable/CaseIterable

Вариант А проще и достаточен.

### 6. UI в Settings

Вместо одной секции "Local (Whisper)" — две:
- **Local Fast** — выбор модели, keep loaded, test
- **Local Full** — выбор модели, keep loaded, test

## Объём изменений

| Файл | Что менять |
|---|---|
| `WhisperKitService` | Словарь пайплайнов вместо одного |
| `TranscriptionMode` | + `.localFast`, `.localFull` (убрать `.local`) |
| `Settings` | + `whisperModelFast/Full`, `keepFastModelLoaded/Full`, hotkey |
| `Hotkey` | + `toggleLocalFullDefault` |
| `GlobalHotkeyManager` | + `onToggleLocalFullRecording` |
| `RecordingCoordinator` | Роутинг по новым режимам |
| `TranscriptionService` | Два вызова WhisperKit с разными моделями |
| `GeneralSettingsView` | Две секции Local |
| `GeneralSettingsViewModel` | Управление двумя моделями |
| `MenuBarManager` | + пункт меню |

Примерно ~15 файлов, но изменения в каждом небольшие — паттерн уже есть (так же добавляли Gemini).
