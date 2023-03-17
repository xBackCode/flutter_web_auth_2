import FlutterMacOS

@available(OSX 10.15, *)
public class FlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    let URLSchemeNotificationName = "FlutterWebAuth2_URLScheme_notification"
    var flutterResult: FlutterResult?

    override public init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handelURLScheme), name: Notification.Name(URLSchemeNotificationName), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func handelURLScheme(_ notification: Notification) {
        defer { self.flutterResult = nil }
        if let path = notification.userInfo?["info"] as? String {
            flutterResult?(path)
        } else {
            flutterResult?(FlutterError(code: "FAILED", message: "Failed to get path from URL Scheme callback", details: nil))
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger)
        let instance = FlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate" {
            guard
                let arguments = call.arguments as? [String: AnyObject],
                let urlStr = arguments["url"] as? String,
                let url = URL(string: urlStr)
            else {
                result(FlutterError(code: "FAILED", message: "Failed to parse arguments FlutterChannel", details: nil))
                return
            }
            guard NSWorkspace.shared.open(url) else {
                result(FlutterError(code: "FAILED", message: "Failed to open authenticate URL", details: nil))
                return
            }
            flutterResult = result
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}

