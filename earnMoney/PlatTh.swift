

import UIKit
import SwiftyRSA
import Alamofire
import CryptoSwift
import SwiftSoup


let DOMAIN_NAME_TH = "https://www.touhaoplayer.cn"

let HEADER_API_TH: HTTPHeaders = [
    "Accept": "*/*",
    "Accept-Encoding": "br, gzip, deflate",
    "User-Agent": "thsw/1.2.1 (iPhone; iOS 12.3.1; Scale/2.00)",
    "Accept-Language": "zh-Hans-CN;q=1, en-US;q=0.9"
]

let HEADER_H5_TH: HTTPHeaders = [
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Encoding": "br, gzip, deflate",
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1",
    "Accept-Language": "zh-cn",
]

let sendPEM_TH = "-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDeGH/XqntbcuAXVkGseIs/znxq\nNREIiFOfOaoG0JENUr9XtxEXr+NcH/0vrXllMMlkuQuAERXKuXP51hLCW4cOOvhu\n4ftqFo51OZLusKqm8WPLuZeq0CtKLRi9dj0EWqbPJ/zJY4e6H3ua8Pg6XlQqyueS\nJXsh0QUTnRIOu/MMzQIDAQAB\n-----END PUBLIC KEY-----"

class PlatTh: Plat {
    var logUI:UITextView!
    var devInfo = Dictionary<String, String>()
    var loginInfo = Dictionary<String, Any?>()
    var cancelledTasks = Array<String>()
    var runningTasks = Dictionary<String, Dictionary<String, Any>>()
    var taskQueue = DispatchQueue.init(label: "th.main")
    
    override init() {
    }
    
    init(dict: [String: String], logUI:UITextView) {
        self.devInfo = dict
        self.logUI = logUI
    }
    
    public func run() {
        var params = Dictionary<String, String>()
        var api = ""
        var sendParams = Dictionary<String, String>()
        while(true) {
            let sec = super.sleep4Next(plat: "th")
            print("th 主线程睡眠\(sec)")
            sleep(UInt32(sec))
            
            // -----------------
            // 1.登录
            // -----------------
            params = [
                "now_idfa": self.devInfo["idfa"],
                "ios_model": self.devInfo["model"],
                "ios_version": self.devInfo["os"],
                "udid": self.devInfo["udid"],
                ] as! [String : String]
            api = DOMAIN_NAME_TH + "/api/index/login/"
            sendParams = self.encryptData(params: params)
            
            if sendParams.count < 1 {
                print("th 加密login数据失败")
                continue
            }
            
            var loginRet = false
            let loginSemp = DispatchSemaphore.init(value: 0)
            self.taskQueue.sync {
                AF.request(api, method: .post, parameters: sendParams, headers: HEADER_API_TH)
                    .validate(statusCode: 200..<300)
                    .responseString(completionHandler: { (respLogin) in
                        switch respLogin.result {
                        case .success:
                            let respLoginStr = String(data: respLogin.data!, encoding: .utf8)
                            do {
                                let respLoginDict = try JSONSerialization.jsonObject(with: (respLoginStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                                if respLoginDict.keys.contains("return_code") {
                                    let code:String = respLoginDict["return_code"] as! String
                                    if code == "200" {
                                        loginRet = true
                                        print("th 请求login成功")
                                    } else {
                                        print("th 响应login失败: \(code) - \(String(describing: respLoginStr))")
                                    }
                                } else {
                                    print("th 响应login失败: \(String(describing: respLoginStr))")
                                }
                            } catch let error {
                                print("th 请求login异常: \(error) - \(String(describing: respLoginStr))")
                            }
                            break
                        case .failure(_):
                            print("th 请求login失败")
                            break
                        }
                        loginSemp.signal()
                    })
            }
            
            let loginWaitRet = loginSemp.wait(timeout: .now() + .seconds(20))
            if loginWaitRet == .timedOut || !loginRet {
                continue
            }
            
            
            // -----------------
            // 2.获取authKey
            // -----------------
            var authKey = self.getAuthKey()
            if authKey.count < 1 {
                continue
            } else {
                print("th 获取authKey成功:\(authKey)")
            }
            
            // -----------------
            // 3.获取list
            // -----------------
            params = [
                "ios_model": self.devInfo["model"],
                "ios_version": self.devInfo["os"],
                "now_idfa": self.devInfo["idfa"],
                "udid": self.devInfo["udid"]!,
                "auth_key": authKey,
                "uid": self.devInfo["thUid"]
                ] as! [String : String];
            api = DOMAIN_NAME_TH + "/api/index/list/"
            sendParams = self.encryptData(params: params)
            if sendParams.count < 1 {
                print("th 加密list数据失败")
                continue
            }
            
            self.runningTasks.removeAll()
            var tmpTasks = Dictionary<String, Dictionary<String, Any>>()
            var listRet = false
            let listSemp = DispatchSemaphore.init(value: 0)
            self.taskQueue.sync {
                AF.request(api, method: .post, parameters: sendParams, headers: HEADER_API_TH)
                    .validate(statusCode: 200..<300)
                    .responseString(completionHandler: { (respList) in
                        switch respList.result {
                        case .success:
                            let respListStr = String(data: respList.data!, encoding: .utf8)
                            do {
                                let respListDict = try JSONSerialization.jsonObject(with: (respListStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                                if respListDict.keys.contains("return_data") {
                                    guard let returnData = respListDict["return_data"] as? Dictionary<String, Any> else {
                                        print("th 请求list数据异常：\(String(describing: respListStr))")
                                        return
                                    }
                                    if returnData.keys.contains("applist") {
                                        listRet = true
                                        let taskList = returnData["applist"] as! Array<Dictionary<String, Any?>>
                                        if taskList.count < 1 {
                                            print("th 请求list任务为: 0")
                                        } else {
                                            print("th 请求list任务为: \(taskList.count)")
                                        }
                                        
                                        for eachTask in taskList {
                                            let taskInfo = [
                                                "price": atof(eachTask["price"] as! String)
                                            ]
                                            tmpTasks[eachTask["id"] as! String] = taskInfo
                                        }
                                    } else {
                                        print("th 请求list无数据: \(String(describing: respListStr))")
                                    }
                                } else {
                                    print("th 请求list无数据: \(String(describing: respListStr))")
                                }
                            } catch let error {
                                print("th 请求lis失败: \(error) - \(String(describing: respListStr))")
                            }
                            break
                        case .failure(_):
                            print("th 请求lis失败")
                            break
                        }
                        listSemp.signal()
                    })
            }
            let listWaitRet = listSemp.wait(timeout: .now() + .seconds(20))
            if listWaitRet == .timedOut || !listRet {
                continue
            }
            
            self.runningTasks = super.randomTasks(tasks: tmpTasks)
            
            // -----------------
            // 4.循环列表
            // -----------------
            var tryAuthKeyTime = 0
            authKey = ""
            for (taskId, _) in self.runningTasks {
                if self.cancelledTasks.contains(taskId) {
                    continue
                }
                
                if authKey.count < 1 {
                    var getAuthKey = false
                    while tryAuthKeyTime < 3 {
                        authKey = self.getAuthKey()
                        if authKey.count > 1 {
                            getAuthKey = true
                            break
                        }
                        tryAuthKeyTime += 1
                    }
                    
                    // 3次h未获取到authKey，结束列表循环
                    if !getAuthKey {
                        break
                    }
                }
                
                // -----------------
                // 5.领取任务
                // -----------------
                api = DOMAIN_NAME_TH + "/api/index/apply/"
                params = [
                    "auth_key": authKey,
                    "now_idfa": self.devInfo["idfa"],
                    "tid": taskId,
                    "udid": self.devInfo["udid"]!,
                    "ios_model": self.devInfo["model"],
                    "ios_version": self.devInfo["os"],
                    ] as! [String : String]
                sendParams = self.encryptData(params: params)
                if sendParams.count < 1 {
                    print("th 加密apply数据失败:\(taskId)")
                    continue
                }
                
                var applyRet = false
                let applySemp = DispatchSemaphore.init(value: 0)
                self.taskQueue.sync {
                    AF.request(api, method: .post, parameters: sendParams, headers: HEADER_API_TH)
                        .validate(statusCode: 200..<300)
                        .responseString(completionHandler: { (respApply) in
                            switch respApply.result {
                            case .success:
                                let respApplyStr = String(data: respApply.data!, encoding: .utf8)
                                do {
                                    let respApplyDict = try JSONSerialization.jsonObject(with: (respApplyStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                                    if respApplyDict.keys.contains("return_code") {
                                        let code:String = respApplyDict["return_code"] as! String
                                        if code == "200" {
                                            applyRet = true
                                            print("th 请求apply成功:\(taskId)")
                                        } else {
                                            print("th 请求apply失败: \(String(describing: respApplyStr))")
                                        }
                                    } else {
                                        print("th 请求apply失败: \(String(describing: respApplyStr))")
                                    }
                                } catch let error {
                                    print("th 请求apply异常: \(error) - \(String(describing: respApplyStr))")
                                }
                                break
                            case .failure(_):
                                print("th 响应apply失败:\(taskId)")
                                break
                            }
                            applySemp.signal()
                        })
                }
                let applyWaitRet = applySemp.wait(timeout: .now() + .seconds(20))
                if applyWaitRet == .timedOut || !applyRet {
                    print("th 任务apply失败:\(taskId)")
                    continue
                }
                
                // -----------------
                // 6.请求详情 - 获取bundle_id
                // -----------------
                let detailInfo = self.getTaskDetail(taskId: taskId)
                if detailInfo.bundle.count < 1 {
                    print("th 获取详情信息失败:\(taskId)")
                    self.cancelTask(taskId: taskId)
                    continue
                }
                
                // -----------------
                // 7.睡眠下载
                // -----------------
                let downAppSleep = Int(arc4random() % 20) + 30
                print("th 开始下载APP - \(downAppSleep)")
                sleep(UInt32(downAppSleep))
                
                // authKey有超时时间
                tryAuthKeyTime = 0
                authKey = ""
                
                // -----------------
                // 8.打开app
                // -----------------
                api = DOMAIN_NAME_TH + "/api/index/checkapp/"
                params = [
                    "now_idfa": self.devInfo["idfa"],
                    "bundleId": detailInfo.bundle,
                    "method": "open",
                    "udid": self.devInfo["udid"],
                    "ios_model": self.devInfo["model"],
                    "ios_version": self.devInfo["os"],
                    ] as! [String : String]
                sendParams = self.encryptData(params: params)
                if sendParams.count < 1 {
                    print("th 加密checkapp数据失败:\(taskId)")
                    self.cancelTask(taskId: taskId)
                    continue
                }
                
                var openRet = false
                let openAppSem = DispatchSemaphore.init(value: 0)
                self.taskQueue.sync {
                    AF.request(api, method: .post, parameters: sendParams, headers: HEADER_API_TH)
                        .validate(statusCode: 200..<300)
                        .responseString(completionHandler: { (respOpen) in
                            switch respOpen.result {
                            case .success:
                                let respOpenStr = String(data: respOpen.data!, encoding: .utf8)
                                do {
                                    let respOpenDict = try JSONSerialization.jsonObject(with: (respOpenStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                                    if respOpenDict.keys.contains("return_code") {
                                        let code:String = respOpenDict["return_code"] as! String
                                        if code == "200" {
                                            openRet = true
                                            print("th 打开openapp成功")
                                        } else {
                                            print("th 请求openapp失败: \(String(describing: respOpenStr))")
                                        }
                                    } else {
                                        print("th 请求openapp失败: \(String(describing: respOpenStr))")
                                    }
                                } catch let error {
                                    print("th 请求openapp异常: \(error) - \(String(describing: respOpenStr))")
                                }
                                break
                            case .failure(_):
                                print("th 请求openapp失败:\(taskId)")
                                break
                            }
                            openAppSem.signal()
                        })
                }
                let openAppWaitRet = openAppSem.wait(timeout: .now() + .seconds(20))
                if openAppWaitRet == .timedOut || !openRet {
                    print("th 打开app失败:\(taskId)")
                    self.cancelTask(taskId: taskId)
                    continue
                }
                
                
                // -----------------
                // 9.睡眠试玩
                // -----------------
                let playAppSleep = Int(arc4random() % 10) + detailInfo.minute*60
                print("th 开始试玩APP - \(playAppSleep)")
                sleep(UInt32(playAppSleep))
                
                
                // -----------------
                // 10.提交试玩
                // -----------------
                var verifyRet = false
                api = DOMAIN_NAME_TH + "/taskaso/verify/?tid=\(taskId)"
                var verifyHeader = HEADER_H5_TH
                verifyHeader["Cookie"] = "swuser={\"uid\":" + self.devInfo["thUid"]! + "}"
                let verifySemp = DispatchSemaphore.init(value: 0)
                self.taskQueue.sync {
                    AF.request(api, method: .get, headers: verifyHeader)
                        .validate(statusCode: 200..<300)
                        .responseString(completionHandler: { (respVerify) in
                            switch respVerify.result {
                            case .success:
                                let respVerifyStr = String(data: respVerify.data!, encoding: .utf8)
                                do {
                                    let respVerifyDict = try JSONSerialization.jsonObject(with: (respVerifyStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                                    if respVerifyDict.keys.contains("code") {
                                        guard let code = respVerifyDict["code"] as? Int else {
                                            print("th 请求verify失败: \(String(describing: respVerifyStr))")
                                            return
                                        }
                                        
                                        if String(code) == "1" {
                                            verifyRet = true
                                            print("th 请求verify成功:\(taskId)")
                                        } else {
                                            print("th 请求verify失败: \(String(describing: respVerifyStr))")
                                        }
                                    } else {
                                        print("th 请求verify失败: \(String(describing: respVerifyStr))")
                                    }
                                } catch let error {
                                    print("th 请求verify异常: \(error) - \(String(describing: respVerifyStr))")
                                }
                                break
                            case .failure(_):
                                print("th 请求verify失败:\(taskId)")
                                break
                            }
                            
                            verifySemp.signal()
                        })
                }
                let verifyWaitRet = verifySemp.wait(timeout: .now() + .seconds(20))
                if verifyWaitRet == .timedOut || !verifyRet {
                    print("th 提交任务失败:\(taskId)")
                    self.cancelTask(taskId: taskId)
                    continue
                } else {
                    
                }
            } // end for task
        } // end while(True)
    }// end run
    
    func cancelTask(taskId: String) -> Void {
        var cancelRet = false
        let api = DOMAIN_NAME_TH + "/taskaso/cancel/?tid=\(taskId)"
        var cancelHeader = HEADER_H5_TH
        cancelHeader["Cookie"] = "swuser={\"uid\":" + self.devInfo["thUid"]! + "}"
        
        let cancelSemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method: .get, headers: cancelHeader)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respCancel) in
                    switch respCancel.result {
                    case .success:
                        let respCancelStr = String(data: respCancel.data!, encoding: .utf8)
                        do {
                            let respCancelDict = try JSONSerialization.jsonObject(with: (respCancelStr?.data(using: .utf8))!, options: .mutableContainers) as! Dictionary<String, AnyObject?>
                            if respCancelDict.keys.contains("code") {
                                guard let code = respCancelDict["code"] as? Int else {
                                    print("th 请求cancel失败: \(String(describing: respCancelStr))")
                                    return
                                }
                                if String(code) == "1" {
                                    cancelRet = true
                                } else {
                                    print("th 请求cancel失败: \(String(describing: respCancelStr))")
                                }
                            } else {
                                print("th 请求cancel失败: \(String(describing: respCancelStr))")
                            }
                        } catch let error {
                            print("th 请求cancel异常: \(error)")
                        }
                        break
                    case .failure(_):
                        print("th 请求cancel失败:\(taskId)")
                        break
                    }
                    
                    cancelSemp.signal()
                })
        }
        let cancelWaitRet = cancelSemp.wait(timeout: .now() + .seconds(2400))
        if cancelWaitRet == .timedOut || !cancelRet {
            // 睡眠时间，待释放
            print("th 取消失败开始睡眠 - 2400")
            sleep(2400)
        }
        self.cancelledTasks.append(taskId)
    }
    
    func getTaskDetail(taskId: String) -> (bundle:String, minute: Int) {
        var bundle = ""
        var minute = 0
        var detailHeader = HEADER_H5_TH
        detailHeader["Cookie"] = "swuser={\"uid\":" + self.devInfo["thUid"]! + "}"
        let api = DOMAIN_NAME_TH + "/taskaso/detail/?tid=\(taskId)"
        let detailSemp = DispatchSemaphore.init(value: 0)
        
        self.taskQueue.sync {
            AF.request(api, method: .get, headers: detailHeader)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respDetail) in
                    switch respDetail.result {
                    case .success:
                        let respData = String(data: respDetail.data!, encoding: .utf8)
                        do {
                            let doc: Document = try SwiftSoup.parse(respData!)
                            let bundleElem: Element = try doc.getElementById("bundle_id")!
                            let minuteElem: Element = try doc.getElementById("try_play")!
                            bundle = try bundleElem.attr("value")
                            minute = try Int(minuteElem.attr("value"))!
                        } catch let error {
                            print("th 解析detail页面失败: \(error) - \(String(describing: respData))")
                        }
                        break
                    case .failure(_):
                        print("th 请求detail失败:\(taskId)")
                        break
                    }
                    detailSemp.signal()
                })
        }
        _ = detailSemp.wait(timeout: .now() + .seconds(20))
        return (bundle, minute)
    }
    
    func getAuthKey() -> String {
        var authKey = ""
        var authKeyHeader = HEADER_H5_TH
        authKeyHeader["Cookie"] = "swuser={\"uid\":" + self.devInfo["thUid"]! + "}"
        let api = DOMAIN_NAME_TH + "/taskaso/index/"
        let authKeySemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method: .get, headers: authKeyHeader)
                .validate(statusCode: 200..<300)
                .responseString(completionHandler: { (respAuthKey) in
                    switch respAuthKey.result {
                    case .success:
                        let respData = String(data: respAuthKey.data!, encoding: .utf8)
                        do {
                            let doc:Document = try SwiftSoup.parse(respData!)
                            guard let authKeyElem:Element = try doc.getElementById("auth") else {
                                print("th 请求authkey失败: \(String(describing: respData))")
                                return
                            }
                            authKey = try authKeyElem.attr("value")
                        } catch let error {
                            print("th 解析authkey页面失败: \(error) - \(String(describing: respData))")
                        }
                        break
                    case .failure(_):
                        print("th 请求authkey失败")
                        break
                    }
                    authKeySemp.signal()
                })
        }
        _ = authKeySemp.wait(timeout: .now() + .seconds(20))
        return authKey
    }
    
    func encryptData(params: [String: String]) -> Dictionary<String, String> {
        var retDict = Dictionary<String, String>()
        let curTime = Date().timeIntStamp
        var allParams = params
        
        // 拼接字串
        allParams["app_version"] = "1.1.2"
        allParams["app_key"] = "21428uyw23e7dhde"
        allParams["carrier_code"] = "46001"
        allParams["app_installed"] = """
        ["taobao","mqq","weixin","alipay","openApp.jdMobile"]
        """
        allParams["udid_from"] = "1"
        allParams["bssid"] = "a:9b:4b:97:54:3a"
        allParams["charging"] = "1"
        allParams["power"] = "1.00"
        allParams["acceleration_x"] = "0.\(Int(arc4random()%1000000))"
        allParams["acceleration_y"] = "-0.\(Int(arc4random()%1000000))"
        allParams["acceleration_z"] = "-0.\(Int(arc4random()%1000000))"
        allParams["gyro_x"] = "0.\(Int(arc4random()%1000000))"
        allParams["gyro_y"] = "0.\(Int(arc4random()%1000000))"
        allParams["gyro_z"] = "0.\(Int(arc4random()%1000000))"
        allParams["auth_timestamp"] = curTime
        
        var strParams = ""
        for (key, value) in allParams {
            strParams += "\(key)=\(value)&"
        }
        strParams = String(strParams.prefix(upTo: strParams.index(strParams.endIndex, offsetBy: -1)))
        
        // AES-ECB加密业务参数字串
        if strParams.count % AES.blockSize > 0 {
            let padNum = AES.blockSize - strParams.count % AES.blockSize
            let padChar = Character(UnicodeScalar(padNum)!)
            for _ in 1...padNum {
                strParams += String(padChar)
            }
        }
        
        // 随机密钥加密
        var encryptedRandomKey = ""
        let randomKey = String.randomStr(len: 16)
        let randomStr = "\(randomKey)\(curTime)"
        let pubKey = try? PublicKey(pemEncoded: sendPEM_TH)
        do {
            let clear = try ClearMessage(string: randomStr, using: .utf8)
            let encrypted = try clear.encrypted(with: pubKey!, padding: .PKCS1)
            encryptedRandomKey = encrypted.base64String
        } catch let error {
            print("th error >>> \(error.localizedDescription)")
            return retDict
        }
        encryptedRandomKey = encryptedRandomKey.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        encryptedRandomKey = encryptedRandomKey.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed)!
        encryptedRandomKey = encryptedRandomKey.replacingOccurrences(of: "%252F", with: "%2F")
        
        var encodeString = ""
        do {
            let aes = try AES(key: [UInt8](randomKey.utf8), blockMode: ECB())
            let encoded = try aes.encrypt(strParams.bytes)
            encodeString = encoded.toBase64()!
        } catch let error {
            print("th error >>> \(error.localizedDescription)")
            return retDict
        }
        
        // 返回字典数据
        encodeString = encodeString.toBase64()!
        encodeString = encodeString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        encodeString = encodeString.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed)!
        //encodeString = encodeString.replacingOccurrences(of: "%252F", with: "%2F")
        
        retDict["params"] = encryptedRandomKey
        retDict["data"] = encodeString
        retDict["rand"] = randomKey
        retDict["time"] = curTime
        
        return retDict
    }
}
