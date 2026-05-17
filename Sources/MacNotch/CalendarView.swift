import SwiftUI

struct CalendarTabView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        if !vm.calendarAuthorized {
            CalPermView()
        } else {
            HStack(alignment: .top, spacing: 14) {
                EventsPanel(events: vm.upcomingEvents).frame(maxWidth: 190)
                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 0.5)
                MiniCal(vm: vm)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
        }
    }
}

struct CalPermView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28)).foregroundColor(.white.opacity(0.3))
            Text("달력 접근 권한 필요")
                .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.6))
            Text("시스템 설정 → 개인정보 → 달력에서\nMacNotch를 허용해주세요.")
                .font(.system(size: 10)).foregroundColor(.white.opacity(0.35)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventsPanel: View {
    let events: [CalendarEvent]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("다가오는 일정")
                .font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.35)).padding(.bottom, 8)
            if events.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20)).foregroundColor(.white.opacity(0.2))
                    Text("예정된 일정 없음")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let first = events.first {
                    FirstEventCard(event: first).padding(.bottom, 8)
                }
                VStack(spacing: 4) {
                    ForEach(events.dropFirst().prefix(3)) { e in
                        SmallEventRow(event: e)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct FirstEventCard: View {
    let event: CalendarEvent
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 3, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.timeString).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                    Text("·").foregroundColor(.white.opacity(0.3))
                    Text(event.relativeString).font(.system(size: 10, weight: .medium)).foregroundColor(.orange)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(event.color.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(event.color.opacity(0.3), lineWidth: 0.5)))
    }
}

struct SmallEventRow: View {
    let event: CalendarEvent
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(event.color).frame(width: 5, height: 5)
            Text(event.title).font(.system(size: 11)).foregroundColor(.white.opacity(0.7)).lineLimit(1)
            Spacer()
            Text(event.timeString).font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
        }
    }
}

// MARK: - Mini Calendar

struct MiniCal: View {
    @ObservedObject var vm: NotchViewModel
    private let wd  = ["일","월","화","수","목","금","토"]
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: prevMonth) {
                    Image(systemName: "chevron.left").font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45)).frame(width: 20, height: 20).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Spacer()
                Text(monthLabel).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.75))
                Spacer()
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45)).frame(width: 20, height: 20).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            HStack(spacing: 0) {
                ForEach(wd, id: \.self) { d in
                    Text(d).font(.system(size: 9, weight: .semibold))
                        .foregroundColor(d == "일" ? .red.opacity(0.6) : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(Array(calDays.enumerated()), id: \.offset) { idx, date in
                    DayCell(date: date, weekdayIndex: idx % 7, keys: vm.eventDayKeys)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var monthLabel: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "ko_KR"); df.dateFormat = "yyyy년 M월"
        return df.string(from: vm.currentMonth)
    }

    private func prevMonth() {
        vm.currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: vm.currentMonth) ?? vm.currentMonth
    }
    private func nextMonth() {
        vm.currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: vm.currentMonth) ?? vm.currentMonth
    }

    private var calDays: [Date?] {
        var cal = Calendar.current; cal.firstWeekday = 1
        let comps = cal.dateComponents([.year, .month], from: vm.currentMonth)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let offset = cal.component(.weekday, from: first) - 1
        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            var c = comps; c.day = d; days.append(cal.date(from: c))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Day Cell (모든 계산을 computed property로 분리)

struct DayCell: View {
    let date: Date?
    let weekdayIndex: Int
    let keys: Set<String>

    private var exists: Bool { date != nil }

    private var dayNum: Int {
        guard let d = date else { return 0 }
        return Calendar.current.component(.day, from: d)
    }

    private var isToday: Bool {
        guard let d = date else { return false }
        return Calendar.current.isDateInToday(d)
    }

    private var hasEvent: Bool {
        guard let d = date else { return false }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return keys.contains(df.string(from: d))
    }

    private var isSunday: Bool { weekdayIndex == 0 }

    private var textColor: Color {
        if isToday    { return .black }
        if isSunday   { return .red.opacity(0.7) }
        return .white.opacity(0.7)
    }

    var body: some View {
        Group {
            if exists {
                VStack(spacing: 1) {
                    ZStack {
                        if isToday { Circle().fill(Color.white).frame(width: 20, height: 20) }
                        Text("\(dayNum)")
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundColor(textColor)
                    }
                    .frame(width: 20, height: 20)
                    Circle()
                        .fill(hasEvent ? Color.blue.opacity(0.8) : Color.clear)
                        .frame(width: 3, height: 3)
                }
            } else {
                Color.clear.frame(height: 24)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
