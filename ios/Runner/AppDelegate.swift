import UIKit
import Flutter
import DirectTapFramework

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
  private let directTapChannelName = "com.brankas.tap/direct"
    
  private var navigationController: UINavigationController!
    
  private var banks: [DirectBank] = []
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let directTapChannel = FlutterMethodChannel(name: directTapChannelName, binaryMessenger: controller.binaryMessenger)
      GeneratedPluginRegistrant.register(with: self)
      self.navigationController = UINavigationController(rootViewController: controller)
      self.window.rootViewController = self.navigationController
      self.navigationController.setNavigationBarHidden(true, animated: false)
      self.window.makeKeyAndVisible()
      
      directTapChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
                
          switch call.method {
            case "checkout" :
              if let args = call.arguments as? Dictionary<String, Any> {
                  DirectTapSF.shared.initialize(apiKey: args["apiKey"] as? String ?? "", certPath: nil, isDebug: false)
                  
                  let bankCode = args["sourceBank"] as? Int
                  var bank: DirectBankCode? = nil

                  if !self.banks.isEmpty {
                      bank = self.banks.first { $0.bankCode.value == bankCode }?.bankCode
                  }
                  
                  let countryCode = self.getCountry(country: args["country"] as? String ?? "")
                  let currency = countryCode == Country.PH ? Currency.php : Currency.idr
                  let amountVal = String(Int((Double(args["amount"] as? String ?? "0.0") ?? 0.0) * 100))
                  
                  let account = DirectAccount(country: countryCode, bankCode: bank)
                  let amount = Amount(currency: currency, numInCents: amountVal)
                  
                  let customer = Customer(firstName: args["firstName"] as? String ?? "", lastName: args["lastName"] as? String ?? "", email: args["email"] as? String ?? "", mobileNumber: args["mobileNumber"] as? String ?? "")
                  
                  
                  var client = Client()
                  client.displayName = args["orgName"] as? String ?? ""
                  client.returnUrl = args["returnURL"] as? String ?? ""
                  client.failUrl = args["failURL"] as? String ?? ""
                  
                  let referenceID = args["referenceId"] as? String ?? ""
                  
                  var request = DirectTapRequest(sourceAccount: account, destinationAccountId: args["destinationAccountId"] as? String ?? "", amount: amount, memo: args["memo"] as? String ?? "", customer: customer, referenceId: referenceID, client: client)
                  
                  request.dismissAlert = DismissAlert(message: "Do you want to close the application?", confirmButtonText: "Yes", cancelButtonText: "No")
                  request.browserMode = DirectTapRequest.BrowserMode.WebView
                  request.useRememberMe = args["rememberMe"] as? Bool ?? false
                  
                  if let date = args["expiryDate"] as? Int {
                      request.expiryDate = Date(timeIntervalSince1970: TimeInterval(date)/1000)
                  }
                  
                  do {
                      let retrieveTransactions = { (transaction: Transaction?, error: String?) in
                          self.setResult(data: transaction, error: error)
                      }
                      try DirectTapSF.shared.checkoutWithinSameScreen(tapRequest: request, vc: controller, closure: retrieveTransactions, showWithinSameScreen: false, showBackButton: true)
                  } catch {
                  }
            }
            case "getVersion":
                result(DirectTapSF.shared.getFrameworkVersion())
            case "getBanks":
                if let args = call.arguments as? Dictionary<String, Any> {
                    DirectTapSF.shared.initialize(apiKey: args["apiKey"] as? String ?? "", certPath: nil, isDebug: false)
                    let getBanks = { (bankList: [DirectBank], error: String?)  in
                        if !bankList.isEmpty {
                            self.banks = bankList.filter{ $0.isEnabled }
                            let bankNames = self.banks.map { $0.title }
                            let bankCodes = self.banks.map { $0.bankCode.value }
                            let bankIcons = self.banks.map { $0.logoUrl }
                            let bankDetails: [[Any]] = [bankNames, bankCodes, bankIcons]
                            result(bankDetails)
                        }
                        else if let err = error {
                            self.showAlert(message: err)
                        }
                    }

                    DirectTapSF.shared.getSourceBanks(country: self.getCountry(country: args["country"] as? String ?? ""), destinationBank: self.getBankCode(bank: args["bank"] as? String ?? ""), closure: getBanks)
                }
            default:
                result(FlutterMethodNotImplemented)
        }
      })
      
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    func setResult(data: Transaction?, error: String?) {
        if let transaction = data {
            let date = DateFormatter()
            date.dateFormat = "MMMM dd YYYY"
            
            let bankFee = Float(transaction.bankFee.numInCents) ?? 0 / 100
            let amount = Float(transaction.amount.numInCents) ?? 0 / 100
            let finishedDate = date.string(from: transaction.finishedDate)
            
            let fee = "\(transaction.bankFee.currency) \(bankFee)"
            let payment = "\(transaction.amount.currency) \(amount)"
            
            showAlert(message: "TRANSACTION (\(transaction.id))\nReference ID: \(transaction.referenceId)\nStatus: \(transaction.status)\nStatus Code: \(transaction.statusMessage ?? "") (\(transaction.statusCode))\nBank: \(transaction.bankCode) (\(transaction.country))\nAmount: \(payment)\nBank Fee:\(fee)\nDate: \(finishedDate)")
        }
        
        if let message = error {
            showAlert(message: "Error: \(message)")
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
            default:
                return Country.PH
        }
    }

    private func getBankCode(bank: String) -> DirectBankCode {
        switch bank {
            case "BDO": return DirectBankCode.BDO
            case "BPI": return DirectBankCode.BPI
            case "EastWest": return DirectBankCode.EAST_WEST
            case "LandBank": return DirectBankCode.LAND_BANK
            case "MetroBank": return DirectBankCode.MB
            case "PNB": return DirectBankCode.PNB
            case "RCBC": return DirectBankCode.RCBC
            case "UnionBank": return DirectBankCode.UB
            case "BCA": return DirectBankCode.BCA
            case "BNI": return DirectBankCode.BNI
            case "BRI": return DirectBankCode.BRI
            case "Mandiri": return DirectBankCode.Mandiri
            default: return DirectBankCode.BDO
        }
    }
}
