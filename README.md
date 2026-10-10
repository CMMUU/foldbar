# 折栏 FoldBar

macOS 27 菜单栏管理器的本机开发原型，当前版本 0.1.0。可选择第三方应用、一键收起或展开其菜单栏图标。界面与实现为本项目编写，Bartender 7 是功能参考。

项目源码位于 `/opt/workspace/projects/foldbar`。需求、实现范围、验证结果和后续路线统一维护在 [project-docs 的 FoldBar 目录](https://github.com/CMMUU/project-docs/tree/main/foldbar)。

## 本机运行

需要 Apple Silicon Mac、macOS 27 和 Xcode。当前构建脚本产出 arm64，使用本机临时签名，尚未公证或公开发布。

```sh
bash scripts/build.sh
open build/FoldBar.app
```

首次打开，在系统设置的辅助功能中允许 FoldBar，然后回到窗口点击刷新。选择希望收起的应用，再点“收起所选”。菜单栏箭头用于切换，右键可以打开设置、全部展开或退出。

选择会保存在本机；每次启动默认展开。退出时会释放收起会话。新应用启动、应用退出、唤醒或 Space 改变时也会展开，以避免隐藏新出现的入口。

## 当前边界

- 按应用分组，同一进程的多个图标一起变化；没有单图标拖动排序。
- 使用 macOS 27 私有菜单栏接口，接口不可用时禁用收起功能；未适配其他系统版本。
- 保留九类基础系统图标，但系统可能在收起期间撤下“正在播放”等附加项；全部展开后恢复。
- 不需要录屏权限，不修改系统菜单栏偏好文件，没有网络请求。
- 尚无悬浮图标栏、热键、自动收起、登录启动、自动更新或多屏布局配置。
- 不属于 Bartender 7 全功能复刻或正式发行版本。

## 验证

```sh
swift test
codesign --verify --strict build/FoldBar.app
```

3 项策略测试通过。本机集成测试使用独立 `com.cmmuu.FoldBar.Fixture` 测试图标，已验证收起、恢复以及其他应用图标保持可见。测试入口 `--smoke-test` 只操作这个测试 bundle，运行前需要单独启动带 `--fixture` 参数的测试 app。

## 技术参考

- [Apple NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)
- [Bartender 7](https://www.macbartender.com/)
- [Thaw 架构](https://github.com/thaw-app/Thaw/blob/development/docs/ARCHITECTURE.md)
- [Pelmet 对 macOS 27 机制的说明](https://github.com/fif7y/pelmet#how-it-works)

调研中的 Thaw、Pelmet、Tuck 均采用 GPL-3.0；本原型没有引入这些项目作为依赖或复制其应用实现。若后续转为基于它们二次开发，应单独确定许可与发布方式。
