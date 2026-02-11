# macOS Shell Architecture (Pasty)

本文件定义 `platform/macos/` 下 macOS 工程的架构、目录约定、以及开发规范。若其它文档与本文件冲突，以本文件为准。

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说："我已阅读fileName。"。其中 fileName 为当前文件名

## 目标与边界

- macOS 层是 **thin shell**：只做 UI、系统集成（剪贴板、窗口、快捷键、权限）、以及适配层。
- 所有可移植的业务逻辑与数据模型必须在 **C++ Core**（`core/`）中实现。
- 依赖方向永远是：`platform/macos` -> `core`（单向）。Core 禁止依赖任何平台头文件/库。

## 构建与 Core 集成（必须可编译）

- Xcode 工程由 XcodeGen 生成：配置文件为 `platform/macos/project.yml`。
- 生成工程：在 `platform/macos/` 目录执行 `xcodegen generate`。
- 工程内包含两个关键 target：
  - `PastyCore`：静态库，直接编译 `core/src`，并公开 `core/include` 头文件
  - `Pasty`：macOS App，依赖 `PastyCore`
- Swift 调用 Core 的方式：
  - `import PastyCore`
  - Core Swift 模块由 `core/include/module.modulemap` 定义
  - 允许使用 Swift-C++ 互操作（由 `project.yml` 中的 Swift 设置开启）

约束：
- 不允许在 macOS 层复制/重写 Core 逻辑；需要能力时扩展 Core API。
- 不允许在 Core 中引入 AppKit/Cocoa/Carbon 等平台依赖。

## 开发模式（强制）：MVVM + Combine

macOS 层必须严格遵循 MVVM，并采用 Combine 做响应式数据流。

## UI 技术栈（AppKit 外壳 + SwiftUI 混合）

- 应用启动与外层结构使用 AppKit：`NSApplication` 生命周期、窗口/菜单、权限、快捷键等都由 AppKit 管理（见 `platform/macos/Sources/App.swift`）。
- 内部“简单 UI”（小面板、列表单元、设置项等）允许使用 SwiftUI 进行混合编程，并嵌入到 AppKit 中：
  - AppKit -> SwiftUI：使用 `NSHostingView` / `NSHostingController` 承载 SwiftUI View。
  - 仍保持 MVVM + Combine：SwiftUI View 只绑定 ViewModel State，事件只发送 Action。
- 不要因为引入 SwiftUI 就把业务逻辑挪到 View：可移植的逻辑仍然必须留在 C++ Core。

## 布局约定（AppKit）：SnapKit

- AppKit View 的布局统一使用 SnapKit。
- SnapKit 只允许用于 `platform/macos/`（UI 层）并保持“thin shell”原则；Core 禁止依赖任何第三方 UI 库。
- 若调整/新增 SnapKit 依赖，必须同时更新 `platform/macos/project.yml` 并确保本地可编译。

## 第三方依赖管理：SPM

- macOS 层新增/管理三方库统一使用 Swift Package Manager（SPM）（通过 XcodeGen 配置接入），避免手工拖入二进制依赖。

核心规则：
- **Action 触发数据更新**：用户交互/系统事件只能转换为 Action 发送给 ViewModel。
- **数据变化触发界面更新**：View 只能绑定 ViewModel 的 State（或其派生值）。
- **禁止 View 直接操作数据**：View / ViewController 不能直接调用 Core API、数据库、文件系统、网络等；这些必须经由 ViewModel（再经由 Service/Adapter）。

推荐的一致形态（可用于 AppKit 或 SwiftUI）：

```swift
import Combine

@MainActor
final class ExampleViewModel: ObservableObject {
    struct State: Equatable {
        var isLoading: Bool = false
        var items: [ItemRow] = []
        var errorMessage: String? = nil
    }

    enum Action {
        case onAppear
        case refreshTapped
        case deleteTapped(id: String)
        case searchChanged(String)
    }

    @Published private(set) var state = State()
    private var cancellables = Set<AnyCancellable>()

    private let history: ClipboardHistoryService

    init(history: ClipboardHistoryService) {
        self.history = history
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear, .refreshTapped:
            refresh()
        case let .deleteTapped(id):
            delete(id: id)
        case let .searchChanged(query):
            search(query: query)
        }
    }

    private func refresh() {
        state.isLoading = true
        history.list(limit: 200)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.state.isLoading = false
                    if case let .failure(error) = completion {
                        self.state.errorMessage = String(describing: error)
                    }
                },
                receiveValue: { [weak self] items in
                    self?.state.items = items
                }
            )
            .store(in: &cancellables)
    }

    private func delete(id: String) {
        history.delete(id: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { })
            .store(in: &cancellables)
    }

    private func search(query: String) {
        // 具体策略由业务需要决定（debounce / distinctUntilChanged 等）。
    }
}
```

Combine 约定：
- UI 状态更新必须在主线程（`@MainActor` 或 `receive(on: DispatchQueue.main)`）。
- 所有订阅必须可取消，生命周期由 ViewModel 管理（`Set<AnyCancellable>`）。
- View 侧只允许订阅/绑定 ViewModel State；禁止在 View 里做副作用（写数据、调用 Core）。

## 目录结构（以此为准）

`platform/macos/` 的推荐结构如下：

```text
platform/macos/
├── project.yml                 # XcodeGen 配置（生成 Xcode 工程）
├── Info.plist                  # 应用配置
├── Pasty.xcodeproj/           # 生成产物：Xcode 工程（不要手工编辑）
├── Sources/                    # macOS 层源码（新代码必须放这里）
│   ├── App.swift               # 应用入口与依赖组装（Composition Root）
│   ├── DesignSystem/           # 共享设计系统
│   ├── Features/               # 按功能组织的模块
│   │   ├── MainPanel/
│   │   │   ├── Model/          # MainPanel Presentation Model + 映射（不得放业务规则）
│   │   │   ├── ViewModel/      # MainPanel ViewModel（Action -> Effect -> State）
│   │   │   └── View/           # MainPanel View / ViewController（只渲染 + 发送 Action）
│   │   ├── Settings/
│   │   │   ├── ViewModel/
│   │   │   └── View/
│   │   └── FutureModules/      # 未来模块占位
│   ├── Services/
│   │   ├── Interface/          # 服务协议（可注入、可替换）
│   │   └── Impl/               # 服务实现
│   └── Utilities/              # 通用工具/扩展/日志/Combine 辅助
└── ARCHITECTURE.md             # 本文件
```

## 窗口管理

- **主面板 (Main Panel)**: 设置为 `.floating` 层级，确保在大多数窗口之上。
- **设置面板 (Settings Panel)**: 同样设置为 `.floating` 层级，以防止被主面板遮挡（因为主面板通常一直存在）。
- **窗口层级原则**: 功能性浮动面板 > 普通窗口。如果多个面板需要共存，需注意层级冲突。

## 分层职责（必须遵守）

### Feature View（`platform/macos/Sources/Features/*/View/`）

允许：
- 读取 ViewModel 输出（State / Published / derived values）并渲染
- 将用户/系统事件转换为 Action 发送给 ViewModel
- 只做 UI 层的临时计算（例如布局、颜色、纯格式化）

禁止：
- 直接调用 Core API（包括 `import PastyCore` 后直接访问）
- 读写数据库/文件系统/网络
- 在 View 内部持有业务状态源（状态源只能在 ViewModel）

### Feature ViewModel（`platform/macos/Sources/Features/*/ViewModel/`）

职责：
- 定义 `State`（UI 所需的最小状态集合）与 `Action`
- 执行业务用例的编排（调用 Service/Adapter；把结果映射为 Presentation Model）
- 通过 Combine 管理异步与取消；错误统一落入 State

约束：
- ViewModel 是唯一可以触发副作用的层（通过依赖注入的 Service/Adapter）。
- 不允许把 Core 数据结构“直接透传”给 View；需要在 Model 层做映射/裁剪。

### Feature Model（`platform/macos/Sources/Features/*/Model/`）

职责：
- Presentation Model（供 View 渲染用的轻量模型）
- 从 Core types / JSON / C API 返回值到 Presentation Model 的映射
- UI 相关的格式化（例如时间展示、行标题截断策略）

禁止：
- 业务规则（去重、保留策略、搜索语义、删除语义等）必须在 Core

### Services（`platform/macos/Sources/Services/`）

职责：
- 通过 Interface/Impl 分离业务服务协议与实现
- 封装平台能力（快捷键、剪贴板监听、窗口交互）与 Core 调用边界

约束：
- ViewModel 依赖协议（Interface），避免直接耦合具体实现
- 不将纯工具函数放入 Services

### Utilities（`platform/macos/Sources/Utilities/`）

职责：
- 通用 helper（路径、时间、日志、Combine 扩展）
- 平台适配的纯工具代码（但不要把业务逻辑塞进来）

## 依赖注入与 Adapter（建议）

为保持 macOS 层“可测试 + 可替换”，建议在 ViewModel 依赖的边界使用协议（protocol），并在 `App.swift` 作为 Composition Root 组装：

- `ClipboardHistoryService`：封装对 Core history API 的调用（C API / C++ API）
- `ClipboardWatchingService`：封装 NSPasteboard 监听（平台能力）
- `HotkeyService`：封装全局快捷键注册（平台能力）

约束：
- ViewModel 只依赖协议，不直接 new 平台实现。
- 服务实现放在 `Services/Impl/`。
- 纯工具和扩展放在 `Utilities/`。

## 线程与并发

- UI 状态必须在主线程更新（推荐 ViewModel 标注 `@MainActor`）。
- Core 调用若可能阻塞（IO/SQLite），需要在 Service/Adapter 内部切换到后台队列，再将结果通过 Combine 回到主线程。

## 测试（建议但优先级高）

- ViewModel 必须可单元测试：通过注入协议的 stub/mock 来验证 Action -> State 的演进。
- 测试不依赖 UI、不依赖真实 NSPasteboard。

## 额外规范

- 生成工程产物（如 `platform/macos/Pasty.xcodeproj/`）视为生成文件：原则上不手工编辑。
- 不引入新第三方依赖，除非得到明确批准。
- 修改 `platform/macos/` 后应运行 `scripts/platform-build-macos.sh` 验证可编译（见 `docs/agents-development-flow.md`）。
- 禁止滥用全局通知（`NotificationCenter`），业务交互使用 Coordinator 模式实现。

## 日志规范

macOS 层集成 `CocoaLumberjack` 进行日志记录，但必须通过 `LoggerService` 封装调用。

- **必须**通过 `LoggerService` 记录日志：
  - `LoggerService.info("Application started")`
  - `LoggerService.error("Failed to load settings: \(error)")`
  - `LoggerService.debug("Debug info")`
- **禁止**直接使用 `DDLog*` 宏或 `import CocoaLumberjack`（除 `LoggerService` 内部外）。
- **禁止**使用 `print` / `NSLog`。
- 日志输出目标：
  - 控制台 (Console.app)
  - 文件 (`~/Library/Application Support/Pasty/Logs`)
- 日志服务 (`LoggerService`) 负责初始化和桥接 Core 日志。
