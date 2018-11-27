# AWARE: Pedometer

[![CI Status](https://img.shields.io/travis/awareframework/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://travis-ci.org/awareframework/com.awareframework.ios.sensor.pedometer)
[![Version](https://img.shields.io/cocoapods/v/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.pedometer)
[![License](https://img.shields.io/cocoapods/l/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.pedometer)
[![Platform](https://img.shields.io/cocoapods/p/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.pedometer)

The Pedometer sensor allows us to manages historic pedometer data which is provided by [CMPedometer](https://developer.apple.com/documentation/coremotion). The pedometer object contains step counts and other information about the distance traveled and the number of floors ascended or descended. 

## Requirements
iOS 10 or later

## Installation

com.awareframework.ios.sensor.pedometer is available through [CocoaPods](https://cocoapods.org). 

1. To install it, simply add the following line to your Podfile:
```ruby
pod 'com.awareframework.ios.sensor.pedometer'
```

2. Import com.awareframework.ios.sensor.pedometer library into your source code.
```swift
import com_awareframework_ios_sensor_pedometer
```

3. Add a description of `NSMotionUsageDescription` into Info.plist

## Public functions

### PedometerSensor

+ `init(config:PedometerSensor.Config?)` : Initializes the pedometer sensor with the optional configuration.
+ `start()`: Starts the pedometer sensor with the optional configuration.
+ `stop()`: Stops the service.

### PedometerSensor.Config

Class to hold the configuration of the sensor.

#### Fields
+ `sensorObserver: PedometerObserver`: Callback for live data updates.
+ `interval : Int`: A sampling duration (minute) of a sample. (default = 10)
+ `enabled: Boolean` Sensor is enabled or not. (default = `false`)
+ `debug: Boolean` enable/disable logging to Xcode console. (default = `false`)
+ `label: String` Label for the data. (default = "")
+ `deviceId: String` Id of the device that will be associated with the events and the sensor. (default = "")
+ `dbEncryptionKey` Encryption key for the database. (default = `null`)
+ `dbType: Engine` Which db engine to use for saving data. (default = `Engine.DatabaseType.NONE`)
+ `dbPath: String` Path of the database. (default = "aware_pedometer")
+ `dbHost: String` Host for syncing the database. (default = `null`)

## Broadcasts

### Fired Broadcasts

+ `PedometerSensor.ACTION_AWARE_PEDOMETER` fired when pedometer saved data to db after the period ends.

### Received Broadcasts

+ `PedometerSensor.ACTION_AWARE_PEDOMETER_START`: received broadcast to start the sensor.
+ `PedometerSensor.ACTION_AWARE_PEDOMETER_STOP`: received broadcast to stop the sensor.
+ `PedometerSensor.ACTION_AWARE_PEDOMETER_SYNC`: received broadcast to send sync attempt to the host.
+ `PedometerSensor.ACTION_AWARE_PEDOMETER_SET_LABEL`: received broadcast to set the data label. Label is expected in the `PedometerSensor.EXTRA_LABEL` field of the intent extras.

## Data Representations

### PedometerSensor Data

Contains the raw sensor data.

| Field     | Type   | Description                                                     |
| --------- | ------ | --------------------------------------------------------------- |
| startDate      | Int64  | The start time for the pedometer data by unixtime milliseconds since 1970  |
| endDate        | Int64  | The end time for the pedometer data by unixtime milliseconds since 1970    |
| numberOfSteps  | Int64  |      The number of steps taken by the user. |
| distance       | Double  |    The estimated distance (in meters) traveled by the user. |
| currentPace    | Double  | The current pace of the user, measured in seconds per meter. |
| currentCadence | Double  | The rate at which steps are taken, measured in steps per second.  |
| floorsAscended | Double  |The approximate number of floors ascended by walking.|
| floorsDescended   | Double  |The approximate number of floors descended by walking.|
| averageActivePace | Double  |The average pace of the user, measured in seconds per meter.
| label     | String | Customizable label. Useful for data calibration or traceability |
| deviceId  | String | AWARE device UUID                                               |
| label     | String | Customizable label. Useful for data calibration or traceability |
| timestamp | Int64   | Unixtime milliseconds since 1970                                |
| timezone  | Int    | Raw timezone offset of the device                          |
| os        | String | Operating system of the device (e.g., ios)                    |

## Example usage
```swift
var pedometer = PedometerSensor.init(PedometerSensor.Config().apply{config in
    config.debug  = true
    config.dbType = .REALM
    config.sensorObserver = Observer()
})
pedometer.start()
```

```swift
class Observer:PedometerObserver {
    func onPedometerChanged(data:PedometerData){
        // Your code here..
    }
}
```

## Author

Yuuki Nishiyama, yuuki.nishiyama@oulu.fi

## Related Links

- [ Apple | CoreMotion ](https://developer.apple.com/documentation/coremotion)
- [ Apple | CMPedometer ](https://developer.apple.com/documentation/coremotion/cmpedometer)
- [ Apple | CMPedometerData ](https://developer.apple.com/documentation/coremotion/cmpedometerdata)

## License
Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
