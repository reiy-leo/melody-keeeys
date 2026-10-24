import Cocoa
import SwiftUI

/// State the tray panel shows; MelodyHost updates it while the panel is open.
final class HudModel: ObservableObject {
  @Published var engineEnabled = true
  @Published var activePackId = ""
  @Published var latencyMs: Double?
  /// False until Accessibility is granted: keystrokes are not heard.
  @Published var hookRunning = true
}

/// Native tray panel (replaces the Flutter HUD window on macOS: no second
/// engine, opens instantly, and is released as soon as it closes).
final class HudViewController: NSHostingController<HudView> {
  init(model: HudModel, packs: [PackInfo], host: MelodyHost) {
    super.init(rootView: HudView(
      model: model,
      packs: packs,
      onToggleEngine: { [weak host] in host?.toggleEngine() },
      onSelect: { [weak host] id in host?.selectPack(id) },
      onPreview: { [weak host] id in host?.preview(packId: id) },
      onOpenSettings: { [weak host] in host?.requestSettings() },
      onGrantAccess: { [weak host] in host?.openAccessibilitySettings() }))
    preferredContentSize = NSSize(width: 340, height: 560)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// Brand violet from app_colors.dart (light 0xFF6D4AD6 / dark 0xFFA78BFA).
private let brand = Color(NSColor(name: nil) { appearance in
  appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    ? NSColor(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255, alpha: 1)
    : NSColor(red: 0x6D / 255, green: 0x4A / 255, blue: 0xD6 / 255, alpha: 1)
})

struct HudView: View {
  @ObservedObject var model: HudModel
  let packs: [PackInfo]
  let onToggleEngine: () -> Void
  let onSelect: (String) -> Void
  let onPreview: (String) -> Void
  let onOpenSettings: () -> Void
  let onGrantAccess: () -> Void

  private var active: PackInfo? { packs.first { $0.id == model.activePackId } ?? packs.first }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "pianokeys").foregroundColor(brand)
        Text("Melody Keeeys").font(.headline)
        Spacer()
        Text("托盘面板").font(.caption).foregroundColor(.secondary)
      }

      if !model.hookRunning {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text("未开启辅助功能权限").font(.subheadline).fontWeight(.semibold)
          }
          Text("不开启时打字不会有任何声音。请在「系统设置 → 隐私与安全性 → 辅助功能」中勾选旋律键音，勾选后几秒内自动生效，无需重启。")
            .font(.caption)
            .foregroundColor(.primary.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
          Button(action: onGrantAccess) {
            Label("去开启权限", systemImage: "lock.open")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.orange)
          .controlSize(.small)
        }
        .padding(10)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.orange.opacity(0.6))
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.10))))
      }

      HStack(spacing: 8) {
        Circle()
          .fill(!model.hookRunning ? Color.orange : model.engineEnabled ? Color.green : Color.gray)
          .frame(width: 8, height: 8)
        Text(statusText).font(.caption).foregroundColor(.secondary)
        Spacer()
        Toggle("", isOn: Binding(get: { model.engineEnabled }, set: { _ in onToggleEngine() }))
          .toggleStyle(SwitchToggleStyle())
          .labelsHidden()
          .controlSize(.small)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))

      if let pack = active {
        HStack(alignment: .center, spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            Text("正在使用").font(.caption).fontWeight(.semibold).foregroundColor(brand)
            HStack(spacing: 6) {
              Text(pack.name).font(.title3).fontWeight(.semibold).lineLimit(1)
              TagChip(text: pack.nameEn)
            }
            Text(pack.description)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }
          Spacer(minLength: 4)
          Button(action: { onPreview(pack.id) }) {
            Label("试听", systemImage: "waveform")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
        .padding(10)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .stroke(brand.opacity(0.35))
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04))))
      }

      ScrollView {
        LazyVStack(spacing: 4) {
          ForEach(Array(packs.enumerated()), id: \.element.id) { index, pack in
            PackRow(
              index: index + 1,
              pack: pack,
              active: pack.id == model.activePackId,
              onSelect: { onSelect(pack.id) },
              onPreview: { onPreview(pack.id) })
          }
        }
      }

      Button(action: onOpenSettings) {
        Label("打开设置…", systemImage: "gearshape")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
    .padding(14)
    .frame(width: 340, height: 560)
  }

  private var statusText: String {
    guard model.hookRunning else { return "无辅助功能权限，按键无声" }
    guard model.engineEnabled else { return "音频引擎已静音" }
    let latency = model.latencyMs.map { String(format: "%.1f", $0) } ?? "--"
    return "音频引擎运行中  \(latency)ms"
  }
}

private struct TagChip: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2)
      .lineLimit(1)
      .truncationMode(.tail)
      .foregroundColor(brand)
      .padding(.horizontal, 6)
      .padding(.vertical, 1)
      .background(Capsule().fill(brand.opacity(0.14)))
      // Chinese name keeps its width; the English tag shrinks first.
      .layoutPriority(-1)
  }
}

private struct PackRow: View {
  let index: Int
  let pack: PackInfo
  let active: Bool
  let onSelect: () -> Void
  let onPreview: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Text(String(format: "%02d", index))
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(active ? brand : .secondary)
      Text(pack.name).font(.callout).fontWeight(.medium).lineLimit(1)
      TagChip(text: pack.nameEn)
      Spacer(minLength: 4)
      if active {
        Image(systemName: "checkmark.circle.fill").foregroundColor(brand)
      } else {
        Button(action: onPreview) { Image(systemName: "play.fill") }
          .buttonStyle(.borderless)
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(active ? brand.opacity(0.10) : Color.primary.opacity(0.04)))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(active ? brand.opacity(0.5) : Color.clear))
    .contentShape(Rectangle())
    .onTapGesture(perform: onSelect)
  }
}
