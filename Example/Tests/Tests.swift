import XCTest
import com_awareframework_ios_sensor_pedometer

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
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
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
