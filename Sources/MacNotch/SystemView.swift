import SwiftUI
import AppKit

struct SystemTabView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: volIcon).font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                        Text("볼륨").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.55))
                        Spacer()
                        Text("\(Int(vm.volume * 100))%").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                    }
                    VolSlider(value: Binding(get: { Double(vm.volume) }, set: { vm.setVolume(Float($0)) }))
                }
                Button(action: openSound) {
                    HStack(spacing: 6) {
                        Image(systemName: "airplayvideo").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                        Text("출력 기기 설정").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.5)))
                }.buttonStyle(.plain)
            }.frame(maxWidth: .infinity)

            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 0.5)

            VStack(alignment: .leading, spacing: 10) {
                Text("시스템").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.35))
                SysBar(label: "CPU", icon: "cpu", value: vm.cpuUsage / 100, text: "\(Int(vm.cpuUsage))%",
                       color: vm.cpuUsage < 40 ? .green : vm.cpuUsage < 70 ? .yellow : .red)
                SysBar(label: "메모리", icon: "memorychip", value: min(vm.memoryGB / 16, 1),
                       text: String(format: "%.1f GB", vm.memoryGB),
                       color: vm.memoryGB / 16 < 0.6 ? .blue : vm.memoryGB / 16 < 0.8 ? .yellow : .orange)
                SysBar(label: "볼륨", icon: "speaker.wave.2", value: Double(vm.volume),
                       text: "\(Int(vm.volume * 100))%", color: .blue)
            }.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var volIcon: String {
        switch vm.volume {
        case ..<0.01: return "speaker.slash"
        case ..<0.33: return "speaker.wave.1"
        case ..<0.66: return "speaker.wave.2"
        default:      return "speaker.wave.3"
        }
    }
    private func openSound() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct VolSlider: View {
    @Binding var value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                Capsule().fill(LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * value, height: 4)
                Circle().fill(Color.white).frame(width: 14, height: 14).shadow(color: .black.opacity(0.4), radius: 2)
                    .offset(x: geo.size.width * value - 7)
            }
            .frame(height: 14).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                value = max(0, min(1, g.location.x / geo.size.width))
            })
        }.frame(height: 14)
    }
}

struct SysBar: View {
    let label: String; let icon: String; let value: Double; let text: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundColor(color.opacity(0.75))
                Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(text).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.6))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                    Capsule().fill(LinearGradient(colors: [color.opacity(0.65), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * value), height: 3)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: value)
                }
            }.frame(height: 3)
        }
    }
}
