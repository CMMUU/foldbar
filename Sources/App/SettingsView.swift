import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""

    var matches: [MenuApp] {
        model.apps.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "menubar.rectangle").font(.system(size: 30, weight: .medium)).foregroundStyle(.indigo)
                    .frame(width: 60, height: 60).background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text("折栏 FoldBar").font(.system(size: 23, weight: .semibold))
                    Text("常用的留下，其余随时展开。").foregroundStyle(.secondary)
                }
                Spacer()
                Text("开发预览 0.1").font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(.quaternary, in: Capsule())
            }.padding(24)

            HStack(spacing: 12) {
                Circle().fill(model.isCollapsed ? Color.indigo : Color.green).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.isBusy ? "正在收起…" : model.isCollapsed ? "已收起所选应用" : "菜单栏已展开").fontWeight(.medium)
                    Text("点击菜单栏箭头切换 · 右键打开设置").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.isCollapsed || model.isBusy ? "全部展开" : "收起所选") { model.toggle() }
                    .buttonStyle(.borderedProminent).tint(.indigo)
                    .disabled(!model.supported || !model.hasPermission || (!model.isCollapsed && model.selected.isEmpty))
            }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 24)

            if !model.supported {
                notice("此预览版适用于 macOS 27。当前系统接口不可用，所有图标保持展开。", symbol: "exclamationmark.triangle")
            } else if !model.hasPermission {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised").foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("允许读取菜单栏").fontWeight(.medium)
                        Text("在辅助功能中启用 FoldBar，再回来点击刷新。").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("打开权限设置") { model.requestPermission() }
                }.padding(16).background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24).padding(.top, 14)
            }

            if let error = model.errorMessage { notice(error, symbol: "exclamationmark.circle") }

            HStack {
                Text("选择收起的应用").font(.headline)
                Text("\(model.apps.filter { model.selected.contains($0.id) }.count) / \(model.apps.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                if model.isScanning { ProgressView().controlSize(.small) }
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("刷新菜单栏应用").disabled(model.isScanning || model.isCollapsed || model.isBusy)
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 12)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索应用", text: $query).textFieldStyle(.plain)
            }.padding(10).background(.background, in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 24)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if matches.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: query.isEmpty ? "menubar.arrow.up.rectangle" : "magnifyingglass").font(.system(size: 25))
                            Text(model.isScanning ? "正在查找菜单栏应用…" : query.isEmpty ? "尚未发现可管理的应用" : "没有匹配的应用")
                            Text(model.hasPermission ? "应用运行并显示菜单栏图标后，点击刷新。" : "授予辅助功能权限后，即可显示真实应用。")
                                .font(.caption)
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 42)
                    }
                    ForEach(matches) { app in
                        HStack(spacing: 12) {
                            Image(nsImage: app.path.map { NSWorkspace.shared.icon(forFile: $0) } ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
                                .resizable().frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name).fontWeight(.medium)
                                Text(model.selected.contains(app.id) ? "随展开按钮显示" : "始终显示")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("收起", isOn: Binding(get: { model.selected.contains(app.id) }, set: { model.setSelected(app.id, value: $0) }))
                                .toggleStyle(.switch).controlSize(.small).tint(.indigo)
                        }.padding(.horizontal, 14).padding(.vertical, 11)
                        if app.id != matches.last?.id { Divider().padding(.leading, 58) }
                    }
                }.background(.background, in: RoundedRectangle(cornerRadius: 12))
            }.padding(.horizontal, 24).padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("按应用收起；同一应用的多个图标一起变化。退出 FoldBar 会释放收起状态。")
                Text("预览版：收起时，部分系统附加项（如正在播放）可能暂时消失，展开后恢复。")
            }.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24).padding(.vertical, 18)
        }
        .frame(width: 620, height: 690)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
    }

    func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.callout).foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 24).padding(.top, 14)
    }
}
