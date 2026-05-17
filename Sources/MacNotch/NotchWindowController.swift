import AppKit
import SwiftUI

// MARK: - NonActivatingPanel
// 절대 키 윈도우가 되지 않는 패널 – 잠자기 후에도 포커스 탈취 없음

class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func becomeKey() { }   // 무시
    override func becomeMain() { }  // 무시
}

// MARK: - IslandHostingView

class IslandHostingView<Content: View>: NSHostingView<Content> {
    private(set) weak var viewModel: NotchViewModel?

    // 절대 first responder가 되지 않음 → 다른 앱 포커스 유지
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
    override var canBecomeKeyView: Bool { false }

    func setup(with vm: NotchViewModel) {
        viewModel = vm
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return nil }
        guard vm.currentHitRect.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DispatchQueue.main.async { self.viewModel?.handleDragEntered() }
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async { self.viewModel?.handleDragExited() }
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self]) as? [URL] else { return false }
        DispatchQueue.main.async { self.viewModel?.handleFileDrop(urls) }
        return true
    }
}

// MARK: - NotchWindowController

@MainActor
final class NotchWindowController: NSObject {

    private var panel: NonActivatingPanel?
    let viewModel = NotchViewModel()
    private var pollTimer:    Timer?
    private var clickMonitor: Any?

    func start() {
        guard let screen = targetScreen else { return }
        buildPanel(on: screen)
        viewModel.start()
        startPolling()
        setupClickMonitor()
        setupSleepWakeObserver()
    }

    func stop() {
        viewModel.stop()
        panel?.orderOut(nil)
        pollTimer?.invalidate()
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    // MARK: - 패널

    private func buildPanel(on screen: NSScreen) {
        let (notchX, notchW, notchH) = notchGeometry(screen)
        let panelW: CGFloat = 560
        let panelH: CGFloat = 340
        let panelX = screen.frame.midX - panelW / 2
        let panelFrame = NSRect(x: panelX,
                                y: screen.frame.maxY - panelH,
                                width: panelW, height: panelH)
        let offset = (notchX + notchW / 2) - (panelX + panelW / 2)

        viewModel.configure(
            screen: screen,
            panelW: panelW, panelH: panelH,
            notchWidth: notchW, notchHeight: notchH,
            notchCenterOffset: offset
        )

        let p = NonActivatingPanel(contentRect: panelFrame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level              = NSWindow.Level(rawValue: Int(NSWindow.Level.statusBar.rawValue) + 12)
        p.backgroundColor    = .clear
        p.isOpaque           = false
        p.hasShadow          = false
        p.isMovable          = false
        p.hidesOnDeactivate  = false
        p.canHide            = false
        // 패널이 절대 키/메인 윈도우가 되지 않도록 → 다른 앱 포커스 유지
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let hv = IslandHostingView(rootView: NotchRootView(vm: viewModel))
        hv.frame            = NSRect(origin: .zero, size: panelFrame.size)
        hv.autoresizingMask = [.width, .height]
        hv.setup(with: viewModel)
        p.contentView = hv
        p.orderFrontRegardless()
        panel = p
    }

    // MARK: - 잠자기/깨어나기 감지
    // 깨어날 때 패널이 포커스를 가져가지 않도록 재설정

    private func setupSleepWakeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleWake() {
        // 깨어난 후 패널 포커스 완전 해제
        guard let panel = panel else { return }
        panel.resignKey()
        panel.resignMain()
        // 패널을 맨 앞으로 다시 올리되 포커스는 주지 않음
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            panel.orderFrontRegardless()
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.poll() }
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func poll() {
        guard let panel = panel else { return }

        let mouse  = NSEvent.mouseLocation          // 스크린 좌표
        let localX = mouse.x - panel.frame.minX
        let localY = mouse.y - panel.frame.minY

        // NSHostingView: isFlipped=true → y=0이 상단
        let pt = NSPoint(x: localX, y: panel.frame.height - localY)

        let inside = viewModel.currentHitRect.contains(pt)

        if inside && !viewModel.isHovering {
            viewModel.handleHover(true)
        } else if !inside && viewModel.isHovering {
            viewModel.handleHover(false)
        }
    }

    // MARK: - 외부 클릭

    private func setupClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                // 클릭 시 즉시 위치 확인 후 밖이면 닫기
                self.poll()
                if !self.viewModel.isHovering {
                    self.viewModel.handleOutsideClick()
                }
            }
        }
    }

    // MARK: - 노치 치수

    private func notchGeometry(_ screen: NSScreen) -> (CGFloat, CGFloat, CGFloat) {
        let h = max(screen.safeAreaInsets.top, 37)
        if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            return (l.maxX, r.minX - l.maxX, h)
        }
        let w: CGFloat = 182
        return (screen.frame.midX - w / 2, w, h)
    }
}
