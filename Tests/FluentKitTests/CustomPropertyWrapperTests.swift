//
//  CustomPropertyWrapperTests.swift
//  
//
//  Created by Stuart A. Malone on 11/4/19.
//

// The main purpose of these tests is to ensure that users can define
// their own custom property wrappers for data model relationships.
// We do this by using only the public interface to FluentKit, and making
// sure that the built-in @Parent and @Children property wrappers can
// compile using only the public APIs.

// There are mark comments showing which files these tests have been copied from.
// The name of each property wrapper is then changed to prepend Custom.
// These property wrappers should then compile just like their built-in
// counterparts.

import Foundation
import FluentKit
import XCTest

// MARK: Parent.swift
// Parent ==> CustomParent
// OptionalParent ==> CustomOptionalParent

@propertyWrapper
public final class CustomParent<To>
    where To: Model
{
    @Field
    public var id: To.IDValue

    public var wrappedValue: To {
        get {
            guard let value = self.eagerLoadedValue else {
                fatalError("CustomParent relation not eager loaded, use $ prefix to access")
            }
            return value
        }
        set { fatalError("use $ prefix to access") }
    }

    public var projectedValue: CustomParent<To> {
        return self
    }

    var eagerLoadedValue: To?

    public init(key: String) {
        self._id = .init(key: key)
    }

    public func query(on database: Database) -> QueryBuilder<To> {
        return To.query(on: database)
            .filter(\._$id == self.id)
    }

    public func get(on database: Database) -> EventLoopFuture<To> {
        return self.query(on: database).first().flatMapThrowing { parent in
            guard let parent = parent else {
                throw FluentError.missingParent
            }
            return parent
        }
    }

}

extension CustomParent: FieldRepresentable {
    public var field: Field<To.IDValue> {
        return self.$id
    }
}

extension CustomParent: AnyProperty {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let parent = self.eagerLoadedValue {
            try container.encode(parent)
        } else {
            try container.encode([
                To.key(for: \._$id): self.id
            ])
        }
    }

    public func decode(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _ModelCodingKey.self)
        try self.$id.decode(from: container.superDecoder(forKey: .string(To.key(for: \._$id))))
        // TODO: allow for nested decoding
    }
}

extension CustomParent: AnyField { }


// MARK: OptionalParent.swift
// OptionalParent ==> CustomOptionalParent

@propertyWrapper
public final class CustomOptionalParent<To>
    where To: Model
{
    @Field
    public var id: To.IDValue?

    public var wrappedValue: To? {
        get {
            guard self.didEagerLoad else {
                fatalError("Optional parent relation not eager loaded, use $ prefix to access")
            }
            return self.eagerLoadedValue
        }
        set { fatalError("use $ prefix to access") }
    }

    public var projectedValue: CustomOptionalParent<To> {
        return self
    }

    var eagerLoadedValue: To?
    var didEagerLoad: Bool

    public init(key: String) {
        self._id = .init(key: key)
        self.didEagerLoad = false
    }

    public func query(on database: Database) -> QueryBuilder<To> {
        return To.query(on: database)
            .filter(\._$id == self.id)
    }

    public func get(on database: Database) -> EventLoopFuture<To?> {
        return self.query(on: database).first()
    }

}

extension CustomOptionalParent: FieldRepresentable {
    public var field: Field<To.IDValue?> {
        return self.$id
    }
}

extension CustomOptionalParent: AnyProperty {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let parent = self.eagerLoadedValue {
            try container.encode(parent)
        } else {
            try container.encode([
                To.key(for: \._$id): self.id
            ])
        }
    }

    public func decode(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _ModelCodingKey.self)
        try self.$id.decode(from: container.superDecoder(forKey: .string(To.key(for: \._$id))))
        // TODO: allow for nested decoding
    }
}

extension CustomOptionalParent: AnyField { }


// MARK: Parent+EagerLoad.swift
// Parent ==> CustomParent
// OptionalParent ==> CustomOptionalParent
// ParentSubqueryEagerLoad ==> CustomParentSubqueryEagerLoad

extension CustomParent: AnyEagerLoadable {
    public var eagerLoadKey: String {
        return "p:" + self.$id.key
    }

    public var eagerLoadValueDescription: CustomStringConvertible? {
        return self.eagerLoadedValue
    }

    public func eagerLoad(from eagerLoads: EagerLoads) throws {
        guard let request = eagerLoads.requests[self.eagerLoadKey] else {
            return
        }

        if let subquery = request as? CustomParentSubqueryEagerLoad<To> {
            self.eagerLoadedValue = try subquery.get(id: id)
        } else {
            fatalError("unsupported eagerload request: \(request)")
        }
    }
}

extension CustomParent: EagerLoadable {
    public func eagerLoad<Model>(to builder: QueryBuilder<Model>)
        where Model: FluentKit.Model
    {
        builder.eagerLoads.requests[self.eagerLoadKey] = CustomParentSubqueryEagerLoad<To>(
            key: self.$id.key
        )
    }
}


extension CustomOptionalParent: AnyEagerLoadable {
    public var eagerLoadKey: String {
        return "p:" + self.$id.key
    }

    public var eagerLoadValueDescription: CustomStringConvertible? {
        return self.eagerLoadedValue
    }

    public func eagerLoad(from eagerLoads: EagerLoads) throws {
        guard let request = eagerLoads.requests[self.eagerLoadKey] else {
            return
        }

        self.didEagerLoad = true
        guard let id = self.id else {
            return
        }

        if let subquery = request as? CustomParentSubqueryEagerLoad<To> {
            self.eagerLoadedValue = try subquery.get(id: id)
        } else {
            fatalError("unsupported eagerload request: \(request)")
        }
    }
}

extension CustomOptionalParent: EagerLoadable {
    public func eagerLoad<Model>(to builder: QueryBuilder<Model>)
        where Model: FluentKit.Model
    {
        builder.eagerLoads.requests[self.eagerLoadKey] = CustomParentSubqueryEagerLoad<To>(
            key: self.$id.key
        )
    }
}

// MARK: Private

private final class CustomParentSubqueryEagerLoad<To>: EagerLoadRequest
    where To: Model
{
    let key: String
    var storage: [To]

    var description: String {
        return self.storage.description
    }

    init(key: String) {
        self.storage = []
        self.key = key
    }

    func prepare(query: inout DatabaseQuery) {
        // no preparation needed
    }

    func run(models: [AnyModel], on database: Database) -> EventLoopFuture<Void> {
        let ids: [To.IDValue] = models
            .compactMap { try! $0.anyID.cachedOutput!.decode(self.key, as: To.IDValue?.self) }
        
        guard !ids.isEmpty else {
            return database.eventLoop.makeSucceededFuture(())
        }

        let uniqueIDs = Array(Set(ids))
        return To.query(on: database)
            .filter(To.key(for: \._$id), in: uniqueIDs)
            .all()
            .map { self.storage = $0 }
    }

    func get(id: To.IDValue) throws -> To? {
        return self.storage.filter { parent in
            return parent.id == id
        }.first
    }
}
