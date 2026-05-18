import SwiftUI

// MARK: - Reusable calendar date picker
// Beige background, burgundy accents, Didot font throughout.
// Usage: CalendarPicker(selection: $date)

struct CalendarPicker: View {
    @Binding var selection: Date

    @State private var displayed: Date  // first day of the visible month

    private static let cal = Calendar(identifier: .gregorian)
    private static let weekdayHeaders = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    private let bg     = Color(red: 0.98, green: 0.96, blue: 0.94)
    private let ink    = Color(red: 0.278, green: 0, blue: 0.102)
    private let faint  = Color(red: 0.278, green: 0, blue: 0.102, opacity: 0.35)

    init(selection: Binding<Date>) {
        _selection = selection
        var comps = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month], from: selection.wrappedValue)
        comps.day = 1
        let firstOfMonth = Calendar(identifier: .gregorian).date(from: comps) ?? selection.wrappedValue
        _displayed = State(initialValue: firstOfMonth)
    }

    // All cell slots for the visible month (nil = empty leading/trailing padding)
    var cells: [Date?] {
        guard
            let range    = Self.cal.range(of: .day, in: .month, for: displayed),
            let firstDay = Self.cal.date(from: Self.cal.dateComponents([.year, .month], from: displayed))
        else { return [] }

        // Weekday offset so the grid starts on Monday
        // .weekday: 1=Sun 2=Mon … 7=Sat  →  Monday-first offset: (weekday + 5) % 7
        let firstWeekday = Self.cal.component(.weekday, from: firstDay)
        let leadingEmpties = (firstWeekday + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmpties)
        for d in range {
            result.append(Self.cal.date(byAdding: .day, value: d - 1, to: firstDay))
        }
        // Pad to full rows of 7
        let remainder = result.count % 7
        if remainder != 0 { result += Array(repeating: nil, count: 7 - remainder) }
        return result
    }

    var body: some View {
        VStack(spacing: 14) {

            // ── Month navigation ─────────────────────────────────────────
            HStack {
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ink)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(Self.monthFmt.string(from: displayed))
                    .font(.custom("Didot", size: 15).weight(.semibold))
                    .foregroundColor(ink)

                Spacer()

                Button { shift(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isCurrentMonth ? ink.opacity(0.18) : ink)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
            }

            // ── Weekday headers ──────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(Self.weekdayHeaders, id: \.self) { h in
                    Text(h)
                        .font(.custom("Didot", size: 11))
                        .foregroundColor(faint)
                        .frame(maxWidth: .infinity)
                }
            }

            // ── Day grid ─────────────────────────────────────────────────
            let grid = cells
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 4
            ) {
                ForEach(0 ..< grid.count, id: \.self) { i in
                    if let day = grid[i] {
                        DayCell(
                            date:       day,
                            isSelected: Self.cal.isDate(day, inSameDayAs: selection),
                            isToday:    Self.cal.isDateInToday(day),
                            ink:        ink,
                            faint:      faint
                        ) {
                            selection = day
                        }
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 300)
        .background(bg)
    }

    private var isCurrentMonth: Bool {
        Self.cal.isDate(displayed, equalTo: Date(), toGranularity: .month)
    }

    private func shift(_ delta: Int) {
        guard let next = Self.cal.date(byAdding: .month, value: delta, to: displayed)
        else { return }
        displayed = next
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date:       Date
    let isSelected: Bool
    let isToday:    Bool
    let ink:        Color
    let faint:      Color
    let onTap:      () -> Void

    @State private var isHovered = false

    private static let cal = Calendar(identifier: .gregorian)

    private var isFuture: Bool { date > Date() && !Self.cal.isDateInToday(date) }

    private var day: String {
        "\(Self.cal.component(.day, from: date))"
    }

    var body: some View {
        Button(action: onTap) {
            Text(day)
                .font(.custom("Didot", size: 13))
                .foregroundColor(
                    isFuture   ? ink.opacity(0.18) :
                    isSelected ? .white :
                    isToday    ? ink   :
                                 ink.opacity(0.75)
                )
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        isSelected && !isFuture ? ink :
                        isToday                 ? ink.opacity(0.13) :
                        isHovered && !isFuture  ? ink.opacity(0.07) :
                                                  Color.clear
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .onHover { h in if !isFuture { isHovered = h } }
    }
}
