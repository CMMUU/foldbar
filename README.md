# 折栏 FoldBar

macOS 27 原生菜单栏管理器，当前版本 **0.2.0 本机开发预览**。提供图标浮窗、完整管理窗口，以及单个、部分、全部应用的折叠配置。使用 Swift、SwiftUI、AppKit 和 Objective-C 运行时桥接实现；Bartender 7 是功能参考。

项目源码位于 `/opt/workspace/projects/foldbar`。需求、方案和验收记录统一维护在 [project-docs 的 FoldBar 目录](https://github.com/CMMUU/project-docs/tree/main/foldbar)。

## 使用

1. 打开 FoldBar，在系统设置中授予辅助功能权限，回到窗口点击“重新检测”。
2. 在管理窗口搜索或筛选应用，勾选单个、多个，或“全选当前结果”。设置为“常驻”或“折叠”，点击“应用”生效。
3. 点击菜单栏箭头打开浮窗，默认显示折叠应用，可以切换全部、搜索、打开原菜单，或进入“管理全部”。
4. 修改可以取消、逐步撤销；应用后可以撤销上一次应用。浮窗和管理窗口共用配置与草稿。
5. “临时展开全部”不更改保存的选择。打开应用原菜单时会临时展开，菜单关闭后恢复折叠配置。

macOS 27 的折叠机制有时也会隐藏 FoldBar 自己的原生入口；此时右上角菜单栏下方会出现独立的备用箭头。重新打开 app 也可以找回管理窗口。右键箭头可管理全部、临时展开或退出；退出会释放折叠会话。

## 构建

需要 Apple Silicon Mac、macOS 27 和 Xcode。脚本默认产生临时签名的 arm64 构建：

```sh
bash scripts/build.sh
open build/FoldBar.app
```

可使用本机已有的 Developer ID 身份签名：

```sh
FOLDBAR_SIGN_IDENTITY='Developer ID Application: …' bash scripts/build.sh build/release
```

0.2.0 交付包已使用 Developer ID 签名并通过严格校验，尚未 Apple 公证或公开发布。切换签名身份后，macOS 可能要求重新授予辅助功能权限。

## 行为与边界

- 配置粒度为应用；同一应用的多个菜单栏图标一起折叠。打开菜单时可以选择已识别的具体图标。
- 全选只作用于当前搜索和筛选结果中的可编辑应用。系统项列出但不参与折叠配置。
- 重启会尝试恢复保存的配置；应用启停、唤醒和 Space 变化后刷新并重新应用。接口失败时释放折叠并保留草稿。
- 使用 macOS 27 私有菜单栏接口，不支持其他系统主版本。系统媒体等附加项可能在折叠期间消失，展开后恢复。
- 浮窗显示应用图标，不是菜单栏动态图标的像素镜像。打开原菜单需要辅助功能权限。
- 已实现主屏定位；多屏、全屏、长期运行及后续系统版本兼容性仍需专项验收。
- 不需要录屏权限，没有网络功能，不直接写系统菜单栏偏好文件。“固定入口”通过系统支持的 ⌘ 拖动移动自己的图标。
- 尚无自定义图标排序、登录启动、全局热键、条件规则、自动更新；不是 Bartender 7 的全功能等价替代。

## 验证

```sh
swift test
codesign --verify --strict build/FoldBar.app
```

10 项核心测试通过，覆盖可见性策略、批量修改范围、只读排除、取消、撤销和应用历史。预览构建在本机验证了：搜索与选择、暂存/取消/应用/撤销、独立备用入口、浮窗、原菜单打开、菜单关闭后再次折叠，并确认真实用户配置未被隔离 UI 测试改写。

最终签名构建的运行权限与验收状态见 [0.2.0 验收记录](https://github.com/CMMUU/project-docs/blob/main/foldbar/完整交互方案与验收-2026-10-11.md)。

开发测试入口：`--ui-test` 使用独立偏好域；`--smoke-test` 返回真实成功/失败退出码，只针对独立 `com.cmmuu.FoldBar.Fixture` 测试应用。必须先启动带 `--fixture` 参数或 `FoldBarTestFixture=true` 元数据的独立测试 app；测试进程自身也需要辅助功能权限。

## 技术参考

- [Apple NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)
- [Bartender 7](https://www.macbartender.com/)
- [Thaw 架构](https://github.com/thaw-app/Thaw/blob/development/docs/ARCHITECTURE.md)
- [Pelmet 对 macOS 27 机制的说明](https://github.com/fif7y/pelmet#how-it-works)

本项目独立编写，没有引入这些开源应用作为依赖或复制其应用实现。
