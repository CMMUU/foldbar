<p align="center"><img src="Resources/FoldBar.png" width="112" alt="FoldBar 折页 F"></p>

# 折栏 FoldBar

[English](README.en.md) · [官网](https://foldbar.cmmuu.com) · [下载安装包](https://downloads.cmmuu.com/download/foldbar/latest/macos-arm64) · [GitHub 发行](https://github.com/CMMUU/foldbar/releases/latest)

让菜单栏回归清爽。FoldBar 是为 **macOS 27 / Apple Silicon** 编写的原生菜单栏管理器：收起不常用的应用图标，需要时打开浮窗，也可以进入完整管理窗口。

当前版本 **0.3.0**，属于早期预览。正式下载附件使用 Developer ID 签名并经 Apple 公证。

## 使用

1. 打开 DMG，把 FoldBar 拖入“应用程序”，然后启动。
2. 在系统设置中为 FoldBar 开启“辅助功能”，回到应用点击“重新检测”。
3. 选中一个、多个或当前结果中的全部应用，设为“常驻”或“折叠”，点击“应用”。系统项只读。
4. 点击菜单栏 **F** 打开浮窗，可切换“折叠 / 全部”、搜索、打开原菜单，或进入“管理全部”。
5. 在窗口右上角选择“跟随系统 / 简体中文 / English”，即时切换界面。

修改支持取消和撤销；应用后也可撤销上一次配置。“临时展开全部”不修改保存的选择。打开原菜单时暂时展开，菜单关闭后恢复。设置保存在本机，不收集遥测，无需录屏权限。

系统有时会连同 FoldBar 的菜单栏入口一起隐藏；此时右上角下方会出现独立的备用 **F** 按钮。重新打开应用也能找回管理窗口。右键 F 可管理全部、临时展开或退出，退出会释放折叠会话。

## 当前边界

- 管理粒度为应用，同一应用的多个菜单栏图标一起折叠；打开菜单时可选择识别出的具体图标。
- 使用 macOS 27 私有菜单栏接口，其他系统主版本不支持，未来系统更新可能影响兼容性。
- 系统项不参与配置；媒体等系统附加项可能受折叠影响，展开后恢复。
- 浮窗使用应用图标，不是菜单栏动态图标的实时镜像。
- 主屏流程已做预览验证；多屏、全屏和长期运行仍需进一步测试。
- 暂不提供自定义排序、登录启动、全局快捷键、条件规则、自动更新。

## 构建与测试

应用需要 Apple Silicon、macOS 27 和对应 Xcode SDK，使用 Swift、SwiftUI、AppKit 与小型 Objective-C 运行时桥接。无第三方应用依赖。

```sh
swift test
bash scripts/build.sh
open build/FoldBar.app
```

脚本默认使用临时签名。可通过 `FOLDBAR_SIGN_IDENTITY` 指定自己的 Developer ID 身份；签名密钥和公证凭据不在仓库中。改变签名身份或安装位置可能需要重新授予辅助功能权限。

核心测试覆盖批量范围、系统项只读、取消/撤销、应用历史和语言选择。`--ui-test` 使用独立偏好域；`--fixture` 创建测试菜单图标；`--smoke-test` 仅针对独立 `com.cmmuu.FoldBar.Fixture`，测试进程也需辅助功能权限。

## 反馈与参考

通过 [Issues](https://github.com/CMMUU/foldbar/issues) 报告问题，请附系统版本、芯片类型及复现步骤，避免提交私人菜单内容。

功能参考 [Bartender](https://www.macbartender.com/)，技术调研参考 [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)、[Thaw 架构](https://github.com/thaw-app/Thaw/blob/development/docs/ARCHITECTURE.md) 与 [Pelmet](https://github.com/fif7y/pelmet)。本项目独立实现，与这些产品无隶属关系。
