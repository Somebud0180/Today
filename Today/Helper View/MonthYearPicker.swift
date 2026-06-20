//
//  MonthYearPicker.swift
//  Today
//
//  Created by Ethan John Lagera on 6/10/26.
//  Base code made with ChatGPT via Xcode
//

import SwiftUI
import UIKit

// MARK: - Public SwiftUI facade
struct MonthYearPicker<Label: View>: View {
    @Binding private var date: Date
    private let minYear: Int
    private let maxYear: Int
    @ViewBuilder private let label: () -> Label

    @State private var isPresenting = false
    @State private var workingDate: Date

    init(date: Binding<Date>, minYear: Int = 1970, maxYear: Int = 2100, @ViewBuilder label: @escaping () -> Label) {
        self._date = date
        self.minYear = minYear
        self.maxYear = maxYear
        self.label = label
        _workingDate = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        Button {
            workingDate = date
            isPresenting = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isPresenting,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
            ) {
            VStack(spacing: 12) {
                MonthYearWheel(date: $workingDate, minYear: minYear, maxYear: maxYear)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: workingDate) {
                        withAnimation(.snappy) {
                            date = workingDate
                        }
                    }

                HStack {
                    Spacer()
                    Button("Reset") {
                        withAnimation(.snappy) {
                            date = Calendar.current.dateComponents([.year, .month], from: Date()).date ?? Date()
                            isPresenting = false
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                .padding(8)
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Internal UIKit-backed wheel representable
private struct MonthYearWheel: UIViewRepresentable {
    @Binding var date: Date
    var minYear: Int = 1970
    var maxYear: Int = 2100

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        // Use year & month mode when available. Fallback to .date.
        if #available(iOS 17.0, *) {
            picker.datePickerMode = .yearAndMonth
        } else {
            picker.datePickerMode = .date
        }
        picker.preferredDatePickerStyle = .wheels
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)

        // Limit range to min/max years
        let cal = Calendar.current
        let minDate = cal.date(from: DateComponents(year: minYear, month: 1, day: 1))!
        let maxDate = cal.date(from: DateComponents(year: maxYear, month: 12, day: 31))!
        picker.minimumDate = minDate
        picker.maximumDate = maxDate

        picker.setDate(date, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        if !Calendar.current.isDate(uiView.date, inSameDayAs: date) {
            uiView.setDate(date, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: MonthYearWheel
        init(_ parent: MonthYearWheel) { self.parent = parent }

        @objc func valueChanged(_ sender: UIDatePicker) {
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: sender.date)
            let year = comps.year ?? cal.component(.year, from: Date())
            let month = comps.month ?? cal.component(.month, from: Date())

            let currentDay = cal.component(.day, from: parent.date)
            let startOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
            let range = cal.range(of: .day, in: .month, for: startOfMonth)!
            let clampedDay = min(currentDay, range.count)

            let newDate = cal.date(from: DateComponents(year: year, month: month, day: clampedDay))!
            parent.date = newDate
        }
    }
}
