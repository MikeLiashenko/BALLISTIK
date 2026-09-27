# BALLISTIK

Тактический 3D-экшен на **Godot 4.7.2** (GDScript): авиация от поршневых истребителей 1940-х до реактивных
машин, наземная ПВО и военный флот сражаются на больших процедурных картах. Одиночный режим: игрок и боты
своей команды против команды ботов.

> Графика и звуковые эффекты генерируются **процедурно в коде**: модели самолётов строит параметрический
> генератор (лофт фюзеляжа по сечениям, крылья с профилем NACA, фонари, винты, сопла), рельеф, море, небо,
> облака, леса, текстуры шумов, опознавательные знаки (SVG в коде) и звуки (синтез `AudioStreamWAV`)
> создаются при запуске. Единственные внешние файлы — музыка в `sounds/`.

## Возможности

- **5 больших карт** (зона боя ~14×14 км, мир ~27×27 км, море до горизонта), у каждой свой климат,
  освещение и погода:

  | Карта | Климат и время | Особенности |
  |---|---|---|
  | Северное побережье | умеренный, утро | холмы, смешанные леса, поля, острова с маяком |
  | Тропический архипелаг | тропики, полдень | гористые острова, бирюзовые отмели, пальмы |
  | Пустынный залив | засушливый, дымка | плато и столовые горы, орошаемые поля у воды |
  | Северные фьорды | субарктика, пасмурно | заснеженные хребты, извилистые фьорды, ели |
  | Закатный пролив | средиземноморье, закат | два берега через пролив, кипарисы |

  Рельеф каждого боя уникален (зерно карты), стороны в равных условиях — шум рельефа симметричен
  относительно зеркала карты. Базы: аэродром, штаб, РЛС, позиции ПВО, ВМБ с причалом, эсминец.
- **Детальная графика**: сплаттинг рельефа (луга, лоскуты полей с межами и бороздами, леса, песок и мокрый
  пляж, скалы со слоями, снег), вода с цветом по глубине, прибоем и пеной, аналитическое небо с перистыми
  облаками, объёмные кучевые облака с тенями на земле, леса (MultiMesh, 2 уровня детализации), воздушная
  перспектива, тонмаппинг AgX, каскадные тени, SSAO; рельеф — чанки с 4 уровнями детализации.
- **19 самолётов** с детальными моделями, камуфляжем (пятна, «сплинтер», крап, натуральный металл),
  панельными линиями, опознавательными знаками-декалями, вращающимися винтами, форсажем, инверсионными
  следами:

  | Роль | Поршневые (1940-е) | Реактивные |
  |---|---|---|
  | Истребители | Bf 109 G-6, Fw 190 A-8, Як-9Т, Ла-5ФН, P-51D, P-40E, Spitfire Mk IX, A6M5 Zero | МиГ-29, Су-27, F-16C, F-4E Phantom II, Mirage 2000C, Rafale C |
  | Ударные | Ил-2, B-25J Mitchell | Су-24М, Су-25, A-10A |

  Вооружение из данных: пушки со сведением, ракеты «воздух-воздух» с ИК ГСН (у поршневых нет ловушек,
  зато захват их дольше), НАР, бомбы с прицелом CCIP, управляемые ракеты по выбранной цели и по метке
  тактической карты. Эпоха авиации боя: смешанная, поршневая или реактивная.
- **Наземная ПВО и флот**: ЗСУ «Гепард», ЗРК Patriot / Бук-М1, катера Sea Baby / G-5 (пулемёт, торпеды,
  баллистическая ракета до 9 км), эсминцы команд с ЗАК — стратегические цели.
- **Боты мягче**: три уровня сложности («Новобранец», «Ветеран», «Ас»); боты медлят, промахиваются,
  делают паузы перед пусками ракет, реже выбирают целью игрока, их урон по игроку снижен, ЗРК ботов
  захватывают дольше. Выбрав технику, занятую ботом своей команды, игрок вытесняет его.
- **Музыка**: треки из `sounds/` — «Briefing at Midnight» в меню, «Intercept Vector» и «Target Locked in
  Salt» в бою, плавные переходы, приглушение на паузе, отдельные громкости музыки и эффектов.
- **Меню**: кинематографичный 3D-фон (звено самолётов над случайной картой), лобби с превью карт,
  выбором эпохи и 3D-просмотром техники, **ангар** со всей техникой, экран загрузки с прогрессом.
- **Кроссплатформенность**: Windows, Linux, Android (сенсорное управление), поддержка геймпада.
  Качество графики: Низкое / Среднее / Высокое / Ультра.

Победа — по лимиту очков или по истечении времени (очки за технику, сооружения и эсминцы противника).

## Запуск

1. Установите [Godot 4.7.2](https://godotengine.org/download) (стандартная версия, не .NET).
2. Откройте `project.godot` в редакторе и нажмите **F5**, либо из командной строки:

```bash
godot --path .
```

При первом открытии редактор импортирует проект (создаст папку `.godot/`).

## Управление

**ПК (клавиатура и мышь)**

| Действие | Клавиши |
|---|---|
| Основное / дополнительное оружие | ЛКМ, Пробел / ПКМ, F |
| Тактическая карта (баллистика, управляемые ракеты) | G или СКМ |
| Ловушки · зум · режим радара 3D/2D | X · Z · T |
| Счёт · пауза · справка | Tab · Esc · F1 |
| **Авиация** | мышь — направление полёта; W/S — газ; A/D — крен; Q/E — рыскание; стрелки — ручное управление; C — камера |
| **Наземная техника и катера** | W/S — ход; A/D — поворот; мышь — обзор и прицел |
| **ЗРК** | удерживайте цель в прицеле до захвата, затем ЛКМ — пуск |
| **Тактическая карта** | ЛКМ — метка; повторный ЛКМ по метке или Enter — пуск; колесо — масштаб; WASD — сдвиг; ПКМ/G — выход |

**Геймпад**: левый стик — движение, правый — обзор, триггеры — оружие, A — карта, B — ловушки, Y — радар.

**Android**: плавающий джойстик слева, обзор перетаскиванием по правой половине экрана, кнопки оружия, газа
и ловушек; в тактическом режиме касание ставит метку, «ПУСК» — запуск.

## Архитектура

```mermaid
flowchart LR
    GS[GameSettings] --> MM[MainMenuUI<br/>меню, лобби, ангар]
    MU[MusicPlayer] --- MM
    MM -->|слоты, карта, старт| GBM[GlobalBattleManager<br/>слоты, роли, очки, спавн]
    GBM -->|change_scene| BL[BattleLevel<br/>генерация в фоне]
    BL --> ML[MapLayout + Terrain<br/>TerrainSampler] --> TR[TerrainRenderer<br/>чанки + LOD]
    BL --> AT[Atmosphere] & W[WaterSurface] & CF[CloudField] & VG[Vegetation]
    GBM -->|spawn| V[Vehicle]
    V --> A[Aircraft ← AircraftBuilder]
    V --> G[AAGun / SAMLauncher]
    V --> B[PatrolBoat / Warship]
    AI[BotAI] -->|VehicleControls| V
    PC[PlayerController] -->|VehicleControls| V
```

Техника не знает, кто ею управляет: игрок (`PlayerController`) и бот (`BotAI`) заполняют одну и ту же
структуру `VehicleControls`. Самолёты полностью описаны данными (`GameDB` — лётные характеристики и оружие,
`AircraftSpecs` — геометрия и окраска).

```
res://
├── autoload/        GameSettings, SoundFX, MusicPlayer, GlobalBattleManager
├── scenes/          MainMenu.tscn, BattleLevel.tscn
├── sounds/          музыка (mp3)
├── scripts/
│   ├── core/        GameDB (техника, роли, сложность), BallisticSolver, Weapon, VehicleControls, Participant
│   ├── procedural/  AircraftBuilder, AircraftSpecs, Insignia, VehicleModels, TreeMeshes, MeshKit, StructureModels…
│   ├── vehicles/    Vehicle, Aircraft, GroundVehicle → AAGun/SAMLauncher, PatrolBoat, Warship
│   ├── weapons/     Projectile, GuidedMissile, Rocket, BallisticMissile, CruiseMissile, Bomb, Torpedo, Explosion, Flare
│   ├── world/       MapPresets, MapLayout, Terrain, TerrainSampler, TerrainMeshBuilder, TerrainRenderer,
│   │                WaterSurface, Atmosphere, CloudField, Vegetation, MapPreview, BattleLevel, CameraRig…
│   ├── fx/          Effects, ShaderLib (шейдеры), ProcTextures (процедурные текстуры), FallingWreck
│   └── ui/          MainMenuUI, MenuBackdrop, ModelViewer, SlotSelector, SettingsPanel, HUD, HUDOverlay…
├── tests/           compile_check, map_previews (миникарты и замер генерации), hangar_shots (рендер моделей)
└── tools/           export.ps1, export.sh
```

Тяжёлая генерация (сетка высот, меши чанков, расстановка леса, облака) идёт в фоновых потоках; каждый
поток рельефа использует свой `TerrainSampler` (вызовы методов общих объектов движка из разных потоков
сериализуются, чистая математика GDScript — масштабируется).

## Сборка (Export) через Godot CLI

Версия шаблонов экспорта должна совпадать с версией редактора — **4.7.2.stable**.

| Платформа | Что нужно |
|---|---|
| Windows `.exe`, Linux | Godot 4.7.2 + шаблоны экспорта 4.7.2 |
| Android `.apk` | дополнительно OpenJDK 17 и Android SDK: `platform-tools`, `build-tools;35.0.1`, `platforms;android-35` |

Windows (PowerShell):

```powershell
.\tools\export.ps1 -Godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" -Targets windows,android -InstallTemplates
```

Linux / macOS:

```bash
GODOT=~/bin/Godot_v4.7.2-stable_linux.x86_64 ./tools/export.sh --targets "linux windows android" --install-templates
```

Команды напрямую:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" build/windows/BALLISTIK.exe
godot --headless --path . --export-release "Linux" build/linux/BALLISTIK.x86_64
godot --headless --path . --export-debug "Android" build/android/BALLISTIK-debug.apk
```

Release-APK подписывается ключом из переменных `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD`.

### CI (GitHub Actions)

`.github/workflows/build.yml` на каждый push в `main` и pull request: скачивает Godot 4.7.2 и шаблоны,
компилирует все скрипты, прогоняет бои ботов на всех картах и тесты ручного управления, экспортирует
Windows `.exe`, Linux и Android `.apk`. При пуше тега `v*` сборки публикуются в GitHub Release.

## Автотесты

```bash
# компиляция всех скриптов
godot --headless --path . res://tests/compile_check.tscn

# бой ботов 45 с без окна на заданной карте (coast, archipelago, desert, fjords, strait)
godot --headless --path . -- --smoke-test --smoke-seconds=45 --smoke-map=coast

# ручное управление + удар по метке тактической карты
godot --headless --path . -- --smoke-test --smoke-human --smoke-tactical --smoke-vehicle=su25 --smoke-seconds=30

# миникарты всех карт и время генерации рельефа
godot --headless --path . --script res://tests/map_previews.gd -- --out=/tmp/maps --res=1024

# рендер моделей техники (нужно окно)
godot --path . --script res://tests/hangar_shots.gd -- --out=/tmp/hangar --types=bf109,p51,mig29
```

Параметры запуска: `--smoke-vehicle=<тип>` (например `bf109`, `a10`, `boat`), `--smoke-era=0|1|2`,
`--shots=DIR` — скриншоты, `--touch` — сенсорный интерфейс на ПК, `--quality=0..3` — качество графики.
