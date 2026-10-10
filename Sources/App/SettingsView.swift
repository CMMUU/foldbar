import SwiftUI
import AppKit

private enum ItemFilter: String, CaseIterable {
    case all = "全部", pinned = "常驻", folded = "折叠", system = "系统"
}

struct AppIcon: View {
    let app: MenuApp
    var size: CGFloat = 30
    var body: some View {
        Group {
            if let path = app.path { Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable() }
            else { Image(systemName: "switch.2").resizable().scaledToFit().padding(5).foregroundStyle(.secondary) }
        }.frame(width: size, height: size)
    }
}

struct FeedbackView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if !model.supported {
            Label("当前折叠引擎仅支持 macOS 27", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
        if !model.hasPermission {
            HStack {
                Label("需要辅助功能权限以识别和打开图标", systemImage: "hand.raised")
                Spacer()
                Button("授权辅助功能") { model.requestPermission() }
                Button("重新检测") { model.refresh() }
            }.font(.caption).padding(10).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        if let error = model.errorMessage {
            HStack(alignment: .top) {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Spacer(minLength: 4)
                Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("关闭提示")
            }.font(.caption).fixedSize(horizontal: false, vertical: true)
        } else if let notice = model.notice {
            Text(notice).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct DraftBar: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.state.isDirty ? "待应用 · \(model.state.changed.count) 个应用" : "配置已保存").font(.system(size: 12, weight: .medium))
                if !compact { Text("浮窗与管理窗口共用这些修改").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 2)
            Button(model.state.canUndoDraft ? "撤销修改" : "撤销应用") { Task { await model.undo() } }
                .disabled(!model.canUndo || model.isBusy)
            Button("取消") { model.cancelDraft() }.disabled(!model.state.isDirty || model.isBusy)
            Button("应用") { Task { await model.applyDraft() } }
                .buttonStyle(.borderedProminent).disabled(!model.state.isDirty || model.unavailable)
        }.controlSize(.small)
    }
}

struct NativeMenuButton: View {
    @ObservedObject var model: AppModel
    let app: MenuApp
    var body: some View {
        if app.targets.count > 1 {
            Menu {
                ForEach(Array(app.targets.enumerated()), id: \.element.id) { index, target in
                    Button("图标 \(index + 1) · \(target.name)") { model.open(target) }
                }
            } label: { Image(systemName: "arrow.up.right.square") }
            .menuStyle(.borderlessButton).frame(width: 24).help("选择要打开的原图标")
            .accessibilityLabel("打开 \(app.name) 的图标")
        } else {
            Button { if let target = app.targets.first { model.open(target) } } label: { Image(systemName: "arrow.up.right.square") }
                .buttonStyle(.borderless).help("打开原菜单").accessibilityLabel("打开 \(app.name) 原菜单")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var filter: ItemFilter = .all
    @State private var selected = Set<String>()
    private var results: [MenuApp] {
        model.apps.filter { app in
            let matches = query.isEmpty || app.name.localizedCaseInsensitiveContains(query) || app.id.localizedCaseInsensitiveContains(query)
            switch filter {
            case .all: return matches
            case .system: return matches && app.isSystem
            case .pinned: return matches && app.editable && !model.state.draft.contains(app.id)
            case .folded: return matches && app.editable && model.state.draft.contains(app.id)
            }
        }
    }
    private var eligible: Set<String> { Set(results.filter(\.editable).map(\.id)) }
    private var batch: Set<String> { selected.intersection(eligible) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("管理菜单栏").font(.system(size: 25, weight: .bold))
                    Text("\(model.apps.filter(\.editable).count) 个应用 · \(model.apps.filter(\.isSystem).count) 个系统项").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("固定入口") { Task { await model.fixEntry() } }.disabled(model.unavailable)
                if model.isBusy || model.isScanning { ProgressView().controlSize(.small) }
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("刷新图标").accessibilityLabel("刷新图标")
                Button(model.temporarilyExpanded ? "按配置折叠" : "临时展开全部") {
                    Task { await model.setExpanded(!model.temporarilyExpanded) }
                }.disabled(model.unavailable)
            }
            FeedbackView(model: model)
            HStack {
                Picker("筛选", selection: $filter) { ForEach(ItemFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 310)
                Spacer()
                TextField("搜索应用或标识符", text: $query).textFieldStyle(.roundedBorder).frame(maxWidth: 270).accessibilityLabel("搜索应用")
            }
            HStack(spacing: 12) {
                Button(batch == eligible && !eligible.isEmpty ? "取消全选" : "全选当前结果（\(eligible.count)）") {
                    selected = batch == eligible ? [] : eligible
                }.disabled(eligible.isEmpty)
                Text("已选 \(batch.count) 个应用").foregroundStyle(.secondary)
                Spacer()
                Button("设为常驻") { model.stage(batch, folded: false); selected = [] }.disabled(batch.isEmpty || model.isBusy)
                Button("设为折叠") { model.stage(batch, folded: true); selected = [] }.disabled(batch.isEmpty || model.isBusy)
            }.font(.caption)
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(results) { app in
                        HStack(spacing: 12) {
                            Toggle("选择 \(app.name)", isOn: Binding(get: { batch.contains(app.id) }, set: { value in
                                if value { selected.insert(app.id) } else { selected.remove(app.id) }
                            })).labelsHidden().toggleStyle(.checkbox).disabled(!app.editable || model.isBusy)
                            AppIcon(app: app)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(app.name).fontWeight(.medium).lineLimit(1)
                                    if model.state.changed.contains(app.id) { Text("待应用").font(.system(size: 9, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 2).background(.orange.opacity(0.15), in: Capsule()).foregroundStyle(.orange) }
                                }
                                Text(app.isSystem ? "系统项 · 仅查看和打开" : app.itemCount > 1 ? "\(app.itemCount) 个图标 · 同应用联动" : app.id).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            NativeMenuButton(model: model, app: app).disabled(model.unavailable)
                            if app.isSystem {
                                Label("系统管理", systemImage: "lock").font(.caption).foregroundStyle(.secondary).frame(width: 115)
                            } else {
                                Picker("\(app.name) 显示方式", selection: Binding(get: { model.state.draft.contains(app.id) }, set: { model.stage([app.id], folded: $0) })) {
                                    Text("常驻").tag(false); Text("折叠").tag(true)
                                }.pickerStyle(.segmented).labelsHidden().frame(width: 115).disabled(model.isBusy)
                            }
                        }.padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if results.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "menubar.rectangle").font(.largeTitle)
                            Text(model.isScanning ? "正在扫描菜单栏…" : "没有符合条件的图标")
                            if !model.hasPermission { Text("授权后点击“重新检测”").font(.caption) }
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(45)
                    }
                }
            }
            Divider()
            DraftBar(model: model)
            Text("同应用图标一起折叠。打开原菜单时临时展开，关闭后恢复。入口被系统隐藏时，右上角会出现备用箭头。系统媒体等附加项可能受折叠影响。")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(22).frame(minWidth: 740, minHeight: 580)
        .onChange(of: query) { selected = [] }
        .onChange(of: filter) { selected = [] }
    }
}

struct TrayView: View {
    @ObservedObject var model: AppModel
    @State private var showAll = false
    @State private var selecting = false
    @State private var selected = Set<String>()
    @State private var query = ""
    private var results: [MenuApp] {
        model.apps.filter { (showAll || model.state.applied.contains($0.id)) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    private var eligible: Set<String> { Set(results.filter(\.editable).map(\.id)) }
    private var batch: Set<String> { selected.intersection(eligible) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("折栏").font(.system(size: 17, weight: .semibold))
                Spacer()
                Picker("浮窗范围", selection: $showAll) { Text("已折叠").tag(false); Text("全部").tag(true) }.pickerStyle(.segmented).labelsHidden().frame(width: 155)
                Button(selecting ? "完成选择" : "选择") { selecting.toggle(); selected = [] }.controlSize(.small)
            }
            TextField("搜索图标", text: $query).textFieldStyle(.roundedBorder)
            FeedbackView(model: model)
            if selecting {
                HStack {
                    Button("全选当前结果（\(eligible.count)）") { selected = eligible }.disabled(eligible.isEmpty)
                    Spacer()
                    Text("已选 \(batch.count)").foregroundStyle(.secondary)
                }.font(.caption)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(results) { app in
                        VStack(spacing: 5) {
                            HStack {
                                Spacer()
                                if selecting {
                                    Image(systemName: batch.contains(app.id) ? "checkmark.circle.fill" : app.editable ? "circle" : "lock").foregroundStyle(batch.contains(app.id) ? Color.accentColor : .secondary)
                                } else {
                                    Menu {
                                        ForEach(Array(app.targets.enumerated()), id: \.element.id) { index, target in
                                            Button("打开图标 \(index + 1)") { model.open(target) }
                                        }
                                        if app.editable {
                                            Divider()
                                            Button("设为常驻") { model.stage([app.id], folded: false) }
                                            Button("设为折叠") { model.stage([app.id], folded: true) }
                                        }
                                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 18).accessibilityLabel("管理 \(app.name)")
                                }
                            }.frame(height: 12)
                            Button {
                                if selecting {
                                    if app.editable { if selected.contains(app.id) { selected.remove(app.id) } else { selected.insert(app.id) } }
                                } else if let target = app.targets.first { model.open(target) }
                            } label: {
                                VStack(spacing: 6) {
                                    AppIcon(app: app, size: 31)
                                    Text(app.name).font(.system(size: 10)).lineLimit(1)
                                    Text(app.isSystem ? "系统" : model.state.changed.contains(app.id) ? "待应用" : app.itemCount > 1 ? "\(app.itemCount) 个图标" : model.state.applied.contains(app.id) ? "折叠" : "常驻")
                                        .font(.system(size: 9)).foregroundStyle(model.state.changed.contains(app.id) ? .orange : .secondary)
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).disabled(!selecting && model.unavailable).accessibilityLabel(selecting ? "选择 \(app.name)" : "打开 \(app.name) 原菜单")
                        }.padding(8).background(batch.contains(app.id) ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                if results.isEmpty {
                    Text(showAll ? "没有找到图标" : "还没有已折叠的图标\n点“管理全部”设置折叠范围")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            }.frame(height: min(290, max(125, CGFloat((results.count + 3) / 4) * 109)))
            if selecting {
                HStack {
                    Button("设为常驻") { model.stage(batch, folded: false); selected = [] }
                    Button("设为折叠") { model.stage(batch, folded: true); selected = [] }
                }.disabled(batch.isEmpty || model.isBusy).controlSize(.small)
            }
            if model.state.isDirty || model.canUndo { Divider(); DraftBar(model: model, compact: true) }
            Divider()
            HStack {
                Button("管理全部…") { model.closeTray?(); model.showManager?() }.accessibilityLabel("管理全部")
                Spacer()
                Button(model.temporarilyExpanded ? "恢复折叠" : "临时展开全部") {
                    Task { await model.setExpanded(!model.temporarilyExpanded) }
                }.disabled(model.unavailable)
            }.controlSize(.small)
        }.padding(16).frame(width: 416)
        .onChange(of: query) { selected = [] }
        .onChange(of: showAll) { selected = [] }
    }
}
