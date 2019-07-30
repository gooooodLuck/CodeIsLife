

import UIKit
import Alamofire
import SwiftSoup

let DOMAIN_NAME_YQZ = "http://www.wojianwang.cn"

let HEADER_API_YQZ: HTTPHeaders = [
    "Host": "www.wojianwang.cn",
    "Accept": "*/*",
    "User-Agent": "yqz/1.0.0 (iPhone; iOS 12.3.1; Scale/2.00)",
    "Content-Type": "application/x-www-form-urlencoded",
    "Accept-Encoding": "gzip, deflate",
    "Accept-Language": "zh-Hans-CN;q=1, en-US;q=0.9"
]

let HEADER_H5_YQZ: HTTPHeaders = [
    "Host": "www.wojianwang.cn",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1",
    "Accept-Encoding": "gzip, deflate",
    "Accept-Language": "zh-cn",
    "Referer": "http://www.wojianwang.cn/h5/taskaso/index/"
]

class PlatYqz: Plat {
    var logUI:UITextView!
    var devInfo = Dictionary<String, String>()
    var cancelledTasks = Array<String>()
    var runningTasks = Dictionary<String, Dictionary<String, Any>>()
    var taskQueue = DispatchQueue.init(label: "yqz.main")
    
    override init() {
    }
    
    init(dict: [String: String], logUI:UITextView) {
        self.devInfo = dict
        self.logUI = logUI
    }
    
    public func run() {
        var token = ""
        while (true) {
            let sec = super.sleep4Next(plat: "yqz")
            print("yqz 主线程睡眠\(sec)")
            sleep(UInt32(sec))

            // -------------------------
            // 1.login后对token进行定时心跳
            // -------------------------
            if token.count < 1 {
                token = self.login()
                if token.count < 1 {
                    continue
                } else {
                    let timerExist = TickTimer.shared.isExistTimer(WithTimerName: "YQZTokenHeart")
                    if timerExist {
                        TickTimer.shared.cancleTimer(WithTimerName: "YQZTokenHeart")
                    }

                    TickTimer.shared.scheduledDispatchTimer(WithTimerName: "YQZTokenHeart", timeInterval: 120, queue: .main, repeats: true) {
                        self.heart(token: token)
                    }
                }
            }

            // -------------------------
            // 2.获取列表
            // -------------------------
            let ret = self.getTask(token: token)
            if !ret {
                continue
            }
            
            // -------------------------
            // 3.循环列表
            // -------------------------
            for (taskId, _) in self.runningTasks {
                if self.cancelledTasks.contains(taskId) {
                    continue
                }
                
                let applyRet = self.applyTask(token: token, taskId: taskId)
                if !applyRet {
                    continue
                }
                
                let downAppSleep = Int(arc4random() % 10) + 30
                print("yqz 开始下载APP - \(downAppSleep)")
                sleep(UInt32(downAppSleep))
                
                let openRet = self.openApp(token: token, taskId: taskId)
                if !openRet {
                    self.cancenTask(token: token, taskId: taskId)
                    continue
                }
                
                let playAppSleep = Int(arc4random() % 10) + 180
                print("yqz 开始试玩APP - \(playAppSleep)")
                sleep(UInt32(playAppSleep))
                
                let verifyRet = self.verify(token: token, taskId: taskId)
                if !verifyRet {
                    self.cancenTask(token: token, taskId: taskId)
                    continue
                }
            }
        }
    }
    
    func login() -> String {
        let api = DOMAIN_NAME_YQZ + "/api/ios/log/"
        var params = [
            "v": "1.0.0",
            "udid": self.devInfo["udid"],
            "dev": self.devInfo["model"],
            "os": self.devInfo["os"],
            "idfa": self.devInfo["idfa"],
            "t": Date().timeIntStamp
        ]
        let sign = self.getSign(params: params as! Dictionary<String, String>)
        params["s"] = sign
        
        var token = ""
        let loginSemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.post, parameters: params, headers: HEADER_API_YQZ)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respLogin) in
                    switch respLogin.result {
                    case .success:
                        let respLoginStr = String(data: respLogin.data!, encoding: .utf8)
                        do {
                            let respLoginDict = try JSONSerialization.jsonObject(with: (respLoginStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                            if respLoginDict.keys.contains("data") {
                                let data = respLoginDict["data"] as! Dictionary<String, AnyObject>
                                if data.keys.contains("token") {
                                    token = data["token"]! as! String
                                    print("yzq 请求login success:\(token)")
                                } else {
                                    print("yzq 请求login失败: \(String(describing: respLoginStr))")
                                }
                            } else {
                                print("yzq 请求login失败: \(String(describing: respLoginStr))")
                            }
                        } catch let error {
                            print("yzq 请求login异常: \(error)")
                        }
                        break
                    case .failure(_):
                        print("yzq 请求login失败")
                        break
                    }
                    loginSemp.signal()
            })
        }
        _ = loginSemp.wait(timeout: .now() + .seconds(15))
        return token
    }
    
    func heart(token: String) -> Void {
        let api = DOMAIN_NAME_YQZ + "/api/ios/heart/"
        var params = [
            "v": "1.0.0",
            "token": token,
            "t": Date().timeIntStamp,
            "udid": self.devInfo["udid"],
            "dev": self.devInfo["model"],
            "os": self.devInfo["os"],
            "idfa": self.devInfo["idfa"]
        ]
        let sign = self.getSign(params: params as! Dictionary<String, String>)
        params["s"] = sign
        
        AF.request(api, method:.post, parameters: params, headers: HEADER_API_YQZ)
            .validate(statusCode: 200..<300)
            .responseString(completionHandler: { (respHeart) in
            })
    }
    
    func getTask(token: String) -> Bool {
        let api = DOMAIN_NAME_YQZ + "/h5/taskaso/list/"
        var listRet = false
        var H5Cookie = HEADER_H5_YQZ
        H5Cookie["Cookie"] = "yunyu_access=\(token)"
        
        self.runningTasks.removeAll()
        var tmpTasks = Dictionary<String, Dictionary<String, Any>>()
        let listSemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.get, headers: H5Cookie)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respList) in
                    switch respList.result {
                    case .success:
                        let respListStr = String(data: respList.data!, encoding: .utf8)
                        do {
                            let doc:Document = try SwiftSoup.parse(respListStr!)
                            guard let taskList: Elements = try doc.select("div[onclick^=\"getTask(\"]") else {
                                return
                            }
                            listRet = true
                            
                            if taskList.count < 1 {
                                print("yqz 响应任务数：0")
                                break
                            }
                            
                            for eachTask in taskList {
                                let clickValue = try eachTask.attr("onclick")
                                let bI = clickValue.index(clickValue.startIndex, offsetBy: 8)
                                let eI = clickValue.index(before: clickValue.endIndex)
                                let taskId = String(clickValue[bI..<eI])
                                tmpTasks[taskId] = [:]
                            }
                            print("yqz 响应任务数：\(taskList.count)")
                        } catch let error {
                            print("yzq 解析list页面失败: \(error) - \(String(describing: respListStr))")
                        }
                        break
                    case .failure(_):
                        print("yzq 请求list失败")
                        break
                    }
                    listSemp.signal()
                })
        }
        _ = listSemp.wait(timeout: .now() + .seconds(15))
        self.runningTasks = super.randomTasks(tasks: tmpTasks)
        return listRet
    }
    
    func applyTask(token: String, taskId: String) -> Bool {
        let api = DOMAIN_NAME_YQZ + "/h5/taskaso/ask/"
        var applyRet = false
        var H5Cookie = HEADER_H5_YQZ
        H5Cookie["Cookie"] = "yunyu_access=\(token)"
        let params = ["taskId": taskId]
        
        let applySemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.get, parameters: params, headers: H5Cookie)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respApply) in
                    switch respApply.result {
                    case .success:
                        let respApplyStr = String(data: respApply.data!, encoding: .utf8)
                        do {
                            let respApplyDict = try JSONSerialization.jsonObject(with: (respApplyStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                            if respApplyDict.keys.contains("code") {
                                guard let code = respApplyDict["code"] as? Int else {
                                    print("yzq 请求apply失败: \(String(describing: respApplyStr))")
                                    return
                                }
                                
                                if String(code) == "0" {
                                    applyRet = true
                                    print("yzq 请求apply成功: \(taskId)")
                                } else {
                                    print("yzq 请求apply失败: \(String(describing: respApplyStr))")
                                }
                            } else {
                                print("yzq 请求apply失败: \(String(describing: respApplyStr))")
                            }
                        } catch let error {
                            print("yzq 请求apply异常: \(error) - \(String(describing: respApplyStr))")
                        }
                        break
                    case .failure(_):
                        print("yzq 请求apply失败: \(taskId)")
                        break
                    }
                    applySemp.signal()
                })
        }
        _ = applySemp.wait(timeout: .now() + .seconds(15))
        return applyRet
    }
    
    func openApp(token: String, taskId: String) -> Bool {
        let api = DOMAIN_NAME_YQZ + "/api/ios/open/"
        var params = [
            "v": "1.0.0",
            "udid": self.devInfo["udid"],
            "dev": self.devInfo["model"],
            "os": self.devInfo["os"],
            "idfa": self.devInfo["idfa"],
            "t": Date().timeIntStamp,
            "token": token,
            "task": taskId
        ]
        let sign = self.getSign(params: params as! Dictionary<String, String>)
        params["s"] = sign
        
        var openRet = false
        let openSemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.post, parameters: params, headers: HEADER_API_YQZ)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respOpen) in
                    switch respOpen.result {
                    case .success:
                        let respOpenStr = String(data: respOpen.data!, encoding: .utf8)
                        do {
                            let respOpenDict = try JSONSerialization.jsonObject(with: (respOpenStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                            if respOpenDict.keys.contains("code") {
                                guard let code = respOpenDict["code"] as? Int else {
                                    print("yzq 请求open失败: \(taskId) - \(String(describing: respOpenStr))")
                                    return
                                }
                                
                                if String(code) == "0" {
                                    openRet = true
                                    print("yzq 请求open成功: \(taskId)")
                                } else {
                                    print("yzq 请求open失败: \(taskId) - \(String(describing: respOpenStr))")
                                }
                            } else {
                                print("yzq 请求open失败: \(taskId) - \(String(describing: respOpenStr))")
                            }
                        } catch let error {
                            print("yzq 请求open异常: \(error)")
                        }
                        break
                    case .failure(_):
                        print("yzq 请求open失败")
                        break
                    }
                    openSemp.signal()
                })
        }
        _ = openSemp.wait(timeout: .now() + .seconds(15))
        return openRet
    }
    
    func cancenTask(token: String, taskId: String) -> Bool {
        let api = DOMAIN_NAME_YQZ + "/h5/taskaso/cancel/"
        var cancelRet = false
        var H5Cookie = HEADER_H5_YQZ
        H5Cookie["Cookie"] = "yunyu_access=\(token)"
        let params = ["taskId": taskId]
        
        let cancelSemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.get, parameters: params, headers: H5Cookie)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respCancel) in
                    switch respCancel.result {
                    case .success:
                        let respCancelStr = String(data: respCancel.data!, encoding: .utf8)
                        do {
                            let respCancelDict = try JSONSerialization.jsonObject(with: (respCancelStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                            if respCancelDict.keys.contains("code") {
                                guard let code = respCancelDict["code"] as? Int else {
                                    print("yzq 请求cancel失败: \(taskId) - \(String(describing: respCancelStr))")
                                    return
                                }
                                
                                if String(code) == "0" {
                                    cancelRet = true
                                    print("yzq 请求cancel succes: \(taskId)")
                                } else {
                                    print("yzq 请求cancel失败: \(taskId) - \(String(describing: respCancelStr))")
                                }
                            } else {
                                print("yzq 请求cancel失败: \(taskId) - \(String(describing: respCancelStr))")
                            }
                        } catch let error {
                            print("yzq 请求cancel异常: \(error) - \(String(describing: respCancelStr))")
                        }
                        break
                    case .failure(_):
                        print("yzq 请求cancel失败: \(taskId)")
                        break
                    }
                    cancelSemp.signal()
                })
        }
        _ = cancelSemp.wait(timeout: .now() + .seconds(15))
        self.cancelledTasks.append(taskId)
        return cancelRet
    }
    
    func verify(token: String, taskId: String) -> Bool {
        let api = DOMAIN_NAME_YQZ + "/h5/taskaso/submit/"
        var verifyRet = false
        var H5Cookie = HEADER_H5_YQZ
        H5Cookie["Cookie"] = "yunyu_access=\(token)"
        let params = ["taskId": taskId]
        
        let verifySemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.get, parameters: params, headers: H5Cookie)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respVerify) in
                    switch respVerify.result {
                    case .success:
                        let respVerifyStr = String(data: respVerify.data!, encoding: .utf8)
                        do {
                            let respVerifyDict = try JSONSerialization.jsonObject(with: (respVerifyStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                            if respVerifyDict.keys.contains("code") {
                                guard let code = respVerifyDict["code"] as? Int else {
                                    print("yzq 请求verify失败: \(taskId) - \(String(describing: respVerifyStr))")
                                    return
                                }
                                
                                if String(code) == "0" {
                                    verifyRet = true
                                    print("yzq 请求verify成功: \(taskId)")
                                } else {
                                    print("yzq 请求verify失败: \(taskId) - \(String(describing: respVerifyStr))")
                                }
                            } else {
                                print("yzq 请求verify失败: \(taskId) - \(String(describing: respVerifyStr))")
                            }
                        } catch let error {
                            print("yzq 请求verify异常: \(error) - \(String(describing: respVerifyStr))")
                        }
                        break
                    case .failure(_):
                        print("yzq 请求verify失败: \(taskId)")
                        break
                    }
                    verifySemp.signal()
                })
        }
        _ = verifySemp.wait(timeout: .now() + .seconds(15))
        return verifyRet
    }
    
    func getSign(params: Dictionary<String, String>) -> String {
        let t = Int(params["t"]!)!
        let mod = t % 10
        let salt = String(t).md5()
        let keySortedParams = params.sorted(by: {$0.0 < $1.0})
        var srcStr = ""
        for param in keySortedParams {
            srcStr += "\(param.key)=\(param.value)"
        }
        let prefix = salt.prefix(upTo: salt.index(salt.startIndex, offsetBy: mod))
        let suffix = salt.suffix(salt.count - mod)
        
        return "\(prefix)\(srcStr)\(suffix)".md5()
    }
}
