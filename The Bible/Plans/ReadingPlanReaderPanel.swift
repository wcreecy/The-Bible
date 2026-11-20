import SwiftUI

/// Shown where a plan reading ends in the reader: right after its last verse when it stops
/// partway through a chapter, otherwise at the end of the chapter. Offers the next reading or
/// finishing the day.
struct ReadingPlanReaderPanel: View {
    let bookName: String
    let chapterNumber: Int
    /// The verse this panel follows, or nil for the end of the chapter.
    var afterVerse: Int? = nil

    @State private var store = ReadingPlanStore.shared

    var body: some View {
        if let context = store.sessionContext(atBook: bookName, chapter: chapterNumber),
           context.isLastChapter,
           context.endsAfterVerse == afterVerse {
            content(context)
        }
    }

    private func content(_ context: ReadingPlanStore.SessionContext) -> some View {
        let session = context.session
        let readings = context.day.readings
        let isDayComplete = store.isDayComplete(session.day, planID: session.planID)
        let next = readings[safe: session.readingIndex + 1]

        return VStack(alignment: .leading, spacing: 10) {
            if afterVerse != nil {
                Label("End of today's reading", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(Color.accentColor)
                Text("\(context.plan.title) · Day \(session.day)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if readings.count > 1 {
                    Text("Reading \(session.readingIndex + 1) of \(readings.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isDayComplete {
                Label(
                    store.enrollment(for: session.planID)?.finishedAt != nil
                        ? "Plan complete. Well done!"
                        : "Day \(session.day) complete",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.green)

                if let following = store.nextReading(of: session.planID) {
                    Button {
                        store.openReading(following.index, day: following.day, of: session.planID)
                    } label: {
                        Text("Keep Going: Day \(following.day)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            } else if let next {
                Button {
                    store.advanceSession()
                } label: {
                    Text("Next: \(next.title)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
                Button {
                    store.finishSessionDay()
                    Haptics.success()
                } label: {
                    Text("Finish Day \(session.day)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.vertical, 12)
        .animation(.snappy, value: isDayComplete)
    }
}

/// A slim reminder at the top of the reader that this chapter is part of a plan, and where
/// it falls in the day. Tapping it returns to the plan day.
struct ReadingPlanReaderPill: View {
    let bookName: String
    let chapterNumber: Int

    @State private var store = ReadingPlanStore.shared

    var body: some View {
        if let context = store.sessionContext(atBook: bookName, chapter: chapterNumber) {
            Button {
                AppRouter.shared.open(.readingPlanDay(planID: context.session.planID, day: context.session.day))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                    Text("\(context.plan.title) · Day \(context.session.day)")
                        .lineLimit(1)
                    if let detail = detail(context) {
                        Text("· \(detail)")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
            .accessibilityHint("Returns to this day of the plan")
        }
    }

    /// "Chapter 1 of 3" within a long reading, otherwise "Reading 1 of 2" within the day.
    private func detail(_ context: ReadingPlanStore.SessionContext) -> String? {
        if context.chapterCount > 1 {
            return "Chapter \(context.chapterPosition) of \(context.chapterCount)"
        }
        let readings = context.day.readings.count
        return readings > 1 ? "Reading \(context.session.readingIndex + 1) of \(readings)" : nil
    }
}
