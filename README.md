# AWARE: Pedometer

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

The Pedometer sensor allows us to manages historic pedometer data which is provided by [CMPedometer](https://developer.apple.com/documentation/coremotion). The pedometer object contains step counts and other information about the distance traveled and the number of floors ascended or descended.

## Requirements
iOS 13 or later

## Installation


You can integrate this framework into your project via Swift Package Manager (SwiftPM).

### SwiftPM
1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `git@github.com:awareframework/com.awareframework.ios.sensor.pedometer.git`

3. Import the package into your target.

4. Add a description of `NSMotionUsageDescription` into `Info.plist`



## Public Functions

### PedometerSensor

+ `init(config:PedometerSensor.Config?)`: Initializes the pedometer sensor with the optional configuration.
+ `start()`: Starts the pedometer sensor with the optional configuration.
+ `stop()`: Stops the service.

### PedometerSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sensorObserver: PedometerObserver`: Callback for live data updates.
+ `sampleIntervalSeconds: Int`: A sampling duration in seconds. (default = `600`)
+ `enabled: Bool`: Sensor is enabled or not. (default = `false`)
+ `debug: Bool`: Enable/disable logging. (default = `false`)
+ `label: String`: Label for the data. (default = `""`)
+ `deviceId: String`: Id of the device that will be associated with the events and the sensor. (default = `""`)
+ `dbEncryptionKey: String?`: Encryption key for the database. (default = `nil`)
+ `dbType: DatabaseType`: Which db engine to use for saving data. (default = `.none`)
+ `dbPath: String`: Path of the database. (default = `"aware_pedometer"`)
+ `dbHost: String?`: Host for syncing the database. (default = `nil`)

## Broadcasts

### Fired Broadcasts

+ `PedometerSensor.ACTION_AWARE_PEDOMETER`: fired when pedometer data is saved to db after the sample interval ends.

### Received Broadcasts

+ `PedometerSensor.ACTION_AWARE_PEDOMETER_START`: received broadcast to start the sensor.
+ `PedometerSensor.ACTION_AWARE_PEDOMETER_STOP`: received broadcast to stop the sensor.
+ `PedometerSensor.ACTION_AWARE_PEDOMETER_SYNC`: received broadcast to send sync attempt to the host.
+ `PedometerSensor.ACTION_AWARE_PEDOMETER_SET_LABEL`: received broadcast to set the data label. Label is expected in the `PedometerSensor.EXTRA_LABEL` field of the intent extras.

## Data Representations

### PedometerSensor Data

Contains the raw sensor data.

| Field             | Type   | Description                                                     |
| ----------------- | ------ | --------------------------------------------------------------- |
| startDate         | Int64  | The start time for the pedometer data by unixtime milliseconds since 1970 |
| endDate           | Int64  | The end time for the pedometer data by unixtime milliseconds since 1970   |
| frequencySpeed    | Double | The frequency speed of the user's steps                         |
| numberOfSteps     | Int    | The number of steps taken by the user.                          |
| distance          | Double | The estimated distance (in meters) traveled by the user.        |
| currentPace       | Double | The current pace of the user, measured in seconds per meter.    |
| currentCadence    | Double | The rate at which steps are taken, measured in steps per second. |
| floorsAscended    | Int    | The approximate number of floors ascended by walking.           |
| floorsDescended   | Int    | The approximate number of floors descended by walking.          |
| averageActivePace | Double | The average pace of the user, measured in seconds per meter.    |
| label             | String | Customizable label. Useful for data calibration or traceability |
| deviceId          | String | AWARE device UUID                                               |
| timestamp         | Int64  | Unixtime milliseconds since 1970                                |
| timezone          | Int    | Raw timezone offset of the device                               |
| os                | String | Operating system of the device (e.g., ios)                      |
| jsonVersion       | Int    | JSON schema version                                             |

## Example Usage
```swift
var pedometer = PedometerSensor.init(PedometerSensor.Config().apply { config in
    config.debug  = true
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

Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## Related Links

- [ Apple | CoreMotion ](https://developer.apple.com/documentation/coremotion)
- [ Apple | CMPedometer ](https://developer.apple.com/documentation/coremotion/cmpedometer)
- [ Apple | CMPedometerData ](https://developer.apple.com/documentation/coremotion/cmpedometerdata)

## License
Copyright (c) 2025 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
