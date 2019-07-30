

import UIKit

class Plat: NSObject {
    func sleep4Next(plat: String) -> Int {
        var sleepSeconds = 3600
        let calendar = Calendar.current
        let dateComponets = calendar.dateComponents([Calendar.Component.hour, Calendar.Component.minute], from: Date())
        switch dateComponets.hour! {
        case 10...12:
            sleepSeconds = (10 - dateComponets.minute! % 10) * 60
            break
        case 13...22:
            sleepSeconds = (5 - dateComponets.minute! % 5) * 60
            break
        default:
            break
        }

        if sleepSeconds < 1 {
            return 1
        }
        return sleepSeconds
    }
    
    func randomTasks(tasks: Dictionary<String, Dictionary<String, Any>>) -> Dictionary<String, Dictionary<String, Any>> {
        var respDict = Dictionary<String, Dictionary<String, Any>>()
        var taskIds = Array(tasks.keys)
        while taskIds.count != 0 {
            let i = arc4random_uniform(UInt32(taskIds.count))
            respDict[ taskIds[Int(i)] ] = tasks[ taskIds[Int(i)] ]
            taskIds.remove(at: Int(i))
        }
        
        return respDict
    }
}
