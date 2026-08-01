import Foundation
import GRDB

public struct OutboxEvent: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "sync_outbox"

    public var id: String
    public var createdAt: Date
    public var payloadJSON: String
    public var attempts: Int

    public init(id: String = UUID().uuidString, createdAt: Date = Date(), payloadJSON: String, attempts: Int = 0) {
        self.id = id
        self.createdAt = createdAt
        self.payloadJSON = payloadJSON
        self.attempts = attempts
    }
}

public final class SyncOutbox: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }

    public convenience init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.init(path: directory.appendingPathComponent("whoop.sqlite").path)
    }

    public func enqueue(payloadJSON: String) throws {
        try dbQueue.write { db in
            try OutboxEvent(payloadJSON: payloadJSON).insert(db)
        }
    }

    public func pending() throws -> [OutboxEvent] {
        try dbQueue.read { db in
            try OutboxEvent.order(Column("createdAt").asc).fetchAll(db)
        }
    }

    public func markAttempt(_ event: OutboxEvent) throws {
        var updated = event
        updated.attempts += 1
        try dbQueue.write { db in try updated.update(db) }
    }

    public func remove(id: String) throws {
        try dbQueue.write { db in
            _ = try OutboxEvent.deleteOne(db, key: id)
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createOutbox") { db in
            try db.create(table: OutboxEvent.databaseTableName, ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("createdAt", .datetime).notNull()
                table.column("payloadJSON", .text).notNull()
                table.column("attempts", .integer).notNull().defaults(to: 0)
            }
        }
        return migrator
    }
}
