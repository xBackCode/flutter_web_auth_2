import Flutter
import UIKit
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(SafariServices)
import SafariServices
#endif

protocol AppleuthenticationSessionProtocol: NSObjectProtocol {
    @discardableResult
    func startSession() -> Bool

    func cancelSession()

    func canStartSession() -> Bool
}

#if canImport(AuthenticationServices)

extension ASWebAuthenticationSession: AppleuthenticationSessionProtocol {
    func startSession() -> Bool {
        return start()
    }

    func cancelSession() {
        cancel()
    }

    func canStartSession() -> Bool {
        if #available(iOS 13.4, *) {
            return canStart
        }
        return true
    }
}

#endif

#if canImport(SafariServices)

extension SFAuthenticationSession: AppleuthenticationSessionProtocol {
    func startSession() -> Bool {
        return start()
    }

    func cancelSession() {
        cancel()
    }

    func canStartSession() -> Bool {
        return true
    }
}

#endif

public class SwiftFlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    var sessionToKeepAlive: AppleuthenticationSessionProtocol?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    var completionHandler: ((URL?, Error?) -> Void)?

    private func destroySession() {
        sessionToKeepAlive?.cancelSession()
        sessionToKeepAlive = nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate",
           let arguments = call.arguments as? [String: AnyObject],
           let urlString = arguments["url"] as? String,
           let url = URL(string: urlString),
           let callbackURLScheme = arguments["callbackUrlScheme"] as? String,
           let preferEphemeral = arguments["preferEphemeral"] as? Bool
        {
            destroySession()
            completionHandler = { [weak self] (url: URL?, err: Error?) in
                self?.completionHandler = nil
                self?.destroySession()

                if let err = err {
                    if #available(iOS 12, *) {
                        if case ASWebAuthenticationSessionError.canceledLogin = err {
                            result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            return
                        }
                    }

                    if #available(iOS 11, *) {
                        if case SFAuthenticationError.canceledLogin = err {
                            result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            return
                        }
                    }

                    result(FlutterError(code: "EUNKNOWN", message: err.localizedDescription, details: nil))
                    return
                }

                guard let url = url else {
                    result(FlutterError(code: "EUNKNOWN", message: "URL was null, but no error provided.", details: nil))
                    return
                }

                result(url.absoluteString)
            }

            if #available(iOS 12, *) {
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler!)

                if #available(iOS 13, *) {
                    var rootViewController: UIViewController?

                    // FlutterViewController
                    if rootViewController == nil {
                        rootViewController = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController
                    }

                    // UIViewController
                    if rootViewController == nil {
                        rootViewController = UIApplication.shared.keyWindow?.rootViewController
                    }

                    // ACQUIRE_ROOT_VIEW_CONTROLLER_FAILED
                    if rootViewController == nil {
                        result(FlutterError.acquireRootViewControllerFailed)
                        return
                    }

                    while let presentedViewController = rootViewController!.presentedViewController {
                        rootViewController = presentedViewController
                    }
                    if let nav = rootViewController as? UINavigationController {
                        rootViewController = nav.visibleViewController ?? rootViewController
                    }

                    guard let contextProvider = rootViewController as? ASWebAuthenticationPresentationContextProviding else {
                        result(FlutterError.acquireRootViewControllerFailed)
                        return
                    }
                    session.presentationContextProvider = contextProvider
                    session.prefersEphemeralWebBrowserSession = preferEphemeral
                }

                sessionToKeepAlive = session
            } else if #available(iOS 11, *) {
                let session = SFAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler!)
                sessionToKeepAlive = session
            } else {
                result(FlutterError(code: "FAILED", message: "This plugin does currently not support iOS lower than iOS 11", details: nil))
            }
            sessionToKeepAlive?.startSession()
        } else if call.method == "cleanUpDanglingCalls" {
            // we do not keep track of old callbacks on iOS, so nothing to do here
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]) -> Void) -> Bool
    {
        switch userActivity.activityType {
            case NSUserActivityTypeBrowsingWeb:
                guard let url = userActivity.webpageURL, let completionHandler = completionHandler else {
                    return false
                }
                completionHandler(url, nil)
                return true
            default: return false
        }
    }
}

@available(iOS 13, *)
extension FlutterViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

private extension FlutterError {
    static var acquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "ACQUIRE_ROOT_VIEW_CONTROLLER_FAILED", message: "Failed to acquire root view controller", details: nil)
    }
}

