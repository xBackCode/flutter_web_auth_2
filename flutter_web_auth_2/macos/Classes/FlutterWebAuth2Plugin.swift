import AuthenticationServices
import FlutterMacOS
import SafariServices

@available(OSX 10.15, *)
public class FlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    var lastSession: ASWebAuthenticationSession?
    var lastTimeStamp: TimeInterval?
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger)
        let instance = FlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate" {
            if let lastTimeStamp = lastTimeStamp {
                let currentTimeStamp = Date.timeIntervalSinceReferenceDate
                if currentTimeStamp - lastTimeStamp < 0.2 {
                    result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                    return
                }
            }

            let url = URL(string: (call.arguments as! [String: AnyObject])["url"] as! String)!
            let callbackURLScheme = (call.arguments as! [String: AnyObject])["callbackUrlScheme"] as! String
            let preferEphemeral = (call.arguments as! [String: AnyObject])["preferEphemeral"] as? Bool

            // 关闭上一个
            lastSession?.cancel()
            lastSession = nil

            var keepMe: Any?
            let completionHandler = { [weak self] (url: URL?, err: Error?) in
                keepMe = nil
                self?.lastTimeStamp = nil

                if let err = err {
                    if case ASWebAuthenticationSessionError.canceledLogin = err {
                        result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                        return
                    }

                    result(FlutterError(code: "EUNKNOWN", message: err.localizedDescription, details: nil))
                    return
                }

                result(url!.absoluteString)
            }

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
            session.prefersEphemeralWebBrowserSession = preferEphemeral ?? false

            guard
                let keyWindow = NSApplication.shared.keyWindow,
                let provider = keyWindow.contentViewController as? FlutterViewController
            else {
                result(FlutterError(code: "FAILED", message: "Failed to aquire root FlutterViewController", details: nil))
                return
            }

            session.presentationContextProvider = provider

            session.start()
            keepMe = session
            lastTimeStamp = Date.timeIntervalSinceReferenceDate
            lastSession = session
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}

@available(OSX 10.15, *)
extension FlutterViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}
