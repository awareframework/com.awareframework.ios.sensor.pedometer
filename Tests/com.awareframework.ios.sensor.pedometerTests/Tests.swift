import CoreMotion
import XCTest
@testable import com_awareframework_ios_sensor_pedometer
import com_awareframework_ios_core

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testObserver(){
        
        #if targetEnvironment(simulator)
        print("This test requires a real device.")
        
        #else
        
        class Observer:PedometerObserver{
            weak var pedometerExpectation: XCTestExpectation?
            func onPedometerChanged(data: PedometerData) {
                print(#function)
                self.pedometerExpectation?.fulfill()
            }
        }
        
        let pedometerObserverExpect = expectation(description: "Pedometer observer")
        let observer = Observer()
        observer.pedometerExpectation = pedometerObserverExpect
        let sensor = PedometerSensor.init(PedometerSensor.Config().apply{ config in
            config.sensorObserver = observer
        })
        
        if let engine = sensor.dbEngine {
            engine.removeAll(PedometerData.self)
        }
        
        sensor.setLastUpdateDateTime(Date().addingTimeInterval(-1*60*60))
        sensor.start()
        
        wait(for: [pedometerObserverExpect], timeout: 10)
        sensor.stop()
        
        #endif
    }
    
    func testControllers() {
        let sensor = PedometerSensor(PedometerSensor.Config().apply{config in
        })
        
        /// test set label action ///
        let expectSetLabel = expectation(description: "set label")
        let newLabel = "hello"
        let labelObserver = NotificationCenter.default.addObserver(forName: .actionAwarePedometerSetLabel, object: nil, queue: .main) { (notification) in
            let dict = notification.userInfo;
            if let d = dict as? Dictionary<String,String>{
                XCTAssertEqual(d[PedometerSensor.EXTRA_LABEL], newLabel)
            }else{
                XCTFail()
            }
            expectSetLabel.fulfill()
        }
        sensor.set(label:newLabel)
        sensor.setLastUpdateDateTime(Date().addingTimeInterval(-1*60*60))
        
        wait(for: [expectSetLabel], timeout: 5)
        NotificationCenter.default.removeObserver(labelObserver)
        
        /// test sync action ////
        let expectSync = expectation(description: "sync")
        let syncObserver = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwarePedometerSync , object: nil, queue: .main) { (notification) in
            expectSync.fulfill()
            print("sync")
        }
        sensor.sync()
        wait(for: [expectSync], timeout: 5)
        NotificationCenter.default.removeObserver(syncObserver)
        
        
        #if targetEnvironment(simulator)
        print("This test requires a real device.")
        
        #else
        
        //// test start action ////
        let expectStart = expectation(description: "start")
        let observer = NotificationCenter.default.addObserver(forName: .actionAwarePedometerStart,
                                                              object: nil,
                                                              queue: .main) { (notification) in
                                                                expectStart.fulfill()
                                                                print("start")
        }
        sensor.start()
        wait(for: [expectStart], timeout: 5)
        NotificationCenter.default.removeObserver(observer)
        
        
        /// test stop action ////
        let expectStop = expectation(description: "stop")
        let stopObserver = NotificationCenter.default.addObserver(forName: .actionAwarePedometerStop, object: nil, queue: .main) { (notification) in
            expectStop.fulfill()
            print("stop")
        }
        sensor.stop()
        wait(for: [expectStop], timeout: 5)
        NotificationCenter.default.removeObserver(stopObserver)
        
        #endif
    }
    
    func testConfig(){
        let sampleIntervalSeconds = 20
        let config:Dictionary<String,Any> = ["sampleIntervalSeconds":sampleIntervalSeconds]
        
        // default
        var sensor = PedometerSensor()
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, 600)
        
        // apply
        sensor = PedometerSensor.init(PedometerSensor.Config().apply{config in
            config.sampleIntervalSeconds = sampleIntervalSeconds
        })
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, sampleIntervalSeconds)
        
        // init with dictionary
        sensor = PedometerSensor.init(PedometerSensor.Config(config))
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, sampleIntervalSeconds)
        
        // set
        sensor = PedometerSensor.init()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, sampleIntervalSeconds)
        
        sensor.CONFIG.sampleIntervalSeconds = -10
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, sampleIntervalSeconds)
    }
    
    func testPedometerData(){
        let dict = PedometerData().toDictionary()
        XCTAssertEqual(dict["startDate"] as? Int64, 0)
        XCTAssertEqual(dict["endDate"]   as? Int64, 0)
        XCTAssertEqual(dict["frequencySpeed"] as? Double, 0)
        XCTAssertEqual(dict["numberOfSteps"] as? Int, 0)
        XCTAssertEqual(dict["distance"] as? Double, 0)
        XCTAssertEqual(dict["currentPace"] as? Double, 0)
        XCTAssertEqual(dict["currentCadence"] as? Double, 0)
        XCTAssertEqual(dict["floorsAscended"] as? Int, 0)
        XCTAssertEqual(dict["floorsDescended"] as? Int, 0)
        XCTAssertEqual(dict["averageActivePace"] as? Double, 0)
    }

    func testHistoryCursorPreservesBothOccurrencesOfRepeatedHour() throws {
        let defaults = UserDefaults.standard
        let key = PedometerSensor.KEY_LAST_UPDATE_DATETIME
        let previous = defaults.object(forKey: key)
        defer { defaults.set(previous, forKey: key) }

        let sensor = PedometerSensor(PedometerSensor.Config().apply { $0.dbType = .none })
        let iso = ISO8601DateFormatter()
        // Both instants are 01:00:10 in Los Angeles, on opposite sides of the fall-back transition.
        let first = try XCTUnwrap(iso.date(from: "2026-11-01T08:00:10Z"))
        let second = first.addingTimeInterval(3600)

        sensor.setLastUpdateDateTime(first)
        XCTAssertEqual(sensor.getLastUpdateDateTime(), first)
        sensor.setLastUpdateDateTime(second)
        XCTAssertEqual(sensor.getLastUpdateDateTime(), second)
    }

    func testHistoryWindowAdvancesWithSubMinuteInterval() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_100)
        let cursor = now.addingTimeInterval(-20)
        let first = try XCTUnwrap(PedometerSensor.historyWindow(after: cursor, through: now, interval: 10))
        let second = try XCTUnwrap(PedometerSensor.historyWindow(after: first.end, through: now, interval: 10))
        XCTAssertEqual(first.start, cursor)
        XCTAssertEqual(second.start, cursor.addingTimeInterval(10))
        XCTAssertEqual(second.end, now)
        XCTAssertNil(PedometerSensor.historyWindow(after: second.end, through: now, interval: 10))
    }

    func testHistoryWindowClampsExpiredCursorToAvailableHistory() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_100)
        let cursor = now.addingTimeInterval(-8 * 24 * 60 * 60)
        let window = try XCTUnwrap(PedometerSensor.historyWindow(after: cursor, through: now, interval: 60))
        XCTAssertEqual(window.start, now.addingTimeInterval(-7 * 24 * 60 * 60))
        XCTAssertEqual(window.duration, 60)
    }

    @MainActor
    func testRestartIgnoresOldCallbackAndKeepsNewQueryInFlight() async {
        final class StubPedometer: CMPedometer {
            private var callback: CMPedometerHandler?
            private(set) var queryCount = 0

            override func queryPedometerData(from start: Date, to end: Date, withHandler handler: @escaping CMPedometerHandler) {
                queryCount += 1
                callback = handler
            }

            func returnNoData() {
                let handler = callback
                callback = nil
                handler?(nil, nil)
            }
        }

        let defaults = UserDefaults.standard
        let key = PedometerSensor.KEY_LAST_UPDATE_DATETIME
        let previous = defaults.object(forKey: key)
        defer { defaults.set(previous, forKey: key) }

        let oldManager = StubPedometer()
        let newManager = StubPedometer()
        var managers: [CMPedometer] = [oldManager, newManager]
        let config = PedometerSensor.Config().apply {
            $0.dbType = .none
            $0.sampleIntervalSeconds = 60
        }
        let sensor = PedometerSensor(config, makePedometer: {
            managers.isEmpty ? nil : managers.removeFirst()
        })
        defer { sensor.stop() }
        let cursor = Date().addingTimeInterval(-120)
        sensor.setLastUpdateDateTime(cursor)

        sensor.start()
        sensor.getPedometerData()
        XCTAssertEqual(oldManager.queryCount, 1)

        sensor.stop()
        sensor.getPedometerData()
        XCTAssertEqual(oldManager.queryCount, 1)
        sensor.start()
        XCTAssertEqual(newManager.queryCount, 1)

        oldManager.returnNoData()
        await drainPendingCallback()
        sensor.getPedometerData()
        XCTAssertEqual(newManager.queryCount, 1)

        newManager.returnNoData()
        await drainPendingCallback()
        XCTAssertEqual(sensor.getLastUpdateDateTime(), cursor)
        sensor.getPedometerData()
        XCTAssertEqual(newManager.queryCount, 2)
    }

    /// One tick catches up to now, however many windows are behind (there was a limit of 60).
    @MainActor
    func testOneTickCatchesUpBeyondSixtyWindows() async throws {
        final class StepData: CMPedometerData {
            override var numberOfSteps: NSNumber { 1 }
        }
        final class ImmediatePedometer: CMPedometer {
            private(set) var queryCount = 0
            override func queryPedometerData(from start: Date, to end: Date, withHandler handler: @escaping CMPedometerHandler) {
                queryCount += 1
                DispatchQueue.global().async { handler(StepData(), nil) }
            }
        }

        let defaults = UserDefaults.standard
        let key = PedometerSensor.KEY_LAST_UPDATE_DATETIME
        let previous = defaults.object(forKey: key)
        defer { defaults.set(previous, forKey: key) }

        let manager = ImmediatePedometer()
        let config = PedometerSensor.Config().apply {
            $0.dbType = .none
            $0.sampleIntervalSeconds = 60
        }
        let sensor = PedometerSensor(config, makePedometer: { manager })
        defer { sensor.stop() }
        let behind = 180
        let cursor = Date().addingTimeInterval(-Double(behind * 60) - 30)
        sensor.setLastUpdateDateTime(cursor)

        sensor.start()  // fires the first tick
        // Wait for the last window to be finished (its cursor update), not only queried
        let target = cursor.addingTimeInterval(Double(behind * 60))
        let deadline = Date().addingTimeInterval(10)
        while (sensor.getLastUpdateDateTime() ?? cursor) < target, Date() < deadline {
            await drainPendingCallback()
        }

        XCTAssertEqual(manager.queryCount, behind)
        let advanced = try XCTUnwrap(sensor.getLastUpdateDateTime())
        XCTAssertEqual(advanced.timeIntervalSince(cursor), Double(behind * 60), accuracy: 0.001)
    }

    @MainActor
    private func drainPendingCallback() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
    
    func testSyncModule(){
        #if targetEnvironment(simulator)
        
        print("This test requires a real Pedometer.")
        
        #else
        // success //
        let sensor = PedometerSensor.init(PedometerSensor.Config().apply{ config in
            config.debug = true
            config.dbHost = "node.awareframework.com:1001"
            config.dbPath = "sync_db"
        })
        let successExpectation = XCTestExpectation(description: "success sync")
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwarePedometerSyncCompletion,
                                                              object: sensor, queue: .main) { (notification) in
                                                                if let userInfo = notification.userInfo{
                                                                    if let status = userInfo["status"] as? Bool {
                                                                        if status == true {
                                                                            successExpectation.fulfill()
                                                                        }
                                                                    }
                                                                }
        }
        sensor.sync(force: true)
        wait(for: [successExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(observer)
        
        ////////////////////////////////////
        
        // failure //
        let sensor2 = PedometerSensor.init(PedometerSensor.Config().apply{ config in
            config.debug = true
            config.dbHost = "node.awareframework.com.com" // wrong url
            config.dbPath = "sync_db"
        })
        let failureExpectation = XCTestExpectation(description: "failure sync")
        let failureObserver = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwarePedometerSyncCompletion,
                                                                     object: sensor2, queue: .main) { (notification) in
                                                                        if let userInfo = notification.userInfo{
                                                                            if let status = userInfo["status"] as? Bool {
                                                                                if status == false {
                                                                                    failureExpectation.fulfill()
                                                                                }
                                                                            }
                                                                        }
        }
        sensor2.sync(force: true)
        wait(for: [failureExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(failureObserver)
        
        #endif
    }

    /// The sensor creates its own table: rows can be saved and read back for sync without the app
    /// creating the table (it used to be missing, so every save failed and nothing was synced)
    func testSensorCreatesItsTable() {
        let sensor = PedometerSensor(PedometerSensor.Config().apply { config in
            config.dbPath = "create_table_test_\(UUID().uuidString)"
        })
        XCTAssertEqual(sensor.CONFIG.dbTableName, PedometerData.databaseTableName)
        guard let engine = sensor.dbEngine else { return XCTFail("no engine") }
        let saved = expectation(description: "saved")
        engine.save([PedometerData()]) { error in
            XCTAssertNil(error)
            saved.fulfill()
        }
        wait(for: [saved], timeout: 5)
        XCTAssertEqual(engine.count(filter: nil), 1)
        XCTAssertEqual(engine.fetch(filter: nil, limit: nil)?.count, 1, "rows can be read for sync")
    }
}
