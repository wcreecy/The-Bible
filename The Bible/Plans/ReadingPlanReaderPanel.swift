import SwiftUI

/// Shown at the end of a plan reading in the reader: where the reader is in the day, and the
/// way to the next reading or to finishing the day.
struct ReadingPlanReaderPanel: View {
    let bookName: String
    let chapterNumber: Int

    @State private var store = ReadingPlanStore.shared

    var body: some View {
        if let context = store.sessionReading(atBook: bookName, chapter: chapterNumber) {
            content(context)
        }
    }

    private func content(
        _ context: (session: ReadingPlanStore.Session, plan: ReadingPlan, day: PlanDay, reading: PlanReading)
    ) -> some View {
        let session = context.session
        let readings = context.day.readings
        let isDayComplete = store.isDayComplete(session.day, planID: session.planID)
        let next = readings[safe: session.readingIndex + 1]

        return VStack(alignment: .leading, spacing: 10) {
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

                if let following = store.plan(id: session.planID).flatMap({ store.currentDay(of: $0) }) {
                    Button {
                        store.openReading(0, day: following.day, of: session.planID)
                    } label: {
                        Label("Keep Going: Day \(following.day)", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else if let next {
                Button {
                    store.advanceSession()
                } label: {
                    Label("Next: \(next.title)", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    store.finishSessionDay()
                    Haptics.success()
                } label: {
                    Label("Finish Day \(session.day)", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.vertical, 12)
        .animation(.snappy, value: isDayComplete)
    }
}
