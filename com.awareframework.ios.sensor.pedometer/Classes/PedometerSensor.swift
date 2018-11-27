//
//  PedometerSensor.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/11/12.
//

import UIKit
import SwiftyJSON
import CoreMotion
import com_awareframework_ios_sensor_core

public class PedometerSensor: AwareSensor {
    
    public static let TAG = "AWARE::Pedometer"
    public var CONFIG:PedometerSensor.Config = Config()
    
    var pedometer:CMPedometer? = nil
    var timer:Timer? = nil
    var inRecoveryLoop = false
    
    public class Config:SensorConfig {
        public var interval:Int = 10 // min
        public var sensorObserver:PedometerObserver?
        
        public override init() {
            super.init()
            dbPath = "aware_pedometer"
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            if let interval = config["interval"] as? Int{
                self.interval = interval
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
    
    public init(_ config:PedometerSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
    }
    
    override public func start() {
        if !CMPedometer.isStepCountingAvailable(){
            print(PedometerSensor.TAG, "Step Counting is not available.")
        }
        
        if !CMPedometer.isPaceAvailable(){
            print(PedometerSensor.TAG, "Pace is not available.")
        }
        
        if !CMPedometer.isCadenceAvailable(){
            print(PedometerSensor.TAG, "Cadence is not available.")
        }
        
        if !CMPedometer.isDistanceAvailable(){
            print(PedometerSensor.TAG, "Distance is not available.")
        }
        
        if !CMPedometer.isFloorCountingAvailable(){
            print(PedometerSensor.TAG, "Floor Counting is not available.")
        }
        
        if !CMPedometer.isPedometerEventTrackingAvailable(){
            print(PedometerSensor.TAG, "Pedometer Event Tracking is not available.")
        }
        
        if pedometer == nil {
            pedometer = CMPedometer()
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: Double(self.CONFIG.interval), repeats: true, block: { timer in
                    if !self.inRecoveryLoop {
                        self.getPedometerData()
                    }else{
                        if self.CONFIG.debug { print(PedometerSensor.TAG, "skip: a recovery roop is running") }
                    }
                })
                self.notificationCenter.post(name: .actionAwarePedometerStart , object: nil)
            }
        }
    }
    
    override public func stop() {
        if let uwTimer = timer {
            uwTimer.invalidate()
            timer = nil
            self.notificationCenter.post(name: .actionAwarePedometerStop , object: nil)
        }
    }
    
    override public func sync(force: Bool = false) {
        if let engine = self.dbEngine {
            engine.startSync(PedometerData.TABLE_NAME, DbSyncConfig().apply{config in
                config.debug = self.CONFIG.debug
            })
            self.notificationCenter.post(name: .actionAwarePedometerSync , object: nil)
        }
    }
    
    ////////////////////////
    public func getPedometerData() {
        if let uwPedometer = pedometer, let fromDate = self.getLastUpdateDateTime(){
            let now = Date()
            let diffBetweemNowAndFromDate = now.minutes(from: fromDate)
            // if self.CONFIG.debug{ print(PedometerSensor.TAG, "diff: \(diffBetweemNowAndFromDate) min") }
            if diffBetweemNowAndFromDate > Int(CONFIG.interval) {
                let toDate = fromDate.addingTimeInterval( 60.0 * Double(self.CONFIG.interval) )
                uwPedometer.queryPedometerData(from: fromDate, to: toDate) { (pedometerData, error) in
                    
                    // save pedometer data
                    if let pedoData = pedometerData {
                        let data = PedometerData()
                        data.startDate = Int64(fromDate.timeIntervalSince1970 * 1000)
                        data.endDate   = Int64(toDate.timeIntervalSince1970   * 1000)
                        data.numberOfSteps = pedoData.numberOfSteps.intValue
                        
                        if let currentCadence = pedoData.currentCadence{
                            data.currentCadence = currentCadence.doubleValue
                        }
                        if let currentPace = pedoData.currentPace{
                            data.currentPace = currentPace.doubleValue
                        }
                        if let distance = pedoData.distance{
                            data.distance = distance.doubleValue
                        }
                        if let averageActivePace = pedoData.averageActivePace{
                            data.averageActivePace = averageActivePace.doubleValue
                        }
                        if let floorsAscended = pedoData.floorsAscended{
                            data.floorsAscended = floorsAscended.intValue
                        }
                        if let floorsDescended = pedoData.floorsDescended {
                            data.floorsDescended = floorsDescended.intValue
                        }
                        
                        if let engine = self.dbEngine {
                            engine.save(data, PedometerData.TABLE_NAME)
                        }
                        
                        if self.CONFIG.debug {
                            print(PedometerSensor.TAG, "\(fromDate) - \(toDate) : \(pedoData.numberOfSteps.intValue)" )
                        }
                        
                        if let observer = self.CONFIG.sensorObserver {
                            observer.onPedometerChanged(data: data)
                        }
                        
                        self.notificationCenter.post(name: .actionAwarePedometer , object: nil)
                    }
                    
                    self.setLastUpdateDateTime(toDate)
                    let diffBetweenNowAndToDate = now.minutes(from: toDate)
                    if diffBetweenNowAndToDate > Int(self.CONFIG.interval){
                        self.inRecoveryLoop = true;
                        self.getPedometerData()
                    }else{
                        self.inRecoveryLoop = false;
                    }
                }
            }else{
                self.inRecoveryLoop = false;
            }
        }
    }
}

public protocol PedometerObserver {
    func onPedometerChanged(data:PedometerData)
}

extension Date {
    /// Returns the amount of minutes from another date
    func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
}

extension Notification.Name {
    public static let actionAwarePedometer = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER)
    public static let actionAwarePedometerStart    = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_START)
    public static let actionAwarePedometerStop     = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_STOP)
    public static let actionAwarePedometerSync     = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_SYNC)
    public static let actionAwarePedometerSetLabel = Notification.Name(PedometerSensor.ACTION_AWARE_PEDOMETER_SET_LABEL)
}

extension PedometerSensor {
    public static let ACTION_AWARE_PEDOMETER       = "ACTION_AWARE_PEDOMETER"
    public static let ACTION_AWARE_PEDOMETER_START = "action.aware.pedometer.SENSOR_START"
    public static let ACTION_AWARE_PEDOMETER_STOP  = "action.aware.pedometer.SENSOR_STOP"
    public static let ACTION_AWARE_PEDOMETER_SET_LABEL = "action.aware.pedometer.SET_LABEL"
    public static let ACTION_AWARE_PEDOMETER_SYNC  = "action.aware.pedometer.SENSOR_SYNC"
}

extension PedometerSensor {
    
    public static let KEY_LAST_UPDATE_DATETIME = "com.aware.ios.sensor.pedometer.key.last_update_datetime";
    
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
        }else{
            let date = Date()
            let calendar = Calendar.current
            let year  = calendar.component(.year,   from: date)
            let month = calendar.component(.month,  from: date)
            let day   = calendar.component(.day,    from: date)
            let hour  = calendar.component(.hour,    from: date)
            let newDate = calendar.date(from: DateComponents(year:year, month:month, day:day, hour:hour, minute:0))
            if let uwDate = newDate {
                self.setLastUpdateDateTime(uwDate)
                return uwDate
            }else{
                if self.CONFIG.debug { print(PedometerSensor.TAG, "[Error] KEY_LAST_UPDATE_DATETIME is null." ) }
                return nil
            }
        }
    }
    
    public func setLastUpdateDateTime(_ datetime:Date){
        if let newDateTime = self.getFomattedDateTime(datetime) {
            UserDefaults.standard.set(newDateTime, forKey:PedometerSensor.KEY_LAST_UPDATE_DATETIME)
            UserDefaults.standard.synchronize()
            return
        }
        if self.CONFIG.debug { print(PedometerSensor.TAG, "[Error] Date Time is null.") }
    }
    
}
