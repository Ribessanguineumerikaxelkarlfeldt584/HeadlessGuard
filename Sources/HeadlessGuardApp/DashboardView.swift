import SwiftUI
import HeadlessGuardKit

struct DashboardView: View {
    @ObservedObject var model: GuardViewModel
    @State private var showingConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.055, blue: 0.12), Color(red: 0.06, green: 0.055, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.indigo.opacity(0.16))
                .frame(width: 520, height: 520)
                .blur(radius: 100)
                .offset(x: 430, y: -260)

            VStack(spacing: 18) {
                header
                hero
                HStack(alignment: .top, spacing: 16) {
                    sessionPanel
                    protectionPanel
                        .frame(width: 304)
                }
                footer
            }
            .padding(24)
        }
        .frame(minWidth: 920, minHeight: 650)
        .confirmationDialog(
            Copy.text("安全清理并恢复 Chrome？", "Safely clean up and restore Chrome?"),
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button(Copy.text("停止 \(model.confirmedIncidents.count) 个确认会话", "Stop \(model.confirmedIncidents.count) confirmed session(s)"), role: .destructive) {
                model.rescueConfirmed()
            }
            Button(Copy.text("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(Copy.text("只会终止带无头模式、自动化协议和隔离 profile 的进程树。普通 Chrome 会话受硬保护。", "Only process trees with headless mode, automation transport, and isolated profiles are eligible. Ordinary Chrome is hard-protected."))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppAssets.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: .cyan.opacity(0.2), radius: 12, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Headless Guard")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(Copy.text("让自动化浏览器有始有终", "Keep automation browsers from outliving their work"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(clear: model.incidents.isEmpty)
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(model.isScanning)
        }
    }

    private var hero: some View {
        HStack(spacing: 24) {
            ShieldPulseView(clear: model.incidents.isEmpty)
                .frame(width: 156, height: 156)

            VStack(alignment: .leading, spacing: 11) {
                Text(model.incidents.isEmpty
                    ? Copy.text("浏览器通道畅通", "Your browser path is clear")
                    : Copy.text("发现 \(model.incidents.count) 个遗留自动化会话", "Found \(model.incidents.count) leftover automation session(s)"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text(model.incidents.isEmpty
                    ? Copy.text("没有自动化进程在后台冒充你的浏览器。Headless Guard 会继续静默观察。", "No automation process is masquerading as your browser. Headless Guard will keep watching quietly.")
                    : Copy.text("它们使用独立 profile，但与正常 Chrome 共享应用身份，可能让打开请求落到无窗口实例。", "They use isolated profiles but share Chrome's app identity, so open requests can land in an invisible instance."))
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520, alignment: .leading)

                HStack(spacing: 9) {
                    MetricChip(icon: "memorychip", value: GuardFormatting.bytes(model.reclaimableBytes), label: Copy.text("可释放", "reclaimable"))
                    MetricChip(icon: "clock", value: GuardFormatting.duration(model.oldestAge), label: Copy.text("最久", "oldest"))
                    MetricChip(icon: "point.3.connected.trianglepath.dotted", value: "\(model.totalProcessCount)", label: Copy.text("进程", "processes"))
                }
            }

            Spacer(minLength: 8)

            if model.confirmedIncidents.isEmpty {
                Button {
                    model.launchChrome()
                } label: {
                    Label(Copy.text("打开 Chrome", "Open Chrome"), systemImage: "safari")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                }
                .buttonStyle(GlassButtonStyle())
            } else {
                Button {
                    showingConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        if model.isCleaning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "bolt.shield.fill")
                        }
                        Text(Copy.text("安全清理并恢复", "Clean & restore"))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.isCleaning)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.30), Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(Copy.text("自动化会话", "Automation sessions"), systemImage: "rectangle.3.group.bubble.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(model.incidents.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }

            if model.incidents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Color.mint)
                    Text(Copy.text("这里很安静", "Quiet by design"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(Copy.text("普通 Chrome、Renderer、扩展和 Codex worker 不会出现在清理列表中。", "Ordinary Chrome, renderers, extensions, and Codex workers never enter the cleanup list."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 410)
                }
                .frame(maxWidth: .infinity, minHeight: 184)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.incidents) { incident in
                            IncidentCard(incident: incident)
                        }
                    }
                }
                .frame(maxHeight: 245)
            }
        }
        .padding(17)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07)) }
    }

    private var protectionPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(Copy.text("守护策略", "Guard policy"), systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))

            Toggle(isOn: $model.autoCleanEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Copy.text("自动收尾确认的孤儿", "Auto-clean confirmed orphans"))
                        .font(.system(size: 12.5, weight: .medium))
                    Text(Copy.text("默认关闭 · 只处理高置信进程树", "Off by default · confirmed trees only"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)

            Divider().overlay(Color.white.opacity(0.06))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Copy.text("超龄阈值", "Stale threshold"))
                        .font(.system(size: 12.5, weight: .medium))
                    Text(Copy.text("从不处理新启动的任务", "Fresh tasks are never auto-cleaned"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Picker("", selection: $model.staleThresholdMinutes) {
                    Text("30m").tag(30)
                    Text("1h").tag(60)
                    Text("2h").tag(120)
                    Text("6h").tag(360)
                }
                .labelsHidden()
                .frame(width: 74)
            }

            Divider().overlay(Color.white.opacity(0.06))

            Toggle(isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Copy.text("登录时启动", "Launch at login"))
                        .font(.system(size: 12.5, weight: .medium))
                    Text(Copy.text("无需管理员权限", "No administrator access required"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .toggleStyle(.switch)

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.mint)
                Text(Copy.text("本地运行 · 无遥测 · 不删 profile", "Local only · no telemetry · profiles stay intact"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
        }
        .padding(17)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07)) }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let notice = model.notice {
                Image(systemName: notice.kind == .success ? "checkmark.circle.fill" : notice.kind == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(notice.kind == .success ? Color.mint : notice.kind == .error ? Color.red : Color.orange)
                Text(notice.title).fontWeight(.semibold)
                Text(notice.detail).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Circle()
                    .fill(model.isScanning ? Color.cyan : Color.mint)
                    .frame(width: 6, height: 6)
                Text(model.isScanning
                    ? Copy.text("正在核对进程树…", "Checking process trees…")
                    : Copy.text("每 5 秒重新验证 · 上次 \(model.lastScan?.formatted(date: .omitted, time: .standard) ?? "—")", "Revalidates every 5 seconds · last \(model.lastScan?.formatted(date: .omitted, time: .standard) ?? "—")"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("v0.1.0")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 10.5))
        .padding(.horizontal, 3)
    }
}

struct GuardMenu: View {
    @ObservedObject var model: GuardViewModel

    var body: some View {
        Button {
            WindowPresenter.shared.show(model: model)
        } label: {
            Label(Copy.text("打开 Headless Guard", "Open Headless Guard"), systemImage: "shield.checkered")
        }

        Divider()
        if model.incidents.isEmpty {
            Label(Copy.text("没有遗留的无头浏览器", "No leftover headless browsers"), systemImage: "checkmark.circle")
        } else {
            ForEach(model.incidents.prefix(4)) { incident in
                Label("\(incident.source) · \(GuardFormatting.bytes(incident.residentBytes))", systemImage: "exclamationmark.triangle")
            }
            if !model.confirmedIncidents.isEmpty {
                Button(Copy.text("安全清理并恢复 Chrome…", "Clean safely and restore Chrome…")) {
                    WindowPresenter.shared.show(model: model)
                }
            }
        }

        Divider()
        Toggle(Copy.text("自动收尾确认的孤儿", "Auto-clean confirmed orphans"), isOn: $model.autoCleanEnabled)
        Button(Copy.text("立即重新扫描", "Scan now")) { Task { await model.refresh() } }
        Divider()
        Button(Copy.text("退出 Headless Guard", "Quit Headless Guard")) { NSApp.terminate(nil) }
    }
}
