import UIKit
import Flutter
import ExternalAccessory

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "zebra_print"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let printerChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    // 1) Register for EA connect/disconnect notifications (helps ensure discovery runs after pairing)
    EAAccessoryManager.shared().registerForLocalNotifications()
    NotificationCenter.default.addObserver(self, selector: #selector(onAccessoryDidConnect(_:)),
                                          name: .EAAccessoryDidConnect, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onAccessoryDidDisconnect(_:)),
                                          name: .EAAccessoryDidDisconnect, object: nil)

    printerChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {

      case "pairAccessory":
          // Option A: show all MFi accessories
          let nameFilter: NSPredicate? = nil

          // Option B: only show Zebra-ish names (uncomment to use)
          // let nameFilter = NSPredicate(format: "SELF CONTAINS[c] %@", "ZEBRA")

          EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nameFilter) { error in
            if let nsErr = error as NSError? {
              // Codes: 0 success (nil), 1 alreadyConnected, 2 notFound, 3 failed, 4 canceled
              print("[EA] Picker finished with code \(nsErr.code): \(nsErr.localizedDescription)")
            } else {
              print("[EA] Picker success (or already connected)")
            }

            // Give iOS a moment to post EAAccessoryDidConnect, then you're free to refresh from Flutter
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              result(nil) // <-- call result inside the completion block
            }
          }

      case "discoverPrinters":
        self.discoverMfiPrinters(result: result)

      case "sendZplToSerial":
        guard let args = call.arguments as? [String: Any],
              let serial = args["serialNumber"] as? String,
              let zpl = args["zpl"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing serialNumber/ZPL", details: nil))
          return
        }
        self.sendZpl(toSerial: serial, zpl: zpl, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 3) Discover paired MFi Zebra printers (look for BOTH protocols; include a debug dump)
  private func discoverMfiPrinters(result: @escaping FlutterResult) {
    let all = EAAccessoryManager.shared().connectedAccessories

    // Debug: see exactly what iOS sees
    all.forEach { a in
      print("[EA] name=\(a.name) model=\(a.modelNumber) sn=\(a.serialNumber) protos=\(a.protocolStrings)")
    }

    let zebras = all.filter {
      $0.protocolStrings.contains("com.zebra.rawport") ||
      $0.protocolStrings.contains("com.zebra.printer")
    }

    let list: [[String: Any]] = zebras.map {
      [
        "name": $0.name,
        "manufacturer": $0.manufacturer,
        "modelNumber": $0.modelNumber,
        "serialNumber": $0.serialNumber,
        "protocols": $0.protocolStrings
      ]
    }

    result(list)
  }

  // 4) Send ZPL using Link-OS MFiBtPrinterConnection with a SERIAL NUMBER
  private func sendZpl(toSerial serial: String, zpl: String, result: @escaping FlutterResult) {
    let conn = MfiBtPrinterConnection(serialNumber: serial)

    DispatchQueue.global().async {
      let opened = conn?.open() ?? false
      guard opened else {
        result(FlutterError(code: "OPEN_FAILED", message: "Failed to open printer connection", details: nil))
        return
      }

      var error: NSError?
      let bytes = conn?.write(zpl.data(using: .utf8), error: &error) ?? 0

      conn?.close()

      if bytes > 0 {
        result("ZPL sent successfully")
      } else {
        result(FlutterError(code: "SEND_FAILED", message: "Failed to send ZPL", details: error?.localizedDescription))
      }
    }
  }

  // 5) (Optional) React to connect/disconnect to refresh your Flutter list automatically
  @objc private func onAccessoryDidConnect(_ note: Notification) {
    print("[EA] Accessory connected: \(String(describing: (note.userInfo?[EAAccessoryKey] as? EAAccessory)?.name))")
    // You can notify Flutter to re-run discoverPrinters if you want.
  }

  @objc private func onAccessoryDidDisconnect(_ note: Notification) {
    print("[EA] Accessory disconnected: \(String(describing: (note.userInfo?[EAAccessoryKey] as? EAAccessory)?.name))")
  }
}
