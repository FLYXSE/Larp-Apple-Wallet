# Apple Wallet Clone (SwiftUI, iOS)

Клон Apple Wallet на SwiftUI: стопка карт, добавление «выдуманных» карт с фото из галереи, редактирование и **симуляция Apple Pay** (двойное нажатие → Face ID → наклон к считывателю → успех).

- Полностью **офлайн**: ни сети, ни аналитики, ни аккаунтов, ни PassKit.
- Данные — локально в `Documents/` (`wallet.json`, `settings.json`, `CardImages/*.jpg`).
- Язык интерфейса — русский, приложение всегда тёмное.
- Артефакт сборки — `.ipa` через GitHub Actions (**по умолчанию без подписи**).

> Это демо-режим. Приложение ничего не списывает и никуда не передаёт данные: собственные SwiftUI-вьюхи имитируют системный интерфейс оплаты (см. §7 ТЗ).

---

## Требования

| Что | Версия |
|---|---|
| Xcode | 16.x (в CI закреплён Xcode 16.x на `macos-15`) |
| XcodeGen | 4.x (`brew install xcodegen`) |
| Swift language mode | 5 (`SWIFT_VERSION = 5.0` — в `project.yml`; в самом ТЗ указан «Swift 5.9+», это версия компилятора, режим языка — Swift 5) |
| Минимальная версия iOS | 16.0 |

Сторонних зависимостей нет — только системные фреймворки (SwiftUI, PhotosUI, CoreMotion, LocalAuthentication, MediaPlayer, UIKit).

---

## Структура

```
Apple Wallet Clone/
├── ТЗ.md                          # техническое задание
├── project.yml                    # манифест XcodeGen (источник истины)
├── .github/workflows/build-ipa.yml
├── Config/
│   ├── ExportOptions-Development.plist
│   ├── ExportOptions-AdHoc.plist
│   └── ExportOptions-Unsigned.plist
├── Sources/
│   ├── AppleWalletCloneApp.swift
│   ├── Models/                    # WalletCard, Transaction, CardType/Network
│   ├── Services/                  # WalletStore, ImageStore, SettingsStore,
│   │                              # PaymentFlowController, MotionTiltDetector,
│   │                              # VolumeButtonObserver, Haptics
│   ├── Views/                     # WalletHome, стопка, детали, формы, кроп
│   │   └── ApplePay/              # шторка оплаты + Face ID/NFC/Success-вьюхи
│   └── Resources/                 # Assets.xcassets (AppIcon 1024), Localizable.xcstrings
└── Tests/WalletStoreTests.swift   # юнит-тесты хранилища
```

`.xcodeproj` **не коммитится** — он генерируется из `project.yml` командой `xcodegen generate` (и локально, и в CI).

---

## Сборка .ipa через GitHub Actions

1. Создайте репозиторий на GitHub и запушьте проект:
   ```bash
   cd "Apple Wallet Clone"
   git init -b main
   git add .
   git commit -m "Apple Wallet Clone"
   git remote add origin https://github.com/ВАШ_ЮЗЕР/ВАШ_РЕПО.git
   git push -u origin main
   ```
2. Откройте вкладку **Actions** → workflow **Build IPA** запустится сам на `push`
   (вручную: *Run workflow* → режим `signed` / `unsigned`, по умолчанию `signed`).
3. Скачайте артефакт **AppleWalletClone-ipa** — внутри `AppleWalletClone.ipa`.
   При пуше в `main` `.ipa` дополнительно прикрепляется к Release с тегом `build-<номер сборки>`.

### Режимы сборки

| Режим | Когда | Секреты | Что происходит |
|---|---|---|---|
| `unsigned` | каждый `push` (и ручной запуск с input `unsigned`) | не нужны | `xcodebuild build` с `CODE_SIGNING_ALLOWED=NO`, `.app` упаковывается в `Payload/` и zip-уется вручную |
| `signed` (по умолчанию для ручного запуска) | ручной запуск (*Run workflow*) | нужны (см. ниже) | `xcodebuild archive` (ручная подпись: имя профиля читается из `.mobileprovision`) + `exportArchive` |

### Secrets для режима `signed`

| Secret | Содержимое |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `.p12` сертификата, закодированный в base64: `base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | пароль от `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | `.mobileprovision`, base64 |
| `KEYCHAIN_PASSWORD` | любой пароль для временного keychain раннера |
| `TEAM_ID` | идентификатор команды разработчика (10 символов) |

Сертификат и профиль можно получить бесплатным Apple ID (Xcode → *Accounts* → *Manage Certificates*, портал разработчика → профили) либо создать самоподписанный сертификат — см. §8.4 ТЗ.

---

## Локальная сборка

```bash
brew install xcodegen
xcodegen generate

xcodebuild build \
  -project AppleWalletClone.xcodeproj \
  -scheme AppleWalletClone \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Тесты хранилища (на симуляторе, из Xcode или):

```bash
xcodebuild test \
  -project AppleWalletClone.xcodeproj \
  -scheme AppleWalletClone \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Установка на iPhone

`.ipa` в режиме `unsigned` собран **без подписи** — его подписывает sideload-инструмент:

- **Sideloadly** (Windows/Mac) — перетащите `AppleWalletClone.ipa`, укажите свой Apple ID;
- **AltStore / SideStore** — импорт `.ipa` через AltServer или приложение;
- **ESign / Scarlet / Feather** — установка через их приложения;
- **TrollStore** (только устройства с уязвимостями) — установка без переподписи.

**Важно:** бесплатный Apple ID даёт подпись на **7 дней** — раз в неделю нужно переустанавливать/переподписывать приложение (AltServer умеет делать это автоматически). Платный Apple Developer Account продлевает подпись до 90 дней (для сайдлоада) / года (для App Store).

Проект **не предназначен для публикации в App Store** (названия/иконки, эмуляция системного интерфейса).

---

## Как пройти демо-сценарий оплаты

1. Нажмите **+** и добавьте карту (номер может быть выдуманным — 16 цифр), при желании выберите фото из галереи и обрежьте его.
2. Нажмите круглую кнопку **оплаты** в правом нижнем углу (FAB).
3. В шторке **дважды тапните реплику боковой кнопки** справа от рамки (второй тап ≤ 0.4 c).
4. **Face ID** (~1.2 с): реальная проверка запускается для реализма, но результат не блокирует оплату (флаг «Требовать успешный Face ID» в настройках меняет это поведение).
5. **«Приложите iPhone к считывателю»**: наклоните устройство ≥ 25° и удерживайте ≥ 0.7 с.
   - *Fallback на симуляторе* (датчик недоступен): удерживайте палец на карте ≥ 1.5 с.
   - *Опционально:* в настройках включите «Аппаратные кнопки громкости» — двойное нажатие кнопки громкости заменит реплику боковой кнопки (только на физическом устройстве).
6. **Успех**: зелёная галка, хаптик, автозакрытие через 1.5 с. Транзакция «DEMO STORE» появится в «ПОСЛЕДНИЕ ОПЕРАЦИИ» карты.

Также работают: свайп вниз / «Отмена» (выход из любого состояния), таймаут 20 с на состоянии «приложите к считывателю» (возврат с текстом «Повторите»), свайп влево/вправо по карте (выбор другой карты).

**Настройки** открываются **долгим нажатием на кнопку «+»**: сумма и продавец демо-оплаты, флаги Face ID и кнопок громкости.

---

## Ограничения (важно)

- iOS **не позволяет** приложению перехватывать нажатия боковой (Side/Power) кнопки — поэтому в шторке есть её **экранная реплика** (основной механизм) и опциональный триггер по кнопкам громкости.
- Никакого реального NFC/PassKit/платежей — только собственные SwiftUI-вьюхи (в шторке есть маркер «Демо»).
- Только iPhone, portrait, iOS 16+.
- В `Info.plist` присутствует `NSPhotoLibraryUsageDescription` (обложка карты); камера/микрофон/NFC не используются. Выбор фото идёт через `PhotosPicker` (внешний процесс), поэтому прямого доступа к медиатеке нет и отказ в доступе не ломает сценарий добавления карты.

---

## Приёмка

Соответствует приёмочным критериям §10 ТЗ: фон `#000000`, peek-стопка 80pt (72pt на 375pt), радиус 10pt, тень 0.5/8/24, шапка «Кошелёк» 34pt + «+» 32pt, без таб-бара, spring 0.5/0.8 с хаптиками, полный цикл симуляции оплаты, артефакт `.ipa` в Actions (unsigned — без секретов), 0 сетевых запросов, VoiceOver-подписи.
