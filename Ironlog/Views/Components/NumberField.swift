import SwiftUI

/// Text field bound to a number that commits on every keystroke (a formatted
/// `TextField` only commits on return, which loses values when you tap ✓ directly).
struct NumberField: View {
    @Binding var value: Double
    var placeholder: String
    var allowsDecimal = true

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit())
            .focused($focused)
            #if os(iOS)
            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
            #endif
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, newText in
                if newText.isEmpty {
                    if value != 0 { value = 0 }
                } else if let parsed = Self.parse(newText, allowsDecimal: allowsDecimal), parsed != value {
                    value = parsed
                }
            }
            .onChange(of: value) { _, newValue in
                if !focused { text = Self.format(newValue) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = Self.format(value) }
            }
    }

    static func format(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    static func parse(_ text: String, allowsDecimal: Bool) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normalized), number >= 0 else { return nil }
        return allowsDecimal ? number : number.rounded(.down)
    }
}

extension Binding where Value == Int {
    /// Bridges an Int binding into the Double-based `NumberField`.
    var asDouble: Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = Int($0) }
        )
    }
}

struct WeekdayPicker: View {
    @Binding var mask: Int

    private var weekdays: [(weekday: Int, symbol: String)] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return (weekday, symbols[weekday - 1])
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.weekday) { day in
                let bit = 1 << (day.weekday - 1)
                let on = mask & bit != 0
                Button {
                    mask ^= bit
                } label: {
                    Text(day.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(on ? Color.black : Theme.secondary)
                        .background(on ? Color.accentColor : Theme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day.weekday - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct WeekdayDots: View {
    let mask: Int

    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let today = calendar.component(.weekday, from: .now)
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { offset in
                let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
                let on = mask & (1 << (weekday - 1)) != 0
                Text(symbols[weekday - 1])
                    .font(.system(size: 10, weight: weekday == today ? .bold : .medium))
                    .foregroundStyle(on ? Color.accentColor : Theme.tertiary)
                    .frame(width: 14)
            }
        }
    }
}
