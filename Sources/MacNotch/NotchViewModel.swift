import SwiftUI
import AppKit

// MARK: - Types

enum NotchState: Equatable { case hidden, expanded }

enum NotchTab: CaseIterable, Identifiable {
    case calendar, music, files, system
    var id: Self { self }
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .music:    return "music.note"
        case .files:    return "folder"
        case .system:   return "display"
        }
    }
    var label: String {
        switch self {
        case .calendar: return "달력"
        case .music:    return "음악"
        case .files:    return "파일"
        case .system:   return "시스템"
        }
    }
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let color: Color
    let isAllDay: Bool

    var timeString: String {
        if isAllDay { return "하루 종일" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: startDate)
    }

    var relativeString: String {
        if startDate < Date() && endDate > Date() { return "진행 중" }
        let diff = startDate.timeIntervalSinceNow
        if diff < 0 { return "종료됨" }
        let m = Int(diff / 60)
        if m < 60   { return "\(m)분 후" }
        if m < 1440 { return "\(m / 60)시간 후" }
        return "\(m / 1440)일 후"
    }
}

struct DroppedFile: Identifiable {
    let id = UUID()
    let url: URL
    var icon: NSImage?
    var name: String { url.lastPathComponent }
    var sizeString: String {
        guard let sz = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "" }
        let b = Double(sz)
        if b < 1024        { return "\(sz) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024) }
        return String(format: "%.1f MB", b / (1024 * 1024))
    }
}

// MARK: - ViewModel

@MainActor
class NotchViewModel: ObservableObject {

    @Published var state: NotchState   = .hidden
    @Published var activeTab: NotchTab = .calendar
    @Published var isDragTargeted      = false
    @Published var showLiveActivity    = false

    @Published var timeString   = "--:--"
    @Published var secondString = "--"
    @Published var dateString   = ""

    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var eventDayKeys: Set<String>        = []
    @Published var currentMonth: Date               = Date()
    @Published var calendarAuthorized               = false

    @Published var nowPlaying: NowPlayingInfo?
    @Published var droppedFiles: [DroppedFile]      = []

    @Published var volume: Float    = 0.5
    @Published var cpuUsage: Double = 0
    @Published var memoryGB: Double = 0

    // 레이아웃
    private(set) var panelW: CGFloat            = 560
    private(set) var panelH: CGFloat            = 340
    private(set) var notchWidth: CGFloat        = 182
    private(set) var notchHeight: CGFloat       = 37
    private(set) var notchCenterOffset: CGFloat = 0

    let expandedWidth:  CGFloat = 440
    let expandedHeight: CGFloat = 300

    private(set) var isHovering = false

    private var clockTimer:    Timer?
    private var dataTimer:     Timer?
    private var collapseTimer: Timer?
    private var hoverTimer:    Timer?
    var calendarService: CalendarService?

    // MARK: - 크기

    var islandWidth:  CGFloat { state == .hidden ? notchWidth  : expandedWidth  }
    var islandHeight: CGFloat { state == .hidden ? notchHeight : expandedHeight }
    var islandBottomRadius: CGFloat { state == .hidden ? 10 : 24 }
    var liveActivityWidth:  CGFloat { notchWidth + 160 }

    // MARK: - Hit Rects (flipped: y=0 상단)

    var islandHitRect: NSRect {
        let x = (panelW - islandWidth) / 2 + notchCenterOffset
        return NSRect(x: x, y: 0, width: islandWidth, height: islandHeight)
    }
    var notchHitRect: NSRect {
        let w = notchWidth + 8
        let x = (panelW - w) / 2 + notchCenterOffset
        return NSRect(x: x, y: 0, width: w, height: notchHeight)
    }
    var liveActivityHitRect: NSRect {
        let x = (panelW - liveActivityWidth) / 2 + notchCenterOffset
        return NSRect(x: x, y: 0, width: liveActivityWidth, height: notchHeight)
    }
    var currentHitRect: NSRect {
        switch state {
        case .hidden:   return showLiveActivity ? liveActivityHitRect : notchHitRect
        case .expanded: return islandHitRect
        }
    }

    // MARK: - Configure

    func configure(screen: NSScreen, panelW: CGFloat, panelH: CGFloat,
                   notchWidth: CGFloat, notchHeight: CGFloat, notchCenterOffset: CGFloat) {
        self.panelW            = panelW
        self.panelH            = panelH
        self.notchWidth        = notchWidth
        self.notchHeight       = notchHeight
        self.notchCenterOffset = notchCenterOffset
    }

    // MARK: - 라이프사이클

    func start() {
        updateTime()

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateTime() }
        }
        RunLoop.main.add(clockTimer!, forMode: .common)

        dataTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cpuUsage = SystemMetrics.cpuUsage()
                self?.memoryGB = SystemMetrics.systemMemoryGB()
                self?.fetchMusic()
            }
        }
        RunLoop.main.add(dataTimer!, forMode: .common)

        cpuUsage = SystemMetrics.cpuUsage()
        memoryGB = SystemMetrics.systemMemoryGB()
        volume   = SystemMetrics.getVolume()

        // DistributedNotification 실시간 구독
        MusicNotificationObserver.shared.onInfo = { [weak self] info in
            guard let self else { return }
            DispatchQueue.main.async {
                self.nowPlaying = info
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.showLiveActivity = info?.isPlaying == true
                }
                if info != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        NowPlayingService.fetch { fetched in
                            guard let self, let fetched else { return }
                            if let art = fetched.artwork { self.nowPlaying?.artwork = art }
                            if fetched.title == self.nowPlaying?.title {
                                self.nowPlaying?.isPlaying = fetched.isPlaying
                            }
                        }
                    }
                }
            }
        }

        fetchMusic()

        let svc = CalendarService()
        svc.onUpdate = { [weak self] events, authorized in
            DispatchQueue.main.async {
                self?.upcomingEvents     = events
                self?.calendarAuthorized = authorized
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                self?.eventDayKeys = Set(events.map { df.string(from: $0.startDate) })
            }
        }
        calendarService = svc
        svc.requestAndFetch()
    }

    func stop() {
        clockTimer?.invalidate()
        dataTimer?.invalidate()
        collapseTimer?.invalidate()
        hoverTimer?.invalidate()
    }

    // MARK: - 인터랙션

    func handleHover(_ hovered: Bool) {
        isHovering = hovered
        hoverTimer?.invalidate()

        if hovered {
            collapseTimer?.invalidate()
            guard state == .hidden else { return }
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.isHovering, self.state == .hidden else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        self.state = .expanded
                    }
                }
            }
            RunLoop.main.add(hoverTimer!, forMode: .common)
        } else {
            hoverTimer?.invalidate()
            scheduleCollapse(after: 1.0)
        }
    }

    func handleOutsideClick() {
        guard state == .expanded else { return }
        collapseTimer?.invalidate()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { state = .hidden }
    }

    func handleClose() {
        collapseTimer?.invalidate()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { state = .hidden }
    }

    func setTab(_ tab: NotchTab) {
        withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
    }

    // MARK: - 파일

    func handleDragEntered() {
        collapseTimer?.invalidate()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isDragTargeted = true; activeTab = .files; state = .expanded
        }
    }
    func handleDragExited() { isDragTargeted = false; scheduleCollapse(after: 4.0) }

    func handleFileDrop(_ urls: [URL]) {
        isDragTargeted = false
        collapseTimer?.invalidate()
        let newFiles = urls.map { url -> DroppedFile in
            var f = DroppedFile(url: url)
            f.icon = NSWorkspace.shared.icon(forFile: url.path)
            return f
        }
        withAnimation {
            droppedFiles.insert(contentsOf: newFiles, at: 0)
            if droppedFiles.count > 12 { droppedFiles = Array(droppedFiles.prefix(12)) }
            activeTab = .files; state = .expanded
        }
        scheduleCollapse(after: 15.0)
    }

    func removeFile(_ f: DroppedFile) { withAnimation { droppedFiles.removeAll { $0.id == f.id } } }
    func clearFiles()                  { withAnimation { droppedFiles.removeAll() } }
    func openFile(_ f: DroppedFile)    { NSWorkspace.shared.open(f.url) }
    func revealFile(_ f: DroppedFile)  { NSWorkspace.shared.activateFileViewerSelecting([f.url]) }

    // MARK: - 음악

    func playPause() { NowPlayingService.sendCommand(.togglePlayPause); refetch(after: 0.6) }
    func nextTrack()  { NowPlayingService.sendCommand(.nextTrack);        refetch(after: 0.8) }
    func prevTrack()  { NowPlayingService.sendCommand(.previousTrack);    refetch(after: 0.8) }
    private func refetch(after d: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + d) { [weak self] in self?.fetchMusic() }
    }

    func setVolume(_ v: Float) { volume = v; SystemMetrics.setVolume(v) }

    // MARK: - Private

    private func scheduleCollapse(after secs: Double) {
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: secs, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, !self.isHovering else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { self.state = .hidden }
            }
        }
        RunLoop.main.add(collapseTimer!, forMode: .common)
    }

    private func updateTime() {
        let now = Date(); let c = Calendar.current
        timeString   = String(format: "%02d:%02d", c.component(.hour, from: now), c.component(.minute, from: now))
        secondString = String(format: "%02d", c.component(.second, from: now))
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "M월 d일 (E)"
        dateString = df.string(from: now)
    }

    func fetchMusic() {
        NowPlayingService.fetch { [weak self] fetched in
            guard let self, let fetched else { return }
            if self.nowPlaying == nil || self.nowPlaying?.title == fetched.title {
                if self.nowPlaying == nil {
                    self.nowPlaying = fetched
                } else {
                    if let art = fetched.artwork { self.nowPlaying?.artwork = art }
                    self.nowPlaying?.isPlaying = fetched.isPlaying
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.showLiveActivity = fetched.isPlaying
                }
            }
        }
    }
}
