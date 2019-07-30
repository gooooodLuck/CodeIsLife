

import UIKit
import AdSupport
import Alamofire


let SCR_W = UIScreen.main.bounds.width
let SCR_H = UIScreen.main.bounds.height

class ViewController: UIViewController {
    var devInfo = Dictionary<String, String>()
    var logTextView:UITextView!
    var startBtn:UIButton!
    var udidText:UITextField!
    var xyUidText:UITextField!
    var thUidText:UITextField!
    var yqzUidText:UITextField!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        initDeviceData()
        initUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func initDeviceData() {
        self.devInfo["idfa"] = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        self.devInfo["os"] = UIDevice.current.systemVersion
        let curModel = UIDevice.current.modelName
        if curModel.range(of: "86_64") == nil {
            self.devInfo["model"] = curModel
        } else {
            self.devInfo["model"] = "iPhone7,2"
        }
        
        let userDefault = UserDefaults.standard
        guard let udid:String = userDefault.string(forKey: "udid") else {
            return
        }
        self.devInfo["udid"] = udid
        
        guard let xyUid:String = userDefault.string(forKey: "xyUid") else {
            return
        }
        self.devInfo["xyUid"] = xyUid
        
        guard let thUid:String = userDefault.string(forKey: "thUid") else {
            return
        }
        self.devInfo["thUid"] = thUid
        
        guard let yqzUid:String = userDefault.string(forKey: "yqzUid") else {
            return
        }
        self.devInfo["yqzUid"] = yqzUid
    }
    
    func initUI() {
        self.udidText = UITextField(frame: CGRect(x: 10, y: 30, width:350, height: 20))
        self.udidText.text = self.devInfo["udid"]
        self.udidText.borderStyle = UITextField.BorderStyle.roundedRect
        self.udidText.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(self.udidText)
        
        let xyLable:UILabel = UILabel.init(frame: CGRect(x: 10, y: 50, width:50, height: 20))
        xyLable.text = "1-x"
        xyLable.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(xyLable)
        
        self.xyUidText = UITextField(frame: CGRect(x: 60, y: 50, width:300, height: 20))
        self.xyUidText.text = self.devInfo["xyUid"]
        self.xyUidText.borderStyle = UITextField.BorderStyle.roundedRect
        self.xyUidText.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(self.xyUidText)
        
        let thLable:UILabel = UILabel.init(frame: CGRect(x: 10, y: 70, width:50, height: 20))
        thLable.text = "2-t"
        thLable.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(thLable)
        
        self.thUidText = UITextField(frame: CGRect(x: 60, y: 70, width:300, height: 20))
        self.thUidText.text = self.devInfo["thUid"]
        self.thUidText.borderStyle = UITextField.BorderStyle.roundedRect
        self.thUidText.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(self.thUidText)
        
        let yqzLable:UILabel = UILabel.init(frame: CGRect(x: 10, y: 90, width:50, height: 20))
        yqzLable.text = "3-y"
        yqzLable.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(yqzLable)
        
        self.yqzUidText = UITextField(frame: CGRect(x: 60, y: 90, width:300, height: 20))
        self.yqzUidText.text = self.devInfo["yqzUid"]
        self.yqzUidText.borderStyle = UITextField.BorderStyle.roundedRect
        self.yqzUidText.font = UIFont.systemFont(ofSize: 13)
        self.view.addSubview(self.yqzUidText)
        
        
        self.logTextView = UITextView(frame: CGRect(x: 10, y: 130, width: 350, height: 200))
        self.logTextView.font = UIFont.systemFont(ofSize: 13)
        self.logTextView.backgroundColor = UIColor.lightGray
        self.logTextView.isEditable = false
        self.logTextView.isSelectable = false
        self.view.addSubview(self.logTextView)
        
        self.startBtn = UIButton(type: .custom)
        self.startBtn.frame = CGRect(x:(SCR_W - 100)/2, y:500, width: 100, height: 30)
        self.startBtn.setTitle("启动程序", for: .normal)
        self.startBtn.backgroundColor = UIColor.blue
        self.startBtn.addTarget(self, action: #selector(start), for: .touchUpInside)
        self.view.addSubview(self.startBtn)
    }
    
    
    
    @objc func start() {
        self.devInfo["udid"] = self.udidText.text!
        if self.devInfo["udid"]!.count < 1 {
            self.view.makeToast("缺少设备", duration: 3, position: .center)
            return
        }
        
        self.devInfo["xyUid"] = self.xyUidText.text!
        if self.devInfo["xyUid"]!.count < 1 {
            self.view.makeToast("缺少UID", duration: 3, position: .center)
            return
        }
        
        self.devInfo["thUid"] = self.thUidText.text!
        if self.devInfo["thUid"]!.count < 1 {
            self.view.makeToast("缺少UID", duration: 3, position: .center)
            return
        }
        
        self.devInfo["yqzUid"] = self.yqzUidText.text!
        if self.devInfo["yqzUid"]!.count < 1 {
            self.view.makeToast("缺少UID", duration: 3, position: .center)
            return
        }
        
        let userDefault = UserDefaults.standard
        userDefault.set(self.devInfo["udid"], forKey: "udid")
        userDefault.set(self.devInfo["xyUid"], forKey: "xyUid")
        userDefault.set(self.devInfo["thUid"], forKey: "thUid")
        userDefault.set(self.devInfo["yqzUid"], forKey: "yqzUid")
        
        self.startBtn.isHidden = true
        
        if self.checkValidRet == 1 {
            let xyThread = Thread(target: self, selector: #selector(xyRun), object: nil)
            let thThread = Thread(target: self, selector: #selector(thRun), object: nil)
            let yqzThread = Thread(target: self, selector: #selector(yqzRun), object: nil)
            xyThread.start()
            thThread.start()
            yqzThread.start()
        }
    }
    
    @objc func xyRun() {
        let xyPlat = PlatXy(dict: self.devInfo, logUI: self.logTextView!)
        xyPlat.run()
    }
    
    @objc func thRun() {
        let thPlat = PlatTh(dict: self.devInfo, logUI: self.logTextView!)
        thPlat.run()
    }
    
    @objc func yqzRun() {
        let yqzPlat = PlatYqz(dict: self.devInfo, logUI: self.logTextView!)
        yqzPlat.run()
    }
}
