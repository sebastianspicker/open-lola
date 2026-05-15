public enum RxBufferProfile: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case direct
    case small
    case adaptive
    case stableWan
}
