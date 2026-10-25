# Godot Engine CLI 레퍼런스 가이드 (Godot CLI Reference)

## 1. 엔진 버전 정보 (`Godot.exe --version`)

```text
4.6.2.stable.mono.official.71f334935
Godot Engine v4.6.2.stable.mono.official.71f334935 - https://godotengine.org
```

> **참고 (Windows 환경):** `Godot-console.exe` 래퍼는 동일 경로의 `<base>_console.exe` 대신 `<base>.exe`를 호출하므로, `Godot-console.exe`라는 이름으로 실행 시 `Godot-.exe not found`가 발생할 수 있습니다. CLI 및 Headless 실행 시에는 `Godot.exe --headless ...`를 사용합니다.

---

## 2. 사용법 및 옵션 범례 (Usage & Legend)

```text
Usage:
  Godot.exe [options] [path to "project.godot" file]

Option legend (this build = editor):
  R  Available in editor builds, debug export templates and release export templates. (에디터, 디버그/릴리즈 템플릿 모두 사용 가능)
  D  Available in editor builds and debug export templates only. (에디터 및 디버그 템플릿 전용)
  X  Only available in editor builds, and export templates compiled with `disable_path_overrides=false`. (에디터 및 경로 오버라이드 허용 빌드 전용)
  E  Only available in editor builds. (에디터 빌드 전용)
```

---

## 3. 카테고리별 CLI 옵션 및 한국어 주석

### 3.1 일반 옵션 (General options)

| 플래그 | 구분 | 영문 설명 | 한국어 설명 |
|---|---|---|---|
| `-h`, `--help` | R | Display this help message. | 도움말 메시지를 출력합니다. |
| `--version` | R | Display the version string. | Godot 엔진 버전 문자열을 출력합니다. |
| `-v`, `--verbose` | R | Use verbose stdout mode. | 상세 로그 출력(Verbose) 모드를 활성화합니다. |
| `--quiet` | R | Quiet mode, silences stdout messages. Errors are still displayed. | 일반 표준 출력 메시지를 숨기고 에러만 출력합니다. |
| `--no-header` | R | Do not print engine version and rendering driver/method header on startup. | 시작 시 엔진 버전 및 렌더링 드라이버 헤더 출력을 생략합니다. |

### 3.2 실행 옵션 (Run options)

| 플래그 | 구분 | 영문 설명 | 한국어 설명 |
|---|---|---|---|
| `--`, `++` | R | Separator for user-provided arguments (`OS.get_cmdline_user_args()`). | 사용자 정의 인자 구분자입니다. 이후 인자는 `OS.get_cmdline_user_args()`로 읽습니다. |
| `-e`, `--editor` | E | Start the editor instead of running the scene. | 씬 실행 대신 에디터를 실행합니다. (Headless 워크플로우에서는 GUI 실행 금지) |
| `-p`, `--project-manager` | E | Start the project manager, even if a project is auto-detected. | 프로젝트 매니저를 강제로 실행합니다. |
| `--recovery-mode` | E | Start the editor in recovery mode. | 크래시 유발 요소(툴 스크립트, 플러그인 등)를 비활성화한 복구 모드로 실행합니다. |
| `--debug-server <uri>` | E | Start the editor debug server (`tcp://127.0.0.1:6007`). | 에디터 디버그 서버를 지정 URI로 시작합니다. |
| `--dap-port <port>` | E | Use the specified port for the GDScript Debug Adapter Protocol. | GDScript DAP 포트를 지정합니다 (권장: 1024~49151). |
| `--lsp-port <port>` | E | Use the specified port for the GDScript Language Server Protocol. | GDScript LSP 포트를 지정합니다 (권장: 1024~49151). |
| `--quit` | R | Quit after the first iteration. | 첫 프레임(1회 반복) 실행 후 즉시 종료합니다. |
| `--quit-after <int>` | R | Quit after the given number of iterations. Set to 0 to disable. | 지정한 프레임(반복) 횟수만큼 실행한 뒤 자동 종료합니다. |
| `-l`, `--language <locale>` | R | Use a specific locale (<locale> being a two-letter code). | 특정 로케일(2자리 언어 코드)로 실행합니다. |
| `--path <directory>` | X | Path to a project (<directory> must contain a "project.godot" file). | `project.godot`가 위치한 프로젝트 디렉터리 경로를 지정합니다. |
| `--scene <path>` | X | Path or UID of a scene in the project that should be started. | 시작할 특정 씬의 경로(`res://...`) 또는 UID를 지정합니다. |
| `--main-pack <file>` | X | Path to a pack (.pck) file to load. | 로드할 `.pck` 리소스 팩 파일 경로를 지정합니다. |
| `--render-thread <mode>` | R | Render thread mode ("unsafe", "safe", "separate"). | 렌더 스레드 모드를 설정합니다. |
| `--remote-fs <address>` | D | Remote filesystem (`<host/IP>[:<port>]` address). | 원격 파일시스템 주소를 지정합니다. |
| `--remote-fs-password <pwd>` | D | Password for remote filesystem. | 원격 파일시스템 비밀번호를 지정합니다. |
| `--audio-driver <driver>` | R | Audio driver ["WASAPI", "Dummy"]. | 오디오 드라이버를 선택합니다 (`Dummy`는 무음/Headless용). |
| `--display-driver <driver>` | R | Display driver ["windows", "headless"]. | 디스플레이 드라이버를 지정합니다. |
| `--audio-output-latency <ms>` | R | Override audio output latency in milliseconds (default is 15 ms). | 오디오 출력 지연 시간(ms)을 설정합니다. |
| `--rendering-method <name>` | R | Renderer name. Requires driver support. | 렌더러 방식(`forward_plus`, `mobile`, `gl_compatibility`)을 지정합니다. |
| `--rendering-driver <drv>` | R | Rendering driver (depends on display driver). | 렌더링 드라이버(`vulkan`, `d3d12`, `opengl3`, `dummy`)를 지정합니다. |
| `--gpu-index <device_index>` | R | Use a specific GPU. | 사용할 GPU 인덱스를 지정합니다. |
| `--text-driver <driver>` | R | Text driver (used for font rendering, bidirectional support and shaping). | 텍스트 렌더링 드라이버를 지정합니다. |
| `--tablet-driver <driver>` | R | Pen tablet input driver. | 펜 태블릿 입력 드라이버를 지정합니다. |
| `--headless` | R | Enable headless mode (`--display-driver headless --audio-driver Dummy`). | **핵심:** 창과 오디오 없이 실행하는 Headless 모드를 활성화합니다. 서버, CI, `--script` 테스트에 필수입니다. |
| `--log-file <file>` | R | Write output/error log to the specified path. | 표준 출력/에러 로그를 지정한 파일에 기록합니다. |
| `--write-movie <file>` | R | Write a video to the specified path (usually `.avi` or `.png`). | 실행 화면을 영상(`.avi` 또는 `.png` 시퀀스)으로 녹화합니다. |

### 3.3 디스플레이 옵션 (Display options)

| 플래그 | 구분 | 영문 설명 | 한국어 설명 |
|---|---|---|---|
| `-f`, `--fullscreen` | R | Request fullscreen mode. | 전체 화면 모드로 실행합니다. |
| `-m`, `--maximized` | R | Request a maximized window. | 창 최대화 상태로 실행합니다. |
| `-w`, `--windowed` | R | Request windowed mode. | 창 모드로 실행합니다. |
| `-t`, `--always-on-top` | R | Request an always-on-top window. | 항상 위(Always-on-top) 창으로 설정합니다. |
| `--resolution <W>x<H>` | R | Request window resolution. | 창 해상도를 지정합니다 (예: `640x480`). |
| `--position <X>,<Y>` | R | Request window position. | 창 시작 위치 좌표를 지정합니다. |
| `--screen <N>` | R | Request window screen. | 창을 띄울 모니터 번호를 지정합니다. |
| `--single-window` | R | Use a single window (no separate subwindows). | 서브윈도우 분리 없이 단일 창 모드로 실행합니다. |
| `--xr-mode <mode>` | R | Select XR (Extended Reality) mode ["default", "off", "on"]. | XR 모드를 설정합니다. |
| `--wid <window_id>` | R | Request parented to window. | 특정 부모 윈도우 ID에 귀속시킵니다. |
| `--accessibility <mode>` | R | Select accessibility mode ['auto', 'always', 'disabled']. | 접근성(스크린 리더 연동) 모드를 설정합니다. |

### 3.4 디버그 옵션 (Debug options)

| 플래그 | 구분 | 영문 설명 | 한국어 설명 |
|---|---|---|---|
| `-d`, `--debug` | R | Debug (local stdout debugger). | 로컬 표준 출력 디버거를 활성화합니다. |
| `-b`, `--breakpoints` | R | Breakpoint list as `source::line` comma-separated pairs. | 중단점 목록을 지정합니다. |
| `--ignore-error-breaks` | R | If debugger is connected, prevents sending error breakpoints. | 디버거 연결 시 에러 중단점 발생을 무시합니다. |
| `--profiling` | R | Enable profiling in the script debugger. | 스크립트 프로파일링을 활성화합니다. |
| `--gpu-profile` | R | Show a GPU profile of the tasks that took the most time. | 프레임 렌더링 중 GPU 작업 프로파일을 표시합니다. |
| `--gpu-validation` | R | Enable graphics API validation layers for debugging. | 그래픽 API 검증 레이어를 활성화합니다. |
| `--gpu-abort` | D | Abort on graphics API usage errors. | 그래픽 API 오류 발생 시 즉시 중단합니다. |
| `--generate-spirv-debug-info` | R | Generate SPIR-V debug information (Vulkan only). | RenderDoc 디버깅을 위한 SPIR-V 디버그 정보를 생성합니다. |
| `--extra-gpu-memory-tracking` | R | Enables additional memory tracking (Vulkan only). | 추가 GPU 메모리 추적을 활성화합니다. |
| `--accurate-breadcrumbs` | R | Force barriers between breadcrumbs (Vulkan only). | GPU 리셋 추적용 브레드크럼 배리어를 강제합니다. |
| `--remote-debug <uri>` | R | Remote debug (`<protocol>://<host/IP>[:<port>]`). | 원격 디버거에 연결합니다. |
| `--single-threaded-scene` | R | Force scene tree to run in single-threaded mode. | 씬 트리를 단일 스레드 모드로 강제 실행합니다. |
| `--debug-collisions` | D | Show collision shapes when running the scene. | 실행 중 충돌체(CollisionShape2D 등)를 화면에 표시합니다. |
| `--debug-paths` | D | Show path lines when running the scene. | 경로 선을 표시합니다. |
| `--debug-navigation` | D | Show navigation polygons when running the scene. | 내비게이션 폴리곤을 표시합니다. |
| `--debug-avoidance` | D | Show navigation avoidance debug visuals. | 내비게이션 회피 디버그 시각화를 표시합니다. |
| `--debug-stringnames` | D | Print all StringName allocations to stdout when the engine quits. | 종료 시 모든 StringName 할당 내역을 출력합니다. |
| `--debug-canvas-item-redraw` | D | Display a rectangle each time a canvas item requests a redraw. | CanvasItem 재그리기 영역을 표시합니다. |
| `--max-fps <fps>` | R | Set a maximum number of frames per second rendered. | 최대 FPS를 제한합니다. |
| `--frame-delay <ms>` | R | Simulate high CPU load (delay each frame by `<ms>` milliseconds). | 프레임당 인위적 지연(ms)을 주어 고부하를 시뮬레이션합니다. |
| `--time-scale <scale>` | R | Force time scale (higher values are faster, 1.0 is normal speed). | 엔진 시간 배속(`Engine.time_scale`)을 강제 설정합니다. |
| `--disable-vsync` | R | Forces disabling of vertical synchronization. | 수직동기화(V-Sync)를 강제 비활성화합니다. |
| `--disable-render-loop` | R | Disable render loop so rendering only occurs when called explicitly. | 렌더 루프를 비활성화합니다. |
| `--disable-crash-handler` | R | Disable crash handler when supported by the platform code. | 크래시 핸들러를 비활성화합니다. |
| `--fixed-fps <fps>` | R | Force a fixed number of frames per second. | 고정 FPS로 시뮬레이션을 진행합니다 (결정론적 테스트에 유용). |
| `--delta-smoothing <enable>` | R | Enable or disable frame delta smoothing ["enable", "disable"]. | 델타 스무딩을 설정합니다. |
| `--print-fps` | R | Print the frames per second to the stdout. | 초당 프레임 수를 표준 출력에 표시합니다. |
| `--editor-pseudolocalization` | E | Enable pseudolocalization for the editor and the project manager. | 에디터 의사 지역화(Pseudolocalization)를 활성화합니다. |

### 3.5 독립 실행 도구 (Standalone tools)

| 플래그 | 구분 | 영문 설명 | 한국어 설명 |
|---|---|---|---|
| `-s`, `--script <script>` | X | Run a script (`SceneTree` or `MainLoop` inheritance). | **핵심:** 지정한 GDScript(`SceneTree` 또는 `MainLoop` 상속)를 단독 실행합니다. |
| `--main-loop <name>` | X | Run a MainLoop specified by its global class name. | 전역 클래스 이름으로 등록된 커스텀 `MainLoop`를 실행합니다. |
| `--check-only` | X | Only parse for errors and quit (use with `--script`). | **핵심:** `--script`와 함께 사용하여 스크립트 구문/파싱 에러만 검사하고 종료합니다. |
| `--import` | E | Starts the editor, waits for any resources to be imported, and then quits. | **핵심:** 프로젝트의 모든 신규 리소스/텍스처/씬을 임포트(`.godot/` 갱신)한 뒤 즉시 종료합니다. |
| `--export-release <p> <path>` | E | Export the project in release mode using the given preset and output path. | 지정한 프리셋으로 릴리즈 빌드를 추출합니다. |
| `--export-debug <p> <path>` | E | Export the project in debug mode. | 지정한 프리셋으로 디버그 빌드를 추출합니다. |
| `--export-pack <p> <path>` | E | Export the project data only (`.pck` or `.zip`). | 실행 파일 없이 리소스 팩(`.pck`/`.zip`)만 추출합니다. |
| `--export-patch <p> <path>` | E | Export pack with changed files only. | 변경된 리소스만 패치 팩으로 추출합니다. |
| `--patches <paths>` | E | List of patches to use with `--export-patch`. | 패치 추출 시 기준이 되는 팩 목록을 쉼표로 지정합니다. |
| `--install-android-build-template` | E | Install the Android build template. | 안드로이드 커스텀 빌드 템플릿을 설치합니다. |
| `--convert-3to4` | E | Converts project from Godot 3.x to Godot 4.x. | Godot 3.x 프로젝트를 Godot 4.x 포맷으로 변환합니다. |
| `--validate-conversion-3to4` | E | Shows what elements will be renamed when converting 3.x to 4.x. | 3→4 변환 시 변경될 항목을 사전 검증합니다. |
| `--doctool [path]` | E | Dump the engine API reference to the given `<path>` in XML format. | 엔진 API 레퍼런스를 XML 포맷으로 덤프합니다. |
| `--no-docbase` | E | Disallow dumping the base types (used with `--doctool`). | `--doctool` 사용 시 기본 타입 덤프를 제외합니다. |
| `--gdextension-docs` | E | Generate API reference from all the GDExtensions loaded. | 로드된 GDExtension의 API 문서를 생성합니다. |
| `--gdscript-docs <path>` | E | Generate API reference from inline documentation in GDScript files. | 지정 경로의 GDScript 주석으로부터 문서를 생성합니다. |
| `--build-solutions` | E | Build the scripting solutions (e.g. for C# projects). | C# 솔루션을 빌드합니다. |
| `--dump-gdextension-interface` | E | Generate `gdextension_interface.h` in the current folder. | GDExtension C 헤더 파일을 현재 폴더에 생성합니다. |
| `--dump-gdextension-interface-json` | E | Generate `gdextension_interface.json` in the current folder. | GDExtension 인터페이스 JSON 파일을 생성합니다. |
| `--dump-extension-api` | E | Generate `extension_api.json` in the current folder. | Godot API 바인딩용 JSON 덤프를 생성합니다. |
| `--dump-extension-api-with-docs` | E | Generate `extension_api.json` including documentation. | 문서가 포함된 `extension_api.json`을 생성합니다. |
| `--validate-extension-api <path>` | E | Validate an extension API file dumped from a previous version. | 이전 버전 API 덤프와의 호환성을 검증합니다. |
| `--benchmark` | E | Benchmark the run time and print it to console. | 실행 시간 벤치마크를 콘솔에 출력합니다. |
| `--benchmark-file <path>` | E | Benchmark the run time and save it to a given file in JSON format. | 벤치마크 결과를 JSON 파일로 저장합니다. |

---

## 4. 실전 Headless 워크플로우 예제 (Headless Workflow Examples)

### 4.1 에셋 임포트 및 UID/캐시 갱신
신규 이미지(`.png`), 씬(`.tscn`), 리소스(`.tres`) 추가 후 Headless 환경에서 임포트를 수행합니다:
```powershell
Godot.exe --headless --import
```

### 4.2 GDScript 문법 및 정적 오류 검사 (`--check-only`)
스크립트를 실제로 실행하지 않고 파싱 및 타입 오류만 빠르게 검증합니다:
```powershell
Godot.exe --headless --script res://scripts/overworld/Player.gd --check-only
```

### 4.3 자동화 QA 테스트 스크립트 실행 (`SceneTree` 상속)
`extends SceneTree`로 작성된 Headless QA 스크립트를 실행하여 게임 로직과 물리/씬 전환을 검증합니다:
```powershell
Godot.exe --headless --script res://tests/test_phase1.gd
```

### 4.4 메인 씬 또는 특정 씬 스모크 테스트 (N프레임 실행 후 자동 종료)
오토로드 및 메인 씬 초기화 시 런타임 에러가 없는지 60프레임 동안 실행 후 종료합니다:
```powershell
Godot.exe --headless --quit-after 60
Godot.exe --headless --scene res://scenes/overworld/Overworld.tscn --quit-after 60
```

### 4.5 릴리즈 빌드 추출 (Export)
`export_presets.cfg`가 설정된 상태에서 CLI로 빌드를 추출합니다:
```powershell
Godot.exe --headless --export-release "Windows Desktop" builds/pokemon-ace.exe
```
