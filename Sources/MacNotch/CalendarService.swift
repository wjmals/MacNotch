import EventKit
import SwiftUI

final class CalendarService: @unchecked Sendable {
    nonisolated(unsafe) var onUpdate: (([CalendarEvent], Bool) -> Void)?
    private let store = EKEventStore()

    func requestAndFetch() {
        if #available(macOS 14.0, *) {
            Task {
                do {
                    try await store.requestFullAccessToEvents()
                    self.fetch()
                } catch {
                    DispatchQueue.main.async { self.onUpdate?([], false) }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                if granted { self?.fetch() }
                else { DispatchQueue.main.async { self?.onUpdate?([], false) } }
            }
        }
    }

    private func fetch() {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .month, value: 1, to: start) ?? start
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events: [CalendarEvent] = store.events(matching: pred)
            .sorted { $0.startDate < $1.startDate }
            .prefix(30)
            .map { ek in
                let c = ek.calendar.cgColor.flatMap { NSColor(cgColor: $0) } ?? NSColor.systemBlue
                return CalendarEvent(id: ek.eventIdentifier ?? UUID().uuidString,
                                     title: ek.title ?? "(제목 없음)",
                                     startDate: ek.startDate, endDate: ek.endDate,
                                     color: Color(c), isAllDay: ek.isAllDay)
            }
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(events, true) }
    }
}
