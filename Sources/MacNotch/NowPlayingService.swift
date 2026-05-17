import Foundation
import AppKit

// MARK: - Model

struct NowPlayingInfo: Equatable {
    var title:    String
    var artist:   String
    var album:    String
    var isPlaying: Bool
    var artwork:  NSImage?

    static func == (l: NowPlayingInfo, r: NowPlayingInfo) -> Bool {
        l.title == r.title && l.artist == r.artist && l.isPlaying == r.isPlaying
    }
}

enum MediaCommand: Int {
    case togglePlayPause = 2
    case nextTrack       = 4
    case previousTrack   = 5
}

// MARK: - NowPlayingService

enum NowPlayingService {
    private static let fwPath = "/System/Library/PrivateFrameworks/MediaRemote.framework"

    // MARK: 재생 정보 + 앨범아트 가져오기
    // MediaRemote로 기본 정보, AppleScript로 앨범아트 보완

    static func fetch(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard let bundle = makeBundle(),
              let ptr = CFBundleGetFunctionPointerForName(
                  bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)
        else { completion(nil); return }

        typealias Fn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        unsafeBitCast(ptr, to: Fn.self)(.main) { dict in
            guard !dict.isEmpty else { completion(nil); return }
            let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            guard !title.isEmpty else { completion(nil); return }
            let rate    = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            var art     = artData.flatMap { NSImage(data: $0) }

            var info = NowPlayingInfo(
                title:    title,
                artist:   dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
                album:    dict["kMRMediaRemoteNowPlayingInfoAlbum"]  as? String ?? "",
                isPlaying: rate > 0,
                artwork:  art
            )

            // MediaRemote artwork 없으면 AppleScript로 직접 가져오기
            if art == nil {
                art = fetchArtworkViaAppleScript()
                info.artwork = art
            }

            completion(info)
        }
    }

    // MARK: AppleScript로 앨범아트 가져오기 (메인 스레드 전용)
    // Apple Music이 실행 중일 때만 동작

    static func fetchArtworkViaAppleScript() -> NSImage? {
        // 반드시 메인 스레드에서 실행
        guard Thread.isMainThread else { return nil }

        // Apple Music
        let musicScript = """
        tell application "System Events"
            if (name of processes) contains "Music" then
                tell application "Music"
                    if player state is playing or player state is paused then
                        set artData to data of artwork 1 of current track
                        return artData
                    end if
                end tell
            end if
        end tell
        """
        if let img = runArtworkScript(musicScript) { return img }

        // Spotify (Spotify는 AppleScript artwork 미지원이라 nil 반환)
        return nil
    }

    private static func runArtworkScript(_ src: String) -> NSImage? {
        var err: NSDictionary?
        guard let script = NSAppleScript(source: src) else { return nil }
        let result = script.executeAndReturnError(&err)
        guard err == nil else { return nil }
        let data = result.data
        guard !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    // MARK: 재생 명령

    // MARK: - 재생 명령
    // 실행 중인 음악 앱 감지 후 직접 타겟 → YouTube/브라우저 영향 없음

    static func sendCommand(_ cmd: MediaCommand) {
        let action: String
        switch cmd {
        case .togglePlayPause: action = "playpause"
        case .nextTrack:       action = "next track"
        case .previousTrack:   action = "previous track"
        }

        // 지원하는 음악 앱 목록 (AppleScript 지원 앱)
        let scriptableApps = ["Music", "Spotify", "VOX", "Swinsian"]

        let running = NSWorkspace.shared.runningApplications
            .compactMap { $0.localizedName }

        if let target = scriptableApps.first(where: { running.contains($0) }) {
            // AppleScript로 특정 앱만 타겟
            let src = """
            tell application "System Events"
                if (name of processes) contains "\(target)" then
                    tell application "\(target)" to \(action)
                end if
            end tell
            """
            DispatchQueue.main.async {
                NSAppleScript(source: src)?.executeAndReturnError(nil)
            }
        } else {
            // 지원 앱 없으면 MediaRemote (멜론, Vibe 등 기타)
            sendViaMediaRemote(cmd)
        }
    }

    @discardableResult
    private static func sendViaMediaRemote(_ cmd: MediaCommand) -> Bool {
        guard let bundle = makeBundle(),
              let ptr = CFBundleGetFunctionPointerForName(
                  bundle, "MRMediaRemoteSendCommand" as CFString)
        else { return false }
        typealias Fn = @convention(c) (Int, AnyObject?) -> Bool
        return unsafeBitCast(ptr, to: Fn.self)(cmd.rawValue, nil)
    }

    private static func makeBundle() -> CFBundle? {
        CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: fwPath))
    }
}

// MARK: - MusicNotificationObserver

final class MusicNotificationObserver: @unchecked Sendable {
    static let shared = MusicNotificationObserver()
    var onInfo: ((NowPlayingInfo?) -> Void)?

    private init() {
        let nc = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo"] {
            nc.addObserver(self, selector: #selector(onAppleMusic(_:)),
                           name: NSNotification.Name(name), object: nil,
                           suspensionBehavior: .deliverImmediately)
        }
    }

    @objc private func onAppleMusic(_ note: Notification) {
        guard let d = note.userInfo else { return }
        let state = d["Player State"] as? String ?? ""
        let title = d["Name"]   as? String ?? ""
        if state == "Stopped" || title.isEmpty { onInfo?(nil); return }
        var info = NowPlayingInfo(
            title:    title,
            artist:   d["Artist"] as? String ?? "",
            album:    d["Album"]  as? String ?? "",
            isPlaying: state == "Playing",
            artwork:  nil
        )
        // 앨범아트 AppleScript로 가져오기 (메인 스레드에서 직접 실행)
        info.artwork = NowPlayingService.fetchArtworkViaAppleScript()
        onInfo?(info)
    }

}
