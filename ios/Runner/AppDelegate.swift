import UIKit
import Flutter
import StatementTapFramework
import AppTrackingTransparency

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
  private let statementTapChannelName = "com.brankas.tap/statement"
    
  private var navigationController: UINavigationController!
    
  private var banks: [StatementBank] = []
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let statementTapChannel = FlutterMethodChannel(name: statementTapChannelName, binaryMessenger: controller.binaryMessenger)
      GeneratedPluginRegistrant.register(with: self)
      self.navigationController = UINavigationController(rootViewController: controller)
      self.window.rootViewController = self.navigationController
      self.navigationController.setNavigationBarHidden(true, animated: false)
      self.window.makeKeyAndVisible()
      
      // Comment out if App Tracking Transparency wants to be integrated
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
//                if #available(iOS 14, *) {
//                    ATTrackingManager.requestTrackingAuthorization { status in
//                        switch status {
//                            case .authorized:
//                                  statementTapChannel.invokeMethod("updateLogging", arguments: true)
//                            case .denied:
//                                  statementTapChannel.invokeMethod("updateLogging", arguments: false)
//                            default:
//                                  statementTapChannel.invokeMethod("updateLogging", arguments: false)
//                        }
//                    }
//                }
//            })

      
      statementTapChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
                
          switch call.method {
            case "checkout" :
              if let args = call.arguments as? Dictionary<String, Any> {
                  StatementTapSF.shared.initialize(apiKey: args["apiKey"] as? String ?? "", certPath: nil, isDebug: false, isLoggingEnabled: args["logging"] as? Bool ?? true)
                  
                  let countryCode = self.getCountry(country: args["country"] as? String ?? "")

                  let bankNames = args["banks"] as! [String]
                  let bankCodes = self.banks.filter { bank in
                      bankNames.contains(bank.title)
                  }.map {
                      $0.bankCode
                  }
                
                  var request = StatementTapRequest(country: countryCode, externalId: args["externalID"] as? String ?? "", successURL: args["successURL"] as? String ?? "", failURL: args["failURL"] as? String ?? "", organizationName: args["orgName"] as? String ?? "")
                  
                  
                  request.dismissAlert = DismissAlert(message: "Do you want to close the application?", confirmButtonText: "Yes", cancelButtonText: "No")
                  request.browserMode = StatementTapRequest.BrowserMode.WebView
                  request.useRememberMe = args["rememberMe"] as? Bool ?? false
                  request.isAutoConsent = args["autoConsent"] as? Bool ?? false
                  request.includeBalance = args["balanceRetrieval"] as? Bool ?? false
                  request.hasPdfUpload = args["pdfUpload"] as? Bool ?? false
                  request.bankCodes = bankCodes
                  
                  var startDate: Date? = nil
                  var endDate: Date? = nil
                  
                  if let start = args["startDate"] as? Int {
                    startDate = Date(timeIntervalSince1970: TimeInterval(start)/1000)
                  }
                  
                  if let end = args["endDate"] as? Int {
                    endDate = Date(timeIntervalSince1970: TimeInterval(end)/1000)
                  }
                  
                  if startDate != nil && endDate != nil {
                      request.statementRetrievalRequest = StatementRetrievalRequest(startDate: startDate!, endDate: endDate!)
                  }
                  
                  do {
                      let retrieveStatements = { (data: Any?, error: String?) in
                          self.setResult(data: data, error: error)
                      }
                      
                      try StatementTapSF.shared.checkoutWithinSameScreen(statementTapRequest: request, vc: controller, closure: retrieveStatements, showWithinSameScreen: false, showBackButton: true)
                  } catch {
                  }
            }
            case "getVersion":
                result(StatementTapSF.shared.getFrameworkVersion())
            case "getEnabledBanks":
                if let args = call.arguments as? Dictionary<String, Any> {
                    StatementTapSF.shared.initialize(apiKey: args["apiKey"] as? String ?? "", certPath: nil, isDebug: true, isLoggingEnabled: args["logging"] as? Bool ?? true)
                    let getBanks = { (bankList: [StatementBank], error: String?)  in
                        if !bankList.isEmpty {
                            self.banks = bankList
                            let bankNames = bankList.map { $0.title }
                            let bankCodes = bankList.map { $0.bankCode.value }
                            let bankIcons = bankList.map { $0.logoUrl }
                            let bankDetails: [[Any]] = [bankNames, bankCodes, bankIcons]
                            result(bankDetails)
                        }
                        else if let err = error {
                            self.showAlert(message: err)
                        }
                    }

                    StatementTapSF.shared.getEnabledBanks(country: self.getCountry(country: args["country"] as? String ?? ""), includeBalance: args["balanceRetrieval"] as? Bool ?? false, closure: getBanks)
                }
            default:
                result(FlutterMethodNotImplemented)
        }
      })
      
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    private func setResult(data: Any?, error: String?) {
        if let str = data as? String {
            if let err = error {
                showAlert(message: "Statement ID: \(str)\nError: \(err)")
            }
            else {
                showStatementList(statementId: str, message: "", statementResponse: nil)
            }
        } else if let response = data as? StatementResponse {
            if let statements = response.statementList {
                if statements.isEmpty {
                    showAlert(message: "Statement List\n\n\nList is Empty")
                    return
                }
                
                var message = ""
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM-dd-yyyy"
                
                statements.forEach { statement in
                    statement.transactions.forEach { transaction in
                        let amount = transaction.amount
                        message += "\n Account: \(statement.account.holderName)"
                        message += "\n Transaction: (\(dateFormatter.string(from: transaction.date))) "
                        message += String(describing: amount.currency)
                        message += " \((Double(amount.numInCents) ?? 0) / 100)"
                        message += " \(String(describing: transaction.type))"
                    }
                }
                
                showStatementList(statementId: response.statementId, message: message, statementResponse: response)
            }
            else if response.accountList != nil {
                buildAccounts(statementResponse: response)
            }
        } else {
            if let err = error {
                showAlert(message: "Error: \(err)")
            }
        }
    }
    
    private func showStatementList(statementId: String, message: String, statementResponse: StatementResponse?) {
        let controller = self.window?.rootViewController
        let alert = UIAlertController(title: "Statement List", message: message, preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: "Download Statement", style: UIAlertAction.Style.default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)

            StatementTapSF.shared.downloadStatement(vc: controller!, statementId: statementId, closure: { data, err in
                if nil == err {
                    self.showAlert(message: "Download successful")
                } else {
                    self.showAlert(message: err ?? "Download failed")
                }
                if let response = statementResponse {
                    self.buildAccounts(statementResponse: response)
                }
            }, enableSaving: true)
        }))

        alert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)
            if let response = statementResponse {
                self.buildAccounts(statementResponse: response)
            }
            else {
                self.showAlert(message: "Statement Retrieval Successful!\nStatement Id: \(statementId)")
            }
            
        }))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let controller = self.window?.rootViewController
            controller?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func buildAccounts(statementResponse: StatementResponse) {
        if let accounts = statementResponse.accountList {
            if accounts.isEmpty {
                showAlert(message: "Account List\n\n\nList is Empty")
                return
            }
            
            var accountMessage = ""
            
            accounts.forEach { account in
                accountMessage += "\n Account: \(account.holderName) (\(account.number))"
                accountMessage += "\n Balance: \(account.balance.currency)\(Double(account.balance.numInCents) ?? 0 / 100)"
            }
            
            showAccountList(balanceId: statementResponse.statementId, message: accountMessage)
        }
    }
    
    private func showAccountList(balanceId: String, message: String) {
        let alert = UIAlertController(title: "Account List", message: message, preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)
        }))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let controller = self.window?.rootViewController
            controller?.present(alert, animated: true, completion: nil)
        }
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)
        }))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let controller = self.window?.rootViewController
            controller?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getCountry(country: String) -> Country {
        switch country {
            case "Indonesia":
                return Country.ID
            case "Thailand":
                return Country.TH
            default:
                return Country.PH
        }
    }
}
