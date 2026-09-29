import SwiftData
import SwiftUI

@MainActor
struct PersistenceFailure: Identifiable {
    let id = UUID()
    let retry: () -> Void
}

@MainActor
enum ModelContextPersistence {
    static func perform(
        in context: ModelContext,
        operation: @escaping () throws -> Void,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (PersistenceFailure) -> Void
    ) {
        do {
            try operation()
            onSuccess()
        } catch {
            context.rollback()
            onFailure(
                PersistenceFailure {
                    perform(
                        in: context,
                        operation: operation,
                        onSuccess: onSuccess,
                        onFailure: onFailure
                    )
                }
            )
        }
    }
}

extension View {
    func persistenceFailureAlert(failure: Binding<PersistenceFailure?>) -> some View {
        alert(
            "Changes Couldn’t Be Saved",
            isPresented: Binding(
                get: { failure.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        failure.wrappedValue = nil
                    }
                }
            )
        ) {
            Button("Try Again") {
                let retry = failure.wrappedValue?.retry
                failure.wrappedValue = nil
                retry?()
            }
            Button("Cancel", role: .cancel) {
                failure.wrappedValue = nil
            }
        } message: {
            Text("Your changes weren’t saved. Please try again.")
        }
    }
}
