import SwiftUI

struct SettingsVOTDSection: View {
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""

    @AppStorage("votdRefreshFrequency") private var refreshFrequencyRaw: String = VOTDRefreshFrequency.custom.rawValue
    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    private var refresh1DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let now = Date()
                return VOTDSchedule.dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: now) ?? now
            },
            set: { newDate in
                let cal = Calendar.autoupdatingCurrent
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh1Hour = c.hour ?? 6
                votdRefresh1Minute = c.minute ?? 0
            }
        )
    }

    private var refresh2DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let now = Date()
                return VOTDSchedule.dateForToday(hour: votdRefresh2Hour, minute: votdRefresh2Minute, from: now) ?? now
            },
            set: { newDate in
                let cal = Calendar.autoupdatingCurrent
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh2Hour = c.hour ?? 18
                votdRefresh2Minute = c.minute ?? 0
            }
        )
    }

    private var refreshFrequency: VOTDRefreshFrequency {
        VOTDRefreshFrequency(rawValue: refreshFrequencyRaw) ?? .custom
    }

    private var nextVOTDDescription: String {
        VOTDSchedule.nextAutoRefreshDescription(
            frequency: refreshFrequency,
            first: (votdRefresh1Hour, votdRefresh1Minute),
            second: (votdRefresh2Hour, votdRefresh2Minute)
        )
    }

    var body: some View {
        Section(
            header: Text("Verse of the Day").foregroundStyle(.white),
            footer: Text("Choose where verses come from and how often they refresh. Auto-refresh remains disabled while the verse is paused on the Home page.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
        ) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    segmentButton(title: "OT", tag: "old")
                    verticalSeparator()
                    segmentButton(title: "NT", tag: "new")
                    verticalSeparator()
                    segmentButton(title: "OT/NT", tag: "whole")
                    verticalSeparator()
                    segmentButton(title: "Book", tag: "book")
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("verseOfDayScopePicker")

                if verseScopeRaw == "book" {
                    BookSelectionLink(
                        selectedBookName: Binding<String?>(
                            get: { verseSpecificBook.isEmpty ? nil : verseSpecificBook },
                            set: { verseSpecificBook = $0 ?? "" }
                        )
                    )
                    .accessibilityIdentifier("verseOfDaySpecificBookPicker")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Auto-Refresh", systemImage: "clock.arrow.2.circlepath")
                        .font(.headline)

                    Picker("Refresh Frequency", selection: $refreshFrequencyRaw) {
                        ForEach(VOTDRefreshFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("votdRefreshFrequency")

                    if refreshFrequency == .custom {
                        DatePicker("Morning Refresh", selection: refresh1DateBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityIdentifier("votdRefreshTime1")

                        DatePicker("Evening Refresh", selection: refresh2DateBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityIdentifier("votdRefreshTime2")
                    } else if refreshFrequency == .daily {
                        DatePicker("Daily Refresh Time", selection: refresh1DateBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityIdentifier("votdDailyRefreshTime")
                    }

                    Text(nextVOTDDescription)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .accessibilityIdentifier("votdNextRefreshDescription")
                }
                .padding(.top, 8)
            }
        }
        .headerProminence(.increased)
    }

    private func segmentButton(title: String, tag: String) -> some View {
        Button(action: { verseScopeRaw = tag }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(verseScopeRaw == tag ? .semibold : .regular)
                .foregroundStyle(verseScopeRaw == tag ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if verseScopeRaw == tag {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 24)
    }
}
