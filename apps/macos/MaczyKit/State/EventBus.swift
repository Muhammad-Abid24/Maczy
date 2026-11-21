import Foundation
import Combine

/// Events broadcast across application surfaces when state changes occur.
public enum AppEvent: Sendable, Equatable {
    case moduleRuntimeChanged(
        moduleId: MaczyModuleId,
        previous: ModuleRuntimeState,
        current: ModuleRuntimeState
    )
    case actionGated(
        moduleId: MaczyModuleId,
        gateType: String,
        reason: String,
        errorCode: String
    )
    case commandExecuted(
        moduleId: MaczyModuleId,
        result: CommandResult
    )
}

/// Thread-safe event bus distributing state snapshots and transitions across surfaces.
public final class EventBus: @unchecked Sendable {
    public static let shared = EventBus()

    private let subject = PassthroughSubject<AppEvent, Never>()

    public init() {}

    public var events: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    public func publish(_ event: AppEvent) {
        subject.send(event)
    }
}
