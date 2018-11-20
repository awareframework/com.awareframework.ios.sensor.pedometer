# Aware Pedometer

[![CI Status](https://img.shields.io/travis/tetujin/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://travis-ci.org/tetujin/com.awareframework.ios.sensor.pedometer)
[![Version](https://img.shields.io/cocoapods/v/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.pedometer)
[![License](https://img.shields.io/cocoapods/l/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.pedometer)
[![Platform](https://img.shields.io/cocoapods/p/com.awareframework.ios.sensor.pedometer.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.pedometer)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

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

Yuuki Nishiyama, tetujin@ht.sfc.keio.ac.jp

## License
Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
