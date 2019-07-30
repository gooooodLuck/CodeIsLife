

import UIKit
import SwiftyRSA
import Alamofire


let DOMAIN_NAME = "https://www.xiaoyuzhuanqian.com"
let HEADER_API: HTTPHeaders = [
    "Host": "www.xiaoyuzhuanqian.com",
    "Content-Type": "application/octet-stream",
    "ClientVersion": "10.9.8",
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Accept-Language": "zh-cn",
    "Accept-Encoding": "br, gzip, deflate",
    "User-Agent": "%E5%B0%8F%E9%B1%BC%E8%B5%9A%E9%92%B1/200030 CFNetwork/978.0.7 Darwin/18.6.0"
]

let HEADER_H5: HTTPHeaders = [
    "Host": "www.xiaoyuzhuanqian.com",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-cn",
    "Connection": "keep-alive",
    "Accept-Encoding": "br, gzip, deflate",
    "User-Agent": "Mozilla/5.0 (iphone; CPU iPhone OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
]

let sendPEM = "-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC88qgwsQYJwkK3+rEVSh3lLfsv\nKF+VtFVC42TptEG3Sf4WHN7Zxs5gsqR8+qYi08JkvBmeeJpup3+H4d2GuXGnves9\nQ17NzOvzdqiCrImBPRTtdtTRbrpDzjOOuUaf5kLCTMsXBmQZ9Ur3001+ljjseXay\CtqV3962xRxI6oIBHcwIDAQAB\n-----END PUBLIC KEY-----"
let recvPEM = "-----BEGIN RSA PRIVATE KEY-----\nMIICXgIBAAKBgQD1LrXIBnI0CuQnKAD1M8cUMXYpcAFTtr1g+Y4QpPUdoy0y8Ree\nlLQ4zSWnbevOPvxY6zX0Y3gn50VUsm3MYyJT/8Wf0gTYgb7zWa3W0Q+UWeb/1uIt\nq/Ka7ClEF2FZ4suJev5xCVXIc+6y8BJqN3y1/r+21aedP2/r20T5ICn2AQIDAQAB\nAoGBAJidnLWHnarbZK0i74Wx1yewqhadC5ZqV3N3o4CkzZbHLalZ/RPPCGea+uc/\nOtrExhsrPgiDqhVclgFkl4fz5TcgRmbLeTnQ6brBjgLME5K5QarjSJkC52I1C5UR\nKaVwclv0swYukNVOqEYJQIoMKh2tRoBUMvQvkkSQrsMgiX+JAkEA+3MScLbrloi+\n62/mUQ0LzSVFlOskuo6Y1hYwB4AHb8UZ2osQeqLu9avdfgHSCqtp9tr6pQQZogkk\ncFXwUtZuQwJBAPmempJkBPpZ1rr5HvAMlOUJfhU2OghRkF9pGe5gnyjdBAJNu0pK\nQGA3iJy1hGctlaIHkPXeFisCkm8+LmvgoGsCQQC0FvSMGdadmA71XM2eGzPql9lA\nETHbE6pPGtEHbiDlYktkBNmmm+99sLwQNYmT7rUUAj4l1cvuC5I3irV2/vQ1AkB1\ne8VqUvLY1YGv/GIoPvOxHJef6ibEFYdqsG/I9ubR97vUTbtxiqLj5h9BClmnqhe7\n6+25Gm66jXpYKx70HQPDAkEA5xYewmxNYJqOjn8nXS2ZTsonMNyrfiIudUD3jmu6\nD2r9lemG18YYINzDtiu0pFrGBdVN66cshmrLFQ2luwVMHA==\n-----END RSA PRIVATE KEY-----"

class PlatXy: Plat {
    var logUI:UITextView!
    var devInfo = Dictionary<String, String>()
    var loginInfo = Dictionary<String, Any?>()
    var cancelledTasks = Array<String>()
    var runningTasks = Dictionary<String, Dictionary<String, Any>>()
    var taskQueue = DispatchQueue.init(label: "xy.main")
    
    override init() {
    }
    
    init(dict: [String: String], logUI:UITextView) {
        self.devInfo = dict
        self.logUI = logUI
    }

    func run() {
        while (true) {
            let sec = super.sleep4Next(plat: "xy")
            print("xy 主线程睡眠\(sec)")
            sleep(UInt32(sec))
            
            /// -----------------------
            /// 1.checkUserInfo
            /// -----------------------
            var params = [
                "IDFA": self.devInfo["idfa"],
                "UDID": self.devInfo["udid"],
                "PRODUCT": self.devInfo["model"],
                "OSVersion": "Version" + self.devInfo["os"]! + " (Build 16F203)",
                "UsrID": self.devInfo["xyUid"]
            ]
            var checkRet = false
            var postStr = self.encryptData(params: params)
            var api = DOMAIN_NAME + "/api/authapp/checkuserinfo/"
            let checkSemp = DispatchSemaphore.init(value: 0)
            self.taskQueue.sync {
                AF.upload(postStr.data(using: .utf8)!, to: api, method: .post, headers: HEADER_API)
                    .validate(statusCode: 200..<300)
                    .responseString(completionHandler: { (respCheckUserInfo) in
                        switch respCheckUserInfo.result {
                        case .success:
                            let respData = String(data: respCheckUserInfo.data!, encoding: .utf8)
                            //print("xy 校验响应: \(respData ?? "")")
                            let respDict = self.decryptData(data: respData ?? "")
                            if  !respDict.keys.contains("code") {
                                print("xy 响应checkUserInfo异常: ")
                                break
                            }

                            let code = respDict["code"] as! String
                            if Int(code) != 0 {
                                print("xy 响应checkUserInfo失败: \(respDict["msg"] as? String ?? "")")
                                break
                            }

                            let checkUserInfoDict = respDict["data"] as! [String : AnyObject?]
                            if checkUserInfoDict.count < 1
                                || checkUserInfoDict["user_info"] == nil {
                                print("xy 响应checkUserInfo失败: 无用户信息")
                            } else {
                                print("xy 响应checkUserInfo成功")
                                self.loginInfo["serial"] = (checkUserInfoDict["user_info"] as! [String: Any])["serial"] ?? ""
                                self.loginInfo["app_id"] = (checkUserInfoDict["user_info"] as! [String: Any])["app_id"] ?? ""
                                
                                if self.loginInfo["app_id"] == nil {
                                    self.loginInfo["app_id"] = ""
                                }
                                
                                
                                checkRet = true
                            }
                            break;
                        case .failure(_):
                            print("xy 请求checkUserInfo失败")
                            break;
                        }
                        checkSemp.signal()
                    })
            }
            let checkSempWaitRet = checkSemp.wait(timeout: .now() + .seconds(15))
            if checkSempWaitRet == .timedOut || !checkRet {
                continue
            }
            
            /// -----------------------
            /// 2.applogin
            /// -----------------------
            var loginRet = false
            params["SERIAL"] = self.loginInfo["serial"] as? String
            params["UnsafeUsrID"] = self.loginInfo["app_id"] as? String
            postStr = self.encryptData(params: params)
            api = DOMAIN_NAME + "/api/authapp/applogin"
            let loginSemp = DispatchSemaphore.init(value: 0)
            self.taskQueue.sync {
                AF.upload(postStr.data(using: .utf8)!, to: api, method: .post, headers: HEADER_API)
                    .validate(statusCode: 200..<300)
                    .responseString(completionHandler: { (respAppLogin) in
                        switch respAppLogin.result {
                        case .success:
                            let respData = String(data: respAppLogin.data!, encoding: .utf8)
                            let respDict = self.decryptData(data: respData ?? "")
                            if !respDict.keys.contains("code") {
                                print("xy 响应appLogin异常: ")
                                break
                            }
                            
                            let code = respDict["code"] as! String
                            if Int(code) != 0 {
                                print("xy 响应appLogin失败: \(respDict["msg"] as? String ?? "")")
                                break
                            }
                            
                            let appLoginInfoDict = respDict["data"] as! [String: AnyObject?]
                            if appLoginInfoDict.count < 1 || appLoginInfoDict["v4_token_tag"] == nil {
                                print("xy 响应appLogin失败: 无token信息")
                            } else {
                                print("xy 响应appLogin成功")
                                self.loginInfo["token"] = appLoginInfoDict["v4_token_tag"] as? String
                                let acceUrl = appLoginInfoDict["direct_url"] as! String
                                AF.request(acceUrl).response(completionHandler: { (resp) in
                                })
                                loginRet = true
                            }
                            break;
                        case .failure(_):
                            print("xy 请求appLogin失败")
                            break;
                        }
                        
                        loginSemp.signal()
                    })
            }
            let loginSempWaitRet = loginSemp.wait(timeout: .now() + .seconds(15))
            if loginSempWaitRet == .timedOut || !loginRet {
                continue
            }
            
            /// -----------------------
            /// 3.tasklist
            /// -----------------------
            var taskListRet = false
            if (self.loginInfo["token"] as! String).count < 1 {
                print("xy 未获取到token信息")
                continue
            }
            // 请求页面
            let h5Params = ["v4_token_tag": self.loginInfo["token"] as! String]
            api = DOMAIN_NAME + "/app/taskaso/list/"
            AF.request(api, parameters: h5Params, headers: HEADER_H5)
                .response { (resp) in
            }
            
            // 请求接口
            params = [
                "IDFA": self.devInfo["idfa"],
                "UDID": self.devInfo["udid"],
                "PRODUCT": self.devInfo["model"],
                "OSVersion": "Version" + ((self.devInfo["os"])!) + " (Build 16F203)",
                "UsrID": String(self.devInfo["xyUid"]!),
                "UsrToken": self.loginInfo["token"],
                "UnsafeUsrID": self.loginInfo["app_id"],
                "SERIAL": self.loginInfo["serial"]
                ] as! [String : String]
            
            postStr = self.encryptData(params: params as [String : Any?])
            api = DOMAIN_NAME + "/api/authapp/list/"
            
            self.runningTasks.removeAll()
            var tmpTasks = Dictionary<String, Dictionary<String, Any>>()
            let listSemp = DispatchSemaphore.init(value: 0)
            self.taskQueue.sync {
                AF.upload(postStr.data(using: .utf8)!, to: api, method: .post, headers: HEADER_API)
                    .validate(statusCode: 200..<300)
                    .responseString { (respList) in
                        switch respList.result {
                        case .success:
                            let respData = String(data: respList.data!, encoding: .utf8)
                            let respDict = self.decryptData(data: respData ?? "")
                            if !respDict.keys.contains("code") {
                                print("xy 响应list异常: ")
                                break
                            }
                            
                            let code = respDict["code"] as! String
                            if Int(code) != 0 {
                                print("xy 响应list失败: \(respDict["msg"] as? String ?? "")")
                                break
                            }
                            
                            let listDict = respDict["data"] as! [String: AnyObject?]
                            if listDict.keys.contains("applist") {
                                let tasks = listDict["applist"] as! Array<Dictionary<String, Any?>>
                                for eachTask in tasks {
                                    let taskInfo = [
                                        "bundle_id": eachTask["bundle_id"] as! String,
                                        "play": (eachTask["play"] as? Int ?? 3) * 60,
                                        "price": atof(eachTask["price"] as? String ?? "0.8") * 100,
                                        ] as Dictionary<String, Any>
                                    
                                    tmpTasks[eachTask["id"] as! String] = taskInfo
                                }
                                
                                if tasks.count > 0 {
                                    print("xy 响应list成功: \(tasks.count)个在线任务")
                                    taskListRet = true
                                } else {
                                    print("xy 响应list成功: 0个在线任务")
                                }
                            } else {
                                print("xy 响应list成功: 无在线任务")
                            }
                            break
                        case .failure(_):
                            print("xy 请求list失败")
                            break;
                        }
                        
                        listSemp.signal()
                }
            }
            let listSempWaitRet = listSemp.wait(timeout: .now() + .seconds(15))
            if listSempWaitRet == .timedOut || !taskListRet {
                continue
            }
            self.runningTasks = super.randomTasks(tasks: tmpTasks)
            
            
            /// -----------------------
            /// 4.applytask_lists
            /// -----------------------
            postStr = ""
            params = [
                "IDFA": self.devInfo["idfa"],
                "UDID": self.devInfo["udid"],
                "PRODUCT": self.devInfo["model"],
                "OSVersion": "Version" + ((self.devInfo["os"])!) + " (Build 16F203)",
                "UsrID": self.devInfo["xyUid"],
                "UsrToken": self.loginInfo["token"],
                "UnsafeUsrID": self.loginInfo["app_id"],
                "SERIAL": self.loginInfo["serial"]
                ] as! [String : Optional<String>]
            api = DOMAIN_NAME + "/api/authapp/apply/"
            
            for (taskId, _) in self.runningTasks {
                if self.cancelledTasks.contains(taskId) {
                    continue
                }
                
                /// -----------------------
                /// 4.1 applytask
                /// -----------------------
                var applyRet = false
                params["app_id"] = taskId
                postStr = self.encryptData(params: params as [String : Any?])
                
                let waitApplySem = DispatchSemaphore.init(value: 0)
                self.taskQueue.sync {
                    AF.upload(postStr.data(using: .utf8)!, to: api, method: .post, headers: HEADER_API)
                        .validate(statusCode: 200..<300)
                        .responseString { (respApply) in
                            switch respApply.result {
                            case .success:
                                let respData = String(data: respApply.data!, encoding: .utf8)
                                let respDict = self.decryptData(data: respData ?? "")
                                if !respDict.keys.contains("code") {
                                    print("xy 响应apply异常: \(taskId)")
                                    break
                                }
                                
                                let code = respDict["code"] as! String
                                if Int(code) != 0 && Int(code) != 5000 { // 5000 体验中的应用
                                    print("xy 响应apply失败: \(taskId) - \(respDict["msg"] as? String ?? "")")
                                    break
                                }
                                
                                print("xy 响应apply成功:\(taskId)")
                                applyRet = true
                                
                                // 加载详情
                                let h5Params = [
                                    "appid": taskId,
                                    "v4_token_tag": self.loginInfo["token"] as! String
                                ]
                                api = DOMAIN_NAME + "/app/taskaso/asodtl/"
                                AF.request(api, parameters: h5Params, headers: HEADER_H5)
                                    .response(completionHandler: { (resp) in
                                    })
                                break
                            case .failure(_):
                                print("xy 请求apply失败: \(taskId)")
                                break
                            }
                            
                            waitApplySem.signal()
                    }
                }
                let applySempWaitRet = waitApplySem.wait(timeout: .now() + .seconds(15))
                if applySempWaitRet == .timedOut || !applyRet {
                    continue
                }
                
                /// -----------------------
                /// 4.2 downloadapp
                /// -----------------------
                let downAppSleep = Int(arc4random() % 10) + 30
                print("xy 开始下载APP - \(downAppSleep)")
                sleep(UInt32(downAppSleep))
                
                /// -----------------------
                /// 4.3 openapp
                /// -----------------------
                var openRet = false
                let openAppSem = DispatchSemaphore.init(value: 0)
                // 打开app
                params = [
                    "IDFA": self.devInfo["idfa"],
                    "UDID": self.devInfo["udid"],
                    "PRODUCT": self.devInfo["model"],
                    "OSVersion": "Version" + ((self.devInfo["os"])!) + " (Build 16F203)",
                    "UsrID": self.devInfo["xyUid"],
                    "UsrToken": self.loginInfo["token"],
                    "UnsafeUsrID": self.loginInfo["app_id"],
                    "SERIAL": self.loginInfo["serial"],
                    "method": "open",
                    "bundleId": self.runningTasks[taskId]!["bundle_id"],
                    ] as! [String : Optional<String>]
                api = DOMAIN_NAME + "/api/authapp/checkapp/"
                postStr = self.encryptData(params: params as [String : Any?])
                self.taskQueue.sync {
                    AF.upload(postStr.data(using: .utf8)!, to: api, method: .post, headers: HEADER_API)
                        .validate(statusCode: 200..<300)
                        .responseString { (respOpen) in
                            switch respOpen.result {
                            case .success:
                                let respData = String(data: respOpen.data!, encoding: .utf8)
                                let respDict = self.decryptData(data: respData ?? "")
                                if !respDict.keys.contains("code") {
                                    print("xy 响应checkapp异常: \(taskId)")
                                    break
                                }
                                
                                let code = respDict["code"] as! String
                                if Int(code) != 0 {
                                    print("xy 响应checkapp失败:  \(taskId) - \(respDict["msg"] as? String ?? "")")
                                    break
                                }
                                openRet = true
                                break
                            case .failure(_):
                                print("xy 请求checkapp失败: \(taskId)")
                                self.cancelTask(taskId: taskId, token: self.loginInfo["token"] as! String)
                                break
                            }
                            
                            openAppSem.signal()
                    }
                }
                let openSempWaitRet = openAppSem.wait(timeout: .now() + .seconds(15))
                if openSempWaitRet == .timedOut || !openRet {
                    self.cancelTask(taskId: taskId, token: self.loginInfo["token"] as! String)
                    continue
                }
                
                
                /// -----------------------
                /// 4.4 playapp
                /// -----------------------
                let playSeconds = self.runningTasks[taskId]!["play"] as! Int + Int(arc4random() % 30)
                print("xy 响应checkapp成功: 开启试玩\(playSeconds)")
                sleep(UInt32(playSeconds))
                
                /// -----------------------
                /// 4.5 submit
                /// -----------------------
                var submitRet = false
                params = [
                    "IDFA": self.devInfo["idfa"],
                    "UDID": self.devInfo["udid"],
                    "PRODUCT": self.devInfo["model"],
                    "OSVersion": "Version" + ((self.devInfo["os"])!) + " (Build 16F203)",
                    "UsrID": self.devInfo["xyUid"],
                    "UsrToken": self.loginInfo["token"],
                    "UnsafeUsrID": self.loginInfo["app_id"],
                    "SERIAL": self.loginInfo["serial"],
                    "app_id": taskId,
                    ] as! [String : Optional<String>]
                api = DOMAIN_NAME + "/api/authapp/verify/"
                postStr = self.encryptData(params: params as [String : Any?])
                
                let verifySemp = DispatchSemaphore.init(value: 0)
                self.taskQueue.sync {
                    AF.upload(postStr.data(using: .utf8)!, to: api, method: .post, headers: HEADER_API)
                        .validate(statusCode: 200..<300)
                        .responseString { (respVerify) in
                            switch respVerify.result {
                            case .success:
                                let respData = String(data: respVerify.data!, encoding: .utf8)
                                let respDict = self.decryptData(data: respData ?? "")
                                
                                if !respDict.keys.contains("code") {
                                    print("xy 响应verify异常:  \(taskId)")
                                    break
                                }
                                
                                let code = respDict["code"] as! String
                                if Int(code) != 0 {
                                    print("xy 响应verify失败:  \(taskId) - \(respDict["msg"] as? String ?? "")")
                                    break
                                }
                                
                                print("xy 响应verify成功:\(taskId)")
                                submitRet = true;
                                break
                            case .failure(_):
                                print("xy 请求verify失败: \(taskId)")
                                break
                            }
                            verifySemp.signal()
                    }
                }
                let verifySempWaitRet = verifySemp.wait(timeout: .now() + .seconds(15))
                if verifySempWaitRet == .timedOut || !submitRet {
                    self.cancelTask(taskId: taskId, token: self.loginInfo["token"] as! String)
                    continue
                }
            } //end for
        } // end while
        
    }// end func
    
    func cancelTask(taskId: String, token: String) -> Void {
        let params = [
            "app_id": taskId,
            "reason": String(Int(arc4random() % 4) + 1),
            "v4_token_tag": token
        ]
        let api = DOMAIN_NAME + "/app/taskaso/cancel/"
        let cancelSemp = DispatchSemaphore.init(value: 0)
        self.taskQueue.sync {
            AF.request(api, method:.get, parameters: params, headers: HEADER_H5)
                .validate(statusCode: 200..<300)
                .responseString { (respCancel) in
                    switch respCancel.result {
                    case .success:
                        do {
                            let jsonString = try respCancel.result.get()
                            print("xy cancel响应\(jsonString)")
                            let jsonData = jsonString.data(using: String.Encoding.utf8, allowLossyConversion: false) ?? Data()
                            guard let respCancelDict = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String:AnyObject] else {
                                sleep(1600)
                                cancelSemp.signal()
                                return
                            }
                            
                            if respCancelDict["code"] as! Int != 0 {
                                print("xy 响应cancel失败:  \(taskId) - \(String(describing: respCancelDict["msg"]!))")
                                sleep(1600)
                                cancelSemp.signal()
                                break
                            } else {
                                print("xy 响应cancel成功:\(taskId)")
                            }
                        } catch let error {
                            print("xy 响应cancel异常:  \(taskId) - \(error)")
                            sleep(1600)
                            cancelSemp.signal()
                        }
                        break
                    case .failure(let f):
                        print("xy 请求cancel失败: \(taskId) - \(f.localizedDescription)")
                        sleep(1600)
                        cancelSemp.signal()
                        break
                    }
            }
        }
        _ = cancelSemp.wait(timeout: .now() + .seconds(1600))
        self.cancelledTasks.append(taskId)
    }
    
    
    
    func encryptData(params: [String: Any?]) -> String {
        var allParams = params
        allParams["Time"] = Date().timeFloatStamp
        allParams["VERSION"] = "16F203"
        allParams["CMNC"] = "01"
        allParams["CICC"] = "cn"
        allParams["BSSID"] = ""
        allParams["ClientVersion"] = "11.2.2"
        allParams["MEID"] = "35946308142185"
        allParams["IMEI"] = "35 946308 142185 8"
        allParams["CMCC"] = "460"
        allParams["ClientBundleID"] = "ap.xilingol.x"
        allParams["DarwinVersion"] = "Darwin Kernel Version 18.6.0: Thu Apr 25 22:14:06 PDT 2019; root:xnu-4903.262.2~2\\/RELEASE_ARM64_T8010"
        allParams["SSID"] = ""
        allParams["UsrGroup"] = ""
        
        let data : NSData! = try? JSONSerialization.data(withJSONObject: allParams, options: []) as NSData?
        let JSONString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
        //print("xy 加密前：\(JSONString ?? "")")
        
        // 公钥加密
        let pubKey = try? PublicKey(pemEncoded: sendPEM)
        do {
            let clear = try ClearMessage(string: JSONString! as String, using: .utf8)
            let encrypted = try clear.encrypted(with: pubKey!, padding: .PKCS1)
            return encrypted.base64String
        } catch let error {
            print("xy error >>> \(error)")
        }
        
        return ""
    }
    
    func decryptData(data:String) -> Dictionary<String, AnyObject?> {
        if data == "" {
            return [:]
        }
        
        do {
            // 私钥解密
            let priKey = try PrivateKey(pemEncoded: recvPEM)
            let encrypted = try EncryptedMessage(base64Encoded: data)
            let clear = try encrypted.decrypted(with: priKey, padding: .PKCS1)
            let strResp = try clear.string(encoding: .utf8)
            let dictResp = try JSONSerialization.jsonObject(with: (strResp.data(using: .utf8))!, options: .mutableContainers)
            //print("xy 解密后: \(strResp)")
            if dictResp != nil {
                return dictResp as! Dictionary<String, AnyObject?>
            }
        } catch let error {
            print("xy error >>> \(error)")
        }
        
        return [:]
    }
}
