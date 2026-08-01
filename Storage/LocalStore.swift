import Foundation
import GRDB

public struct DailyMetricsRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public static let databaseTableName = "daily_metrics"

    public var date: String
    public var json: String

    public init(date: String, json: String) {
        self.date = date
        self.json = json
    }
}

public final class LocalStore: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }

    public convenience init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.init(path: directory.appendingPathComponent("whoop.sqlite").path)
    }

    public func saveDailyMetrics(date: String, json: String) throws {
        try dbQueue.write { db in
            try DailyMetricsRecord(date: date, json: json).save(db)
        }
    }

    public func dailyMetrics(date: String) throws -> DailyMetricsRecord? {
        try dbQueue.read { db in
            try DailyMetricsRecord.fetchOne(db, key: date)
        }
    }

    public func allDailyMetrics() throws -> [DailyMetricsRecord] {
        try dbQueue.read { db in
            try DailyMetricsRecord.order(Column("date").desc).fetchAll(db)
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDailyMetrics") { db in
            try db.create(table: DailyMetricsRecord.databaseTableName, ifNotExists: true) { table in
                table.column("date", .text).primaryKey()
                table.column("json", .text).notNull()
            }
        }
        return migrator
    }
}
