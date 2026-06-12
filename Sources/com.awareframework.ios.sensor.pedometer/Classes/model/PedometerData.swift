import Foundation
import com_awareframework_ios_core
import GRDB

public struct PedometerData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1
    public static let databaseTableName = "ios_pedometer"

    public var startDate: Int64 = 0
    public var endDate: Int64 = 0
    public var frequencySpeed: Double = 0
    public var numberOfSteps: Int = 0
    public var distance: Double = 0
    public var currentPace: Double = 0
    public var currentCadence: Double = 0
    public var floorsAscended: Int = 0
    public var floorsDescended: Int = 0
    public var averageActivePace: Double = 0

    public init() {}
    public init(_ dict: Dictionary<String, Any>) {
        timestamp        = dict["timestamp"] as? Int64 ?? 0
        label            = dict["label"] as? String ?? ""
        deviceId         = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        startDate        = dict["startDate"] as? Int64 ?? 0
        endDate          = dict["endDate"] as? Int64 ?? 0
        frequencySpeed   = dict["frequencySpeed"] as? Double ?? 0
        numberOfSteps    = dict["numberOfSteps"] as? Int ?? 0
        distance         = dict["distance"] as? Double ?? 0
        currentPace      = dict["currentPace"] as? Double ?? 0
        currentCadence   = dict["currentCadence"] as? Double ?? 0
        floorsAscended   = dict["floorsAscended"] as? Int ?? 0
        floorsDescended  = dict["floorsDescended"] as? Int ?? 0
        averageActivePace = dict["averageActivePace"] as? Double ?? 0
    }
    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("deviceId",.text).notNull(); t.column("timestamp",.integer).notNull()
            t.column("label",.text).notNull(); t.column("startDate",.integer).notNull()
            t.column("timezone",.integer).notNull(); t.column("os",.text).notNull()
            t.column("jsonVersion",.integer).notNull()
            t.column("endDate",.integer).notNull(); t.column("frequencySpeed",.double).notNull()
            t.column("numberOfSteps",.integer).notNull(); t.column("distance",.double).notNull()
            t.column("currentPace",.double).notNull(); t.column("currentCadence",.double).notNull()
            t.column("floorsAscended",.integer).notNull(); t.column("floorsDescended",.integer).notNull()
            t.column("averageActivePace",.double).notNull()
        }}
    }
    public func toDictionary() -> Dictionary<String, Any> {
        ["id": id ?? -1, "timestamp": timestamp, "deviceId": deviceId, "label": label,
         "startDate": startDate, "endDate": endDate, "frequencySpeed": frequencySpeed,
         "numberOfSteps": numberOfSteps, "distance": distance, "currentPace": currentPace,
         "currentCadence": currentCadence, "floorsAscended": floorsAscended,
         "floorsDescended": floorsDescended, "averageActivePace": averageActivePace]
    }
}
