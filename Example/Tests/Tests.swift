import XCTest
import RealmSwift
import com_awareframework_ios_sensor_pedometer
import com_awareframework_ios_sensor_core

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = self.name
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
            config.dbType = .REALM
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
            config.dbType = .REALM
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
        let interval = 20
        let config:Dictionary<String,Any> = ["interval":interval]
        
        // default
        var sensor = PedometerSensor()
        XCTAssertEqual(sensor.CONFIG.interval, 10)
        
        // apply
        sensor = PedometerSensor.init(PedometerSensor.Config().apply{config in
            config.interval = interval
        })
        XCTAssertEqual(sensor.CONFIG.interval, interval)
        
        // init with dictionary
        sensor = PedometerSensor.init(PedometerSensor.Config(config))
        XCTAssertEqual(sensor.CONFIG.interval, interval)
        
        // set
        sensor = PedometerSensor.init()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(sensor.CONFIG.interval, interval)
        
        sensor.CONFIG.interval = -10
        XCTAssertEqual(sensor.CONFIG.interval, interval)
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
    
    func testSyncModule(){
        #if targetEnvironment(simulator)
        
        print("This test requires a real Pedometer.")
        
        #else
        // success //
        let sensor = PedometerSensor.init(PedometerSensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.dbHost = "node.awareframework.com:1001"
            config.dbPath = "sync_db"
        })
        if let engine = sensor.dbEngine as? RealmEngine {
            engine.removeAll(PedometerData.self)
            for _ in 0..<100 {
                engine.save(PedometerData())
            }
        }
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
            config.dbType = .REALM
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
        if let engine = sensor2.dbEngine as? RealmEngine {
            engine.removeAll(PedometerData.self)
            for _ in 0..<100 {
                engine.save(PedometerData())
            }
        }
        sensor2.sync(force: true)
        wait(for: [failureExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(failureObserver)
        
        #endif
    }
}
