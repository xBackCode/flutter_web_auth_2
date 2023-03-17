import AuthenticationServices
import FlutterMacOS
import SafariServices

@available(OSX 10.15, *)
public class FlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    var authSession: AppleAuthenticationSession?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger)
        let instance = FlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate" {
            // exit(0)
            let a: String = nil
            let b = a!
            if let session = authSession {
                if let timestamp = session.timestamp, Date().timeIntervalSince1970 - timestamp > 1 {
                    // 老的 session 打开超过1s就关闭
                    session.cancel()
                    authSession = nil
                } else {
                    // 1s内重复点击直接忽略
                    return
                }
            }

            guard
                let arguments = call.arguments as? [String: AnyObject],
                let urlStr = arguments["url"] as? String,
                let url = URL(string: urlStr),
                let callbackURLScheme = arguments["callbackUrlScheme"] as? String,
                let preferEphemeral = arguments["preferEphemeral"] as? Bool
            else {
                result(FlutterError(code: "FAILED", message: "Failed to parse arguments FlutterChannel", details: nil))
                return
            }

            guard
                let keyWindow = NSApplication.shared.keyWindow,
                let provider = keyWindow.contentViewController as? FlutterViewController
            else {
                result(FlutterError(code: "FAILED", message: "Failed to aquire root FlutterViewController", details: nil))
                return
            }
            let session = AppleAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: preferEphemeral, presentationContextProvider: provider) { urlStr, error in
                if let error = error {
                    result(error)
                } else {
                    result(urlStr)
                }
            }
            if let error = session.start() {
                result(error)
                return
            }
            authSession = session
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

class AppleAuthenticationSession {
    typealias CompletionHandler = (String?, FlutterError?) -> Void

    private var authSession: ASWebAuthenticationSession?

    var url: URL
    var callbackURLScheme: String?
    var prefersEphemeralWebBrowserSession: Bool?
    var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?
    var completionHandler: AppleAuthenticationSession.CompletionHandler?
    var timestamp: TimeInterval?

    init(url URL: URL, callbackURLScheme: String?, prefersEphemeralWebBrowserSession: Bool? = nil, presentationContextProvider: ASWebAuthenticationPresentationContextProviding? = nil, completionHandler: AppleAuthenticationSession.CompletionHandler?) {
        self.url = URL
        self.callbackURLScheme = callbackURLScheme
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
        self.presentationContextProvider = presentationContextProvider
        self.completionHandler = completionHandler
        self.timestamp = Date().timeIntervalSince1970
    }

    deinit {
        completionHandler = nil
        presentationContextProvider = nil
        timestamp = nil
        authSession = nil
    }

    func start() -> FlutterError? {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: { [weak self] URL, error in
            guard let self = self, let completionHandler = self.completionHandler else { return }
            var flutterError: FlutterError?
            if let error = error {
                if case ASWebAuthenticationSessionError.canceledLogin = error {
                    flutterError = FlutterError(code: "CANCELED", message: "User canceled login", details: nil)
                } else {
                    flutterError = FlutterError(code: "EUNKNOWN", message: error.localizedDescription, details: nil)
                }
            }
            completionHandler(URL?.absoluteString, flutterError)
        })
        if let prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession {
            session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
        }
        if let presentationContextProvider = presentationContextProvider {
            session.presentationContextProvider = presentationContextProvider
        }

        guard session.sessionCanStart else {
            return FlutterError(code: "FAILED", message: "Failed to start Authentication", details: "canStart() returns false")
        }
        guard session.start() else {
            return FlutterError(code: "FAILED", message: "Failed to start Authentication", details: "start() returns false")
        }

        authSession = session

        return nil
    }

    func cancel() {
        authSession?.cancel()
        authSession = nil
    }
}

extension ASWebAuthenticationSession {
    var sessionCanStart: Bool {
        if #available(macOS 10.15.4, *) {
            return canStart
        }
        return true
    }
}

