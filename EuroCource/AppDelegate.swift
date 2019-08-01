import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // consts
    let RateCategory = "DebitCardsTransfers"
    let FromCurrency = "EUR"
    let ToCurrency = "RUB"
    let TimerInterval = 300 as Double // every 5 minutes
    
    // strong reference to retain the status bar item object
	var statusItem: NSStatusItem?
    
    @IBOutlet weak var appMenu: NSMenu!
    
    @objc func displayMenu() {
        guard let button = statusItem?.button else { return }
        let x = button.frame.origin.x
        let y = button.frame.origin.y - 5
        let location = button.superview!.convert(NSMakePoint(x, y), to: nil)
        let w = button.window!
        let event = NSEvent.mouseEvent(with: .leftMouseUp,
                                       location: location,
                                       modifierFlags: NSEvent.ModifierFlags(rawValue: 0),
                                       timestamp: 0,
                                       windowNumber: w.windowNumber,
                                       context: w.graphicsContext,
                                       eventNumber: 0,
                                       clickCount: 1,
                                       pressure: 0)!
        NSMenu.popUpContextMenu(appMenu, with: event, for: button)
    }
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: -1)
        guard let button = statusItem?.button else {
            print("status bar item failed. Try removing some menu bar item.")
            NSApp.terminate(nil)
            return
        }
        button.action = #selector(displayMenu)
        button.target = self
        
        appMenu.insertItem(withTitle: "Update now",
                          action: #selector(updateCource), keyEquivalent: "U", at: 0)
        
        print("Create timer for every \(TimerInterval) sec")
        let _ = Timer.scheduledTimer(withTimeInterval: TimerInterval, repeats: true) { _ in
            print("in timer")
            self.updateCource()
        }
        
        updateCource()
    }
    
    @objc func updateCource() {
        print("===> Start update at \(Date())")
        
        guard let button = statusItem?.button else {
            print("Error: cant get button!! WTF?!")
            return
        }
        
        let url = URL(string: "https://www.tinkoff.ru/api/v1/currency_rates/")
        let request = URLRequest(url:url!)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error ?? "Unknown error")
                return
            }
            
            print("Show result for \(self.RateCategory) \(self.FromCurrency)->\(self.ToCurrency)")
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                guard let jsonObject = jsonResponse as? [String: Any] else {
                    print("Cant parse jsonResponse as [String: Any]")
                    print("jsonResponse: \(String(describing: jsonResponse))")
                    return
                }
                
                if jsonObject["resultCode"] as! String == "OK" {
                    let payload = jsonObject["payload"] as! [String: Any]
                    let rates = payload["rates"] as! [[String: Any]]
                    var found = false
                    for rate in rates {
                        if rate["category"] as? String == self.RateCategory {
                            let fromCurrency = rate["fromCurrency"] as! [String: Any]
                            let toCurrency = rate["toCurrency"] as! [String: Any]
                            let fromCurrencyName = fromCurrency["name"] as! String
                            let toCurrencyName = toCurrency["name"] as! String
                            
                            if fromCurrencyName == self.FromCurrency && toCurrencyName == self.ToCurrency {
                                print("rate[buy]: \(String(describing: rate["buy"]))")
                                let resNumber = rate["buy"] as? NSNumber ?? -1
                                let resString = String(format: "%.2f", resNumber.floatValue)
                                found = true
                                DispatchQueue.main.async { button.title = resString }
                            }
                        }
                    }
                    if !found {
                        print("Not found!")
                    }
                }
                else {
                    print("Result code is not OK!")
                }
            }
            catch let parsingError {
                print("Parsing error:", parsingError)
            }
        }
        task.resume()
    }
}
