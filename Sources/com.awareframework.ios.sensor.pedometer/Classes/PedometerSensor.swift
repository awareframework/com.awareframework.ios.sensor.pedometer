//
//  PedometerSensor.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/11/12.
//

import UIKit
import SwiftyJSON
import CoreMotion
import com_awareframework_ios_core

public class PedometerSensor: AwareSensor {
    
    public static let TAG = "AWARE::Pedometer"
    public var CONFIG:PedometerSensor.Config = Config()
    
    private static let historyLimit: TimeInterval = 7 * 24 * 60 * 60

    // Lifecycle and the query/save slot are owned by the main queue. A new manager identifies a new run.
    private var pedometer: CMPedometer?
    private var timer: Timer?
    private var isQuerying = false
    private var isSaving = false
    private let makePedometer: () -> CMPedometer?
    /// Rows are written here, one batch at a time in the order they were collected: off the main
    /// thread and off the queue that delivers the query results. `.utility`, since storing data is not work
    /// the user waits for (a queue created for each save ran at the receiving queue's priority).
    private let saveQueue = DispatchQueue(label: "com.awareframework.ios.sensor.pedometer.save", qos: .utility)

    // MARK: Debug trace (CONFIG.debug): see HistoryTrace. Main queue only.
    let trace = HistoryTrace(name: "pedometer", tag: PedometerSensor.TAG)
    private static let stallThreshold: TimeInterval = 120
    private var runID = 0
    private var tickCount = 0
    private var querySeq = 0
    private var queryStartedAt: Date?
    private var queryWindow: DateInterval?
    private var saveStartedAt: Date?
    
    public class Config:SensorConfig {
        
        /**
         * The sensing interval in seconds for step counts. (default = 10 min)
         * This value must be greater than 0.
         */
        public var sampleIntervalSeconds:Int = 600
        {
            didSet {
                if self.sampleIntervalSeconds <= 0 {
                    print("[Pedometer][Illegal Parameter]",
                          "The 'sampleIntervalSeconds' value has to be greater than 0.",
                          "This parameter ('\(self.sampleIntervalSeconds)' is ignored.)")
                    self.sampleIntervalSeconds = oldValue
                }
            }
        }
        
        public var sensorObserver:PedometerObserver?
        
        public override init() {
            super.init()
            dbTableName = PedometerData.databaseTableName
            dbPath = "aware_pedometer"
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            if let sampleIntervalSeconds = config["sampleIntervalSeconds"] as? Int{
                self.sampleIntervalSeconds = sampleIntervalSeconds
            }
        }
        
        public func apply(closure:(_ config: PedometerSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    public override convenience init() {
        self.init(PedometerSensor.Config())
    }
    

    /// Creates this sensor's table if it does not exist yet, so that the first save does not fail.
    /// Failures are logged: without the table, the data cannot be saved or uploaded.
    private func initializeTables() {
        guard CONFIG.dbType == .sqlite else { return }
        guard let queue = (dbEngine as? SQLiteEngine)?.getSQLiteInstance() else {
            print(PedometerSensor.TAG, "[Error] Cannot open the database '\(CONFIG.dbPath)'. The table is not created.")
            return
        }
        let tables: [(name: String, create: () throws -> Void)] = [
            (PedometerData.databaseTableName, { try PedometerData.createTable(queue: queue) }),
        ]
        for table in tables {
            do {
                try table.create()
            } catch {
                print(PedometerSensor.TAG, "[Error] Cannot create the table '\(table.name)': \(error)")
            }
        }
    }

    public convenience init(_ config: Config) {
        self.init(config, makePedometer: {
            CMPedometer.isStepCountingAvailable() ? CMPedometer() : nil
        })
    }

    init(_ config: Config, makePedometer: @escaping () -> CMPedometer?) {
        self.makePedometer = makePedometer
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        initializeTables()
        super.syncConfig = DbSyncConfig().apply { c in
            c.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.pedometer.sync.queue")
        }
    }
    
    override public func start() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.start() }
            return
        }
        guard pedometer == nil else { return }
        guard let manager = makePedometer() else {
            print(PedometerSensor.TAG, "Step Counting is not available.")
            return
        }

        pedometer = manager
        runID += 1
        trace.isEnabled = CONFIG.debug
        trace.log("START run=\(runID) authorization=\(CMPedometer.authorizationStatus().rawValue) interval=\(CONFIG.sampleIntervalSeconds)s cursor=\(trace.format(UserDefaults.standard.object(forKey: Self.KEY_LAST_UPDATE_DATETIME) as? Date)) isQuerying=\(isQuerying) isSaving=\(isSaving)")
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(CONFIG.sampleIntervalSeconds), repeats: true) { [weak self] firedTimer in
            guard let self else {
                firedTimer.invalidate()
                return
            }
            guard self.timer === firedTimer else { return }
            self.traceTick()
            self.getPedometerData()
        }
        timer?.fire()
        notificationCenter.post(name: .actionAwarePedometerStart, object: self)
    }
    
    override public func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return
        }
        guard pedometer != nil else { return }
        trace.log("STOP run=\(runID) isQuerying=\(isQuerying) (#\(querySeq)) isSaving=\(isSaving) cursor=\(trace.format(UserDefaults.standard.object(forKey: Self.KEY_LAST_UPDATE_DATETIME) as? Date))")
        timer?.invalidate()
        timer = nil
        pedometer = nil
        isQuerying = false
        // An accepted write keeps its slot until completion, even if a new run starts meanwhile.
        notificationCenter.post(name: .actionAwarePedometerStop, object: self)
    }
    
    override public func sync(force: Bool = false) {
        guard let engine = self.dbEngine, let syncConfig = self.syncConfig else { return }
        syncConfig.debug = self.CONFIG.debug
        syncConfig.completionHandler = { (status, error) in
            var userInfo: Dictionary<String,Any> = [PedometerSensor.EXTRA_STATUS: status]
            if let e = error { userInfo[PedometerSensor.EXTRA_ERROR] = e }
            self.notificationCenter.post(name: .actionAwarePedometerSyncCompletion, object: self, userInfo: userInfo)
        }
        engine.startSync(syncConfig)
        self.notificationCenter.post(name: .actionAwarePedometerSync, object: self)
    }
    
    public override func set(label:String){
        self.CONFIG.label = label
        self.notificationCenter.post(name: .actionAwarePedometerSetLabel,
                                     object: self,
                                     userInfo: [PedometerSensor.EXTRA_LABEL:label])
    }
    
    public func getPedometerData() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.getPedometerData() }
            return
        }
        guard let pedometer else { return }
        // Each tick catches up to now: a window takes a few milliseconds, so there is no per-tick limit
        fetchNextWindow(using: pedometer, through: Date(), done: 0)
    }

    static func historyWindow(after cursor: Date, through now: Date, interval: TimeInterval) -> DateInterval? {
        guard interval.isFinite, interval > 0 else { return nil }
        let start = max(cursor, now.addingTimeInterval(-historyLimit))
        let end = start.addingTimeInterval(interval)
        guard end > start, end <= now else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func fetchNextWindow(using pedometer: CMPedometer, through now: Date, done: Int) {
        guard self.pedometer === pedometer else { return traceTickEnd(done, "stale manager (stopped/restarted)") }
        guard !isQuerying else { return traceTickEnd(done, "busy: query #\(querySeq) outstanding \(age(queryStartedAt))") }
        guard !isSaving else { return traceTickEnd(done, "busy: save outstanding \(age(saveStartedAt))") }
        guard let cursor = getLastUpdateDateTime() else { return traceTickEnd(done, "no cursor") }
        guard let window = Self.historyWindow(after: cursor, through: now,
                                              interval: TimeInterval(CONFIG.sampleIntervalSeconds)) else {
            return traceTickEnd(done, "caught up (cursor=\(trace.format(cursor)))")
        }
        isQuerying = true
        querySeq += 1
        let seq = querySeq
        let run = runID
        let issuedAt = Date()
        queryStartedAt = issuedAt
        queryWindow = window
        pedometer.queryPedometerData(from: window.start, to: window.end) { [weak self, weak pedometer] result, error in
            let calledBackAt = Date()
            DispatchQueue.main.async {
                guard let self else { return }
                let queryMs = Int(calledBackAt.timeIntervalSince(issuedAt) * 1000)
                let hopMs = Int(Date().timeIntervalSince(calledBackAt) * 1000)
                guard let pedometer, self.pedometer === pedometer else {
                    self.trace.log("LATE query #\(seq) of run \(run) answered after \(queryMs)ms; current run=\(self.runID) isQuerying=\(self.isQuerying)")
                    return
                }
                self.isQuerying = false
                self.queryStartedAt = nil
                guard error == nil, let result else {
                    let nsError = error as NSError?
                    self.trace.log("QUERY #\(seq) FAILED \(self.trace.format(window.start))..\(self.trace.format(window.end)) after \(queryMs)ms hop=\(hopMs)ms error=\(nsError.map { "\($0.domain)/\($0.code) \($0.localizedDescription)" } ?? "nil result")")
                    if self.CONFIG.debug {
                        print(Self.TAG, "Pedometer history query failed:", error?.localizedDescription ?? "No data")
                    }
                    return
                }

                var data = PedometerData()
                data.startDate = Int64(window.start.timeIntervalSince1970 * 1000)
                data.endDate = Int64(window.end.timeIntervalSince1970 * 1000)
                data.timestamp = data.endDate
                data.numberOfSteps = result.numberOfSteps.intValue
                data.currentCadence = result.currentCadence?.doubleValue ?? 0
                data.currentPace = result.currentPace?.doubleValue ?? 0
                data.distance = result.distance?.doubleValue ?? 0
                data.averageActivePace = result.averageActivePace?.doubleValue ?? 0
                data.floorsAscended = result.floorsAscended?.intValue ?? 0
                data.floorsDescended = result.floorsDescended?.intValue ?? 0
                data.label = self.CONFIG.label

                if self.CONFIG.dbType == .none {
                    self.finishWindow(data, end: window.end, using: pedometer, through: now, done: done)
                    return
                }
                guard let engine = self.dbEngine else {
                    print(Self.TAG, "Pedometer history save failed: database is unavailable")
                    return
                }
                let row = data
                self.isSaving = true
                let saveQueuedAt = Date()
                self.saveStartedAt = saveQueuedAt
                self.saveQueue.async { [weak self] in
                    let saveBeganAt = Date()
                    engine.save([row]) { error in
                        let savedAt = Date()
                        DispatchQueue.main.async {
                            guard let self else { return }
                            self.isSaving = false
                            self.saveStartedAt = nil
                            let waitMs = Int(saveBeganAt.timeIntervalSince(saveQueuedAt) * 1000)
                            let saveMs = Int(savedAt.timeIntervalSince(saveBeganAt) * 1000)
                            if let error {
                                self.trace.log("SAVE #\(seq) FAILED after wait=\(waitMs)ms save=\(saveMs)ms error=\(error)")
                                print(Self.TAG, "Pedometer history save failed:", error)
                                return
                            }
                            self.trace.log("WIN #\(seq) \(self.trace.format(window.start)) steps=\(row.numberOfSteps) query=\(queryMs)ms hop=\(hopMs)ms saveWait=\(waitMs)ms save=\(saveMs)ms")
                            self.finishWindow(row, end: window.end, using: pedometer, through: now, done: done)
                        }
                    }
                }
            }
        }
    }

    // MARK: Debug trace

    private func age(_ date: Date?) -> String {
        guard let date else { return "?s" }
        return String(format: "%.1fs", Date().timeIntervalSince(date))
    }

    /// One line per timer tick, and a STALL line while a query or save has not finished for long
    private func traceTick() {
        tickCount += 1
        trace.isEnabled = CONFIG.debug
        guard trace.isEnabled else { return }
        let cursor = UserDefaults.standard.object(forKey: Self.KEY_LAST_UPDATE_DATETIME) as? Date
        trace.log("TICK #\(tickCount) run=\(runID) app=\(trace.appState) protectedData=\(trace.protectedDataAvailable) manager=\(pedometer != nil) isQuerying=\(isQuerying) isSaving=\(isSaving) cursor=\(trace.format(cursor)) lag=\(cursor.map { Int(Date().timeIntervalSince($0) / 60) } ?? -1)min")
        if isQuerying, let started = queryStartedAt, Date().timeIntervalSince(started) > Self.stallThreshold {
            trace.log("STALL query #\(querySeq) outstanding \(age(started)) window=\(trace.format(queryWindow?.start))..\(trace.format(queryWindow?.end)) authorization=\(CMPedometer.authorizationStatus().rawValue)")
        }
        if isSaving, let started = saveStartedAt, Date().timeIntervalSince(started) > Self.stallThreshold {
            trace.log("STALL save outstanding \(age(started))")
        }
    }

    private func traceTickEnd(_ windows: Int, _ reason: String) {
        trace.log("TICK END windows=\(windows) reason=\(reason)")
    }

    private func finishWindow(_ data: PedometerData, end: Date, using pedometer: CMPedometer,
                              through now: Date, done: Int) {
        if let cursor = getLastUpdateDateTime(), cursor < end {
            setLastUpdateDateTime(end)
        }
        guard self.pedometer === pedometer else { return }
        CONFIG.sensorObserver?.onPedometerChanged(data: data)
        guard self.pedometer === pedometer else { return }
        notificationCenter.post(name: .actionAwarePedometer, object: self)
        fetchNextWindow(using: pedometer, through: now, done: done + 1)
    }
}

public protocol PedometerObserver {
    func onPedometerChanged(data:PedometerData)
}

extension Notification.Name {
    public static let actionAwarePedometer = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER)
    public static let actionAwarePedometerStart    = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_START)
    public static let actionAwarePedometerStop     = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_STOP)
    public static let actionAwarePedometerSync     = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_SYNC)
    public static let actionAwarePedometerSetLabel = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_SET_LABEL)
    public static let actionAwarePedometerSyncCompletion  = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_SYNC_COMPLETION)
}

extension PedometerSensor {
    public static let ACTION_AWARE_PEDOMETER       = "com.awareframework.ios.sensor.pedometer"
    public static let ACTION_AWARE_PEDOMETER_START = "com.awareframework.ios.sensor.pedometer.ACTION_AWARE_PEDOMETER_START"
    public static let ACTION_AWARE_PEDOMETER_STOP  = "com.awareframework.ios.sensor.pedometer.ACTION_AWARE_PEDOMETER_STOP"
    public static let ACTION_AWARE_PEDOMETER_SET_LABEL = "com.awareframework.ios.sensor.pedometer.ACTION_AWARE_PEDOMETER_SET_LABEL"
    public static let ACTION_AWARE_PEDOMETER_SYNC  = "com.awareframework.ios.sensor.pedometer.ACTION_AWARE_PEDOMETER_SYNC"
    public static let EXTRA_LABEL = "label"

    
    public static let ACTION_AWARE_PEDOMETER_SYNC_COMPLETION = "com.awareframework.ios.sensor.pedometer.SENSOR_SYNC_COMPLETION"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"

}

extension PedometerSensor {
    
    public static let KEY_LAST_UPDATE_DATETIME = "com.awareframework.ios.sensor.pedometer.key.last_update_datetime";
    
    public func getFomattedDateTime(_ date:Date) -> Date?{
        let calendar = Calendar.current
        let year  = calendar.component(.year,   from: date)
        let month = calendar.component(.month,  from: date)
        let day   = calendar.component(.day,    from: date)
        let hour  = calendar.component(.hour,   from: date)
        let min   = calendar.component(.minute, from: date)
        let newDate = calendar.date(from: DateComponents(year:year, month:month, day:day, hour:hour, minute:min))
        return newDate
    }
    
    public func getLastUpdateDateTime() -> Date? {
        if let datetime = UserDefaults.standard.object(forKey: PedometerSensor.KEY_LAST_UPDATE_DATETIME) as? Date {
            return datetime
        }
        let now = Date()
        let start = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        setLastUpdateDateTime(start)
        return start
    }
    
    public func setLastUpdateDateTime(_ datetime:Date){
        UserDefaults.standard.set(datetime, forKey: PedometerSensor.KEY_LAST_UPDATE_DATETIME)
    }
    
}
