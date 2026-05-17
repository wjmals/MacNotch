import SwiftUI
import AppKit

struct MusicTabView: View {
    @ObservedObject var vm: NotchViewModel

    var body: some View {
        if let info = vm.nowPlaying {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    AlbumArtView(image: info.artwork)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(info.title).font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white).lineLimit(2)
                        if !info.artist.isEmpty {
                            Text(info.artist).font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.55)).lineLimit(1)
                        }
                        if !info.album.isEmpty {
                            Text(info.album).font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        HStack(spacing: 6) {
                            MusicBarsView(color: .green, isPlaying: info.isPlaying)
                            Text(info.isPlaying ? "재생 중" : "일시정지")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(info.isPlaying ? .green.opacity(0.9) : .white.opacity(0.35))
                        }
                    }
                    Spacer()
                }
                HStack(spacing: 28) {
                    CtrlBtn(icon: "backward.fill", size: 18, bg: false) { vm.prevTrack() }
                    CtrlBtn(icon: info.isPlaying ? "pause.fill" : "play.fill", size: 24, bg: true) { vm.playPause() }
                    CtrlBtn(icon: "forward.fill",  size: 18, bg: false) { vm.nextTrack() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 16)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "music.note.list").font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.18))
                Text("재생 중인 음악 없음").font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Text("Music, Spotify 등을 재생하면\n여기에 표시됩니다.")
                    .font(.system(size: 10)).foregroundColor(.white.opacity(0.25)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct AlbumArtView: View {
    let image: NSImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07))
            if let img = image {
                Image(nsImage: img).resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "music.note").font(.system(size: 24)).foregroundColor(.white.opacity(0.2))
            }
        }
        .frame(width: 72, height: 72)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

struct CtrlBtn: View {
    let icon: String; let size: CGFloat; let bg: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size, weight: bg ? .semibold : .regular))
                .foregroundColor(bg ? .black : .white.opacity(0.85))
                .frame(width: bg ? 44 : 32, height: bg ? 44 : 32)
                .background(Circle().fill(bg ? Color.white : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}
