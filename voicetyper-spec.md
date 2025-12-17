# Murmurix — голосовой ввод для macOS

## Обзор проекта

Нативное macOS-приложение для голосового ввода текста с локальным распознаванием речи и опциональной AI-постобработкой для технических терминов.

**Основной сценарий:** Нажал горячие клавиши → надиктовал → текст вставился в активное поле ввода.

## Архитектура

```
┌─────────────────────────────────────────────────┐
│              Murmurix.app (Swift)             │
├─────────────────────────────────────────────────┤
│  SwiftUI Interface                              │
│  ├── Menubar icon + dropdown                    │
│  ├── Settings window                            │
│  └── Recording indicator overlay                │
├─────────────────────────────────────────────────┤
│  Core Services                                  │
│  ├── GlobalHotkeyManager (CGEvent tap)          │
│  ├── AudioRecorder (AVFoundation)               │
│  ├── TranscriptionService (subprocess → Python) │
│  └── TextPaster (CGEvent keystroke simulation)  │
└─────────────────────────────────────────────────┘
                        │
                        ▼ subprocess call
┌─────────────────────────────────────────────────┐
│           transcribe.py (Python)                │
├─────────────────────────────────────────────────┤
│  faster-whisper (модель "small", ~460MB)        │
│  Опционально: Claude Haiku постобработка        │
└─────────────────────────────────────────────────┘
```

## Технический стек

### Swift-часть
- **Язык:** Swift 5.9+
- **UI:** SwiftUI
- **Минимальная macOS:** 13.0 (Ventura)
- **Frameworks:**
  - `AVFoundation` — запись аудио
  - `Carbon` / `CoreGraphics` — глобальные hotkeys
  - `AppKit` — NSWorkspace для определения активного приложения
  - `ServiceManagement` — автозапуск

### Python-часть
- **Python:** 3.11+
- **Библиотеки:**
  - `faster-whisper` — локальное распознавание
  - `anthropic` — опционально, для Haiku постобработки

## Компоненты Swift

### 1. AppDelegate / Main App
```swift
// Menubar-only приложение
@main
struct MurmurixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
```

Приложение живёт в menubar, не показывает иконку в Dock.

### 2. GlobalHotkeyManager
Регистрация глобального сочетания клавиш (по умолчанию: `⌥ Option` дважды или `Fn`).

Использовать `CGEvent.tapCreate` для перехвата клавиш на уровне системы.

**Требует:** Accessibility permissions в System Settings.

### 3. AudioRecorder
```swift
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    
    func startRecording() -> URL  // Возвращает путь к temp .wav файлу
    func stopRecording() -> URL
}
```

**Формат записи:**
- WAV, 16kHz, mono, 16-bit PCM
- Whisper лучше всего работает с этими параметрами

**Требует:** Microphone permissions.

### 4. TranscriptionService
```swift
class TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        // 1. Найти Python в bundle или по известному пути
        // 2. Запустить subprocess: python transcribe.py <audio_path>
        // 3. Прочитать stdout — это распознанный текст
        // 4. Вернуть текст
    }
}
```

**Важно:**
- Python-скрипт и модель Whisper bundled с приложением или в `~/Library/Application Support/Murmurix/`
- Первый запуск: скачать модель если нет

### 5. TextPaster
```swift
class TextPaster {
    func paste(_ text: String) {
        // 1. Сохранить текущий clipboard
        // 2. Положить text в clipboard (NSPasteboard)
        // 3. Симулировать Cmd+V через CGEvent
        // 4. Восстановить предыдущий clipboard (опционально, с задержкой)
    }
}
```

**Требует:** Accessibility permissions.

### 6. SettingsView
```swift
struct SettingsView: View {
    // Настройки:
    // - Выбор горячей клавиши
    // - Язык распознавания (ru/en/auto)
    // - Включить/выключить Haiku постобработку
    // - API ключ Anthropic (если Haiku включен)
    // - Автозапуск при логине
    // - Показывать overlay при записи
}
```

Хранить в `UserDefaults` или `@AppStorage`.

### 7. RecordingOverlay
Небольшое плавающее окошко или индикатор в углу экрана, показывающий что идёт запись.

```swift
struct RecordingOverlay: View {
    // Пульсирующий красный кружок
    // Текст "Говорите..." 
    // Может показывать уровень громкости
}
```

## Python-модуль

### transcribe.py
```python
#!/usr/bin/env python3
"""
Использование: python transcribe.py <audio_path> [--language ru] [--haiku] [--api-key KEY]
Выводит распознанный текст в stdout.
"""

import sys
import argparse
from faster_whisper import WhisperModel

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audio_path", help="Путь к аудиофайлу")
    parser.add_argument("--language", default="ru", help="Язык распознавания")
    parser.add_argument("--haiku", action="store_true", help="Постобработка через Claude Haiku")
    parser.add_argument("--api-key", help="Anthropic API key для Haiku")
    parser.add_argument("--model-path", help="Путь к модели Whisper")
    args = parser.parse_args()
    
    # Загрузка модели
    model_path = args.model_path or "small"
    model = WhisperModel(model_path, device="cpu", compute_type="int8")
    
    # Распознавание
    segments, _ = model.transcribe(
        args.audio_path,
        language=args.language,
        vad_filter=True  # Убирает тишину
    )
    text = " ".join(segment.text.strip() for segment in segments)
    
    # Опциональная постобработка через Haiku
    if args.haiku and args.api_key:
        text = postprocess_with_haiku(text, args.api_key)
    
    print(text)

def postprocess_with_haiku(text: str, api_key: str) -> str:
    """Исправление технических терминов через Claude Haiku."""
    import anthropic
    
    client = anthropic.Anthropic(api_key=api_key)
    
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"""Исправь технические термины в тексте. Не меняй смысл, только исправь названия технологий, функций, команд.

Примеры исправлений:
- "юз стейт" → "useState"
- "реакт" → "React"
- "тайпскрипт" → "TypeScript"
- "консоль лог" → "console.log"
- "гит коммит" → "git commit"

Текст: {text}

Верни только исправленный текст, без пояснений."""
        }]
    )
    
    return response.content[0].text

if __name__ == "__main__":
    main()
```

### requirements.txt
```
faster-whisper>=1.0.0
anthropic>=0.40.0
```

### Установка Python-окружения
```bash
# Создать venv в Application Support
python3 -m venv ~/Library/Application\ Support/Murmurix/venv
source ~/Library/Application\ Support/Murmurix/venv/bin/activate
pip install -r requirements.txt

# Скачать модель заранее (опционально)
python -c "from faster_whisper import WhisperModel; WhisperModel('small')"
```

## User Flow

### Первый запуск
1. Приложение запускается
2. Проверяет наличие Python-окружения, если нет — предлагает установить
3. Запрашивает Accessibility permissions
4. Запрашивает Microphone permissions
5. Показывает onboarding с выбором hotkey и языка
6. Готово к работе

### Обычное использование
1. Пользователь работает в любом приложении (VSCode, Telegram, браузер...)
2. Нажимает hotkey (например, двойной Option)
3. Появляется индикатор записи
4. Пользователь говорит
5. Нажимает hotkey снова (или пауза 2 сек — авто-стоп)
6. Индикатор показывает "Распознаю..."
7. Текст вставляется в позицию курсора
8. Индикатор исчезает

### Ошибки
- Нет доступа к микрофону → показать alert с кнопкой открыть System Settings
- Нет Accessibility → показать alert с инструкцией
- Python не найден → предложить установить
- Распознавание failed → показать notification с ошибкой

## Структура проекта

```
Murmurix/
├── Murmurix.xcodeproj
├── Murmurix/
│   ├── App/
│   │   ├── MurmurixApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── MenuBarView.swift
│   │   ├── SettingsView.swift
│   │   └── RecordingOverlay.swift
│   ├── Services/
│   │   ├── GlobalHotkeyManager.swift
│   │   ├── AudioRecorder.swift
│   │   ├── TranscriptionService.swift
│   │   └── TextPaster.swift
│   ├── Models/
│   │   └── AppSettings.swift
│   ├── Resources/
│   │   └── transcribe.py
│   └── Info.plist
├── Python/
│   ├── transcribe.py
│   └── requirements.txt
└── README.md
```

## Info.plist ключи

```xml
<!-- Menubar-only app -->
<key>LSUIElement</key>
<true/>

<!-- Описания для permissions -->
<key>NSMicrophoneUsageDescription</key>
<string>Murmurix использует микрофон для записи голосовых сообщений и преобразования их в текст.</string>
```

## Этапы разработки

### Фаза 1: MVP
- [ ] Базовый menubar app
- [ ] Запись аудио в файл
- [ ] Вызов Python subprocess
- [ ] Вставка текста через Cmd+V
- [ ] Простой hotkey (например, Cmd+Shift+V)

### Фаза 2: Polish
- [ ] Настраиваемый hotkey
- [ ] Overlay при записи
- [ ] Settings window
- [ ] Автозапуск

### Фаза 3: Advanced
- [ ] Haiku интеграция
- [ ] Контекстные словари (разные для разных приложений)
- [ ] История распознаваний
- [ ] Автоопределение языка

## Заметки

### Accessibility permissions
Для симуляции нажатий клавиш нужно добавить приложение в:
`System Settings → Privacy & Security → Accessibility`

При разработке в Xcode — добавить сам Xcode туда же.

### Размер модели Whisper
- `small` модель: ~460MB
- При первом запуске faster-whisper скачает её в `~/.cache/huggingface/`
- Можно bundled с приложением, но увеличит размер .app

### Производительность на M1
- `small` модель с `compute_type="int8"` даёт ~10x realtime на M1
- Т.е. 10 секунд аудио распознаются за ~1 секунду
- Metal acceleration через `device="auto"` если установлен ctranslate2 с поддержкой

### Альтернатива subprocess
Если subprocess кажется костылём — можно использовать whisper.cpp через Swift напрямую (есть Swift bindings). Но это сложнее в настройке.
