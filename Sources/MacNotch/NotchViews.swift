import SwiftUI
import AppKit

// MARK: - Root

struct NotchRootView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                Group {
                    if vm.state == .hidden {
                        HiddenView(vm: vm)
                    } else {
                        ExpandedIslandView(vm: vm)
                    }
                }
                .offset(x: vm.notchCenterOffset)
            }
    }
}

// MARK: - Hidden

struct HiddenView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        ZStack(alignment: .top) {
            if vm.showLiveActivity, let info = vm.nowPlaying {
                LiveActivityBar(vm: vm, info: info)
            } else {
                IslandShape(bottomRadius: 10)
                    .fill(Color.black)
                    .frame(width: vm.notchWidth, height: vm.notchHeight)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.showLiveActivity)
    }
}

// MARK: - Live Activity Bar

struct LiveActivityBar: View {
    @ObservedObject var vm: NotchViewModel
    let info: NowPlayingInfo

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 14,
                bottomTrailingRadius: 14, topTrailingRadius: 0
            )
            .fill(Color.black)
            .frame(width: vm.liveActivityWidth, height: vm.notchHeight)
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

            HStack(spacing: 0) {
                Group {
                    if let img = info.artwork {
                        Image(nsImage: img).resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .overlay(Image(systemName: "music.note")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5)))
                    }
                }
                .frame(width: 24, height: 24)
                .padding(.leading, 12)

                Spacer()

                Color.clear.frame(width: vm.notchWidth)

                Spacer()

                MusicBarsView(color: .green, isPlaying: info.isPlaying)
                    .padding(.trailing, 12)
            }
            .frame(width: vm.liveActivityWidth, height: vm.notchHeight)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                .animation(.spring(response: 0.35, dampingFraction: 0.8)),
            removal: .opacity.animation(.easeOut(duration: 0.25))
        ))
    }
}

// MARK: - Expanded Island

struct ExpandedIslandView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: vm.islandBottomRadius)
                .fill(Color.black)
                .frame(width: vm.islandWidth, height: vm.islandHeight)
                .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)

            VStack(spacing: 0) {
                Color.clear.frame(height: vm.notchHeight + 2)
                TabBarView(vm: vm)
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)
                Group {
                    switch vm.activeTab {
                    case .calendar: CalendarTabView(vm: vm)
                    case .music:    MusicTabView(vm: vm)
                    case .files:    FilesTabView(vm: vm)
                    case .system:   SystemTabView(vm: vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: vm.islandWidth, height: vm.islandHeight)
        }
        .frame(width: vm.islandWidth, height: vm.islandHeight)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                .animation(.spring(response: 0.38, dampingFraction: 0.78).delay(0.08)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                .animation(.spring(response: 0.5, dampingFraction: 0.88))
        ))
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        HStack(spacing: 2) {
            ForEach(NotchTab.allCases) { tab in
                Button(action: { vm.setTab(tab) }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 11, weight: .medium))
                        Text(tab.label).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(vm.activeTab == tab ? .black : .white.opacity(0.42))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(vm.activeTab == tab ? Color.white : Color.clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.18), value: vm.activeTab == tab)
            }
            Spacer()
            Button(action: vm.handleClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .frame(height: 38).padding(.leading, 10)
    }
}

// MARK: - Island Shape

struct IslandShape: Shape {
    var bottomRadius: CGFloat
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        p.move(to:    .init(x: rect.minX,        y: rect.minY))
        p.addLine(to: .init(x: rect.maxX,        y: rect.minY))
        p.addLine(to: .init(x: rect.maxX,        y: rect.maxY - r))
        p.addArc(center: .init(x: rect.maxX - r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: .init(x: rect.minX + r,    y: rect.maxY))
        p.addArc(center: .init(x: rect.minX + r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: .init(x: rect.minX,        y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Music Bars

struct MusicBarsView: View {
    var color: Color    = .green
    var isPlaying: Bool = true
    @State private var h: [CGFloat] = [6, 12, 5, 9]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(color).frame(width: 2.5, height: isPlaying ? h[i] : 4)
            }
        }
        .frame(height: 14)
        .onAppear  { if isPlaying { animate() } }
        .onChange(of: isPlaying) { _, p in if p { animate() } }
    }

    private func animate() {
        let d = [0.0, 0.18, 0.09, 0.27]
        for i in 0..<4 {
            withAnimation(.easeInOut(duration: 0.4 + Double(i) * 0.07)
                .repeatForever(autoreverses: true).delay(d[i])) {
                h[i] = CGFloat.random(in: 5...14)
            }
        }
    }
}
