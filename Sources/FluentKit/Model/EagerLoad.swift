public protocol EagerLoadRequest: class, CustomStringConvertible {
    func prepare(query: inout DatabaseQuery)
    func run(models: [AnyModel], on database: Database) -> EventLoopFuture<Void>
}

public final class EagerLoads: CustomStringConvertible {
    public var requests: [String: EagerLoadRequest]

    public var description: String {
        return self.requests.description
    }

    init() {
        self.requests = [:]
    }
}
