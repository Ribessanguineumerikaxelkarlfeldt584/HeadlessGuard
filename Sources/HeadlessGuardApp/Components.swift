import AppKit
import SwiftUI
import HeadlessGuardKit

enum AppAssets {
    static let icon: NSImage = {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("AppIcon.icns")
        if let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: "Headless Guard")
            ?? NSImage(size: NSSize(width: 128, height: 128))
    }()
}

struct StatusPill: View {
    let clear: Bool
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(clear ? Color.mint : Color.orange).frame(width: 7, height: 7)
            Text(clear ? Copy.text("已守护", "Protected") : Copy.text("需要处理", "Needs attention"))
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background((clear ? Color.mint : Color.orange).opacity(0.10), in: Capsule())
        .overlay { Capsule().stroke((clear ? Color.mint : Color.orange).opacity(0.22)) }
    }
}

struct ShieldPulseView: View {
    let clear: Bool
    var body: some View {
        ZStack {
            Circle()
                .stroke((clear ? Color.mint : Color.orange).opacity(0.08), lineWidth: 18)
                .padding(4)
            Circle()
                .stroke((clear ? Color.mint : Color.orange).opacity(0.13), lineWidth: 1)
                .padding(22)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [(clear ? Color.mint : Color.orange).opacity(0.24), Color.indigo.opacity(0.12)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 64
                    )
                )
                .padding(31)
            Image(systemName: clear ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 48, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(clear ? Color.mint : Color.orange)
        }
    }
}

struct MetricChip: View {
    let icon: String
    let value: String
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.cyan.opacity(0.9))
            Text(value).fontWeight(.semibold)
            Text(label).foregroundStyle(.tertiary)
        }
        .font(.system(size: 10.5))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.16), in: Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.06)) }
    }
}

struct IncidentCard: View {
    let incident: BrowserIncident
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(Color.orange)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(incident.source)
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(incident.confidence == .confirmed ? Copy.text("已确认", "CONFIRMED") : Copy.text("请复核", "REVIEW"))
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(incident.confidence == .confirmed ? Color.mint : Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((incident.confidence == .confirmed ? Color.mint : Color.orange).opacity(0.10), in: Capsule())
                    }
                    Text("\(incident.family.rawValue) · PID \(incident.rootProcess.pid)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(incident.score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)
                Text("/100")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 7)
            }

            HStack(spacing: 14) {
                Label(GuardFormatting.duration(incident.elapsedSeconds), systemImage: "clock")
                Label(GuardFormatting.bytes(incident.residentBytes), systemImage: "memorychip")
                Label("\(incident.processCount)", systemImage: "point.3.connected.trianglepath.dotted")
                if incident.isOrphaned {
                    Label(Copy.text("已脱离任务", "detached"), systemImage: "link.badge.plus")
                        .foregroundStyle(Color.orange)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(incident.reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.mint)
                            Text(reason.title).fontWeight(.medium)
                            Text(reason.detail).foregroundStyle(.tertiary)
                            Spacer()
                            Text("+\(reason.score)").foregroundStyle(Color.mint)
                        }
                    }
                }
                .font(.system(size: 10))
                .padding(10)
                .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.13)) }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                LinearGradient(colors: [Color.indigo, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .shadow(color: Color.indigo.opacity(configuration.isPressed ? 0.12 : 0.32), radius: 14, y: 7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10)) }
    }
}
