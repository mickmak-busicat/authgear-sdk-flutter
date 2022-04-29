import Flutter
import UIKit
import AuthenticationServices
import LocalAuthentication
import CommonCrypto

public class SwiftAuthgearPlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_authgear", binaryMessenger: registrar.messenger())
    let instance = SwiftAuthgearPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authenticate":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let urlString = arguments["url"] as! String
      let redirectURIString = arguments["redirectURI"] as! String
      let preferEphemeral = arguments["preferEphemeral"] as! Bool
      let url = URL(string: urlString)!
      let redirectURI = URL(string: redirectURIString)!
      self.authenticate(url: url, redirectURI: redirectURI, preferEphemeral: preferEphemeral, result: result)
    case "openURL":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let urlString = arguments["url"] as! String
      let url = URL(string: urlString)!
      self.openURL(url: url, result: result);
    case "getDeviceInfo":
      self.getDeviceInfo(result: result)
    case "storageSetItem":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let key = arguments["key"] as! String
      let value = arguments["value"] as! String
      self.storageSetItem(key: key, value: value, result: result)
    case "storageGetItem":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let key = arguments["key"] as! String
      self.storageGetItem(key: key, result: result)
    case "storageDeleteItem":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let key = arguments["key"] as! String
      self.storageDeleteItem(key: key, result: result)
    case "generateUUID":
      self.generateUUID(result: result)
    case "checkBiometricSupported":
      self.checkBiometricSupported(result: result)
    case "createBiometricPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      self.createBiometricPrivateKey(arguments: arguments, result: result)
    case "removeBiometricPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let kid = arguments["kid"] as! String
      self.removeBiometricPrivateKey(kid: kid, result: result)
    case "signWithBiometricPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let kid = arguments["kid"] as! String
      let payload = arguments["payload"] as! [String: Any]
      self.signWithBiometricPrivateKey(kid: kid, payload: payload, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authenticate(url: URL, redirectURI: URL, preferEphemeral: Bool, result: @escaping FlutterResult) {
    var sessionToKeepAlive: Any? = nil
    let completionHandler = { (url: URL?, error: Error?) in
      sessionToKeepAlive = nil
      if let error = error {
        if #available(iOS 12, *) {
          if case ASWebAuthenticationSessionError.canceledLogin = error {
            result(FlutterError.cancel)
            return
          }
        }

        self.handleError(result: result, error: error)
        return
      }

      if let url = url {
        result(url.absoluteString)
        return
      }

      result(FlutterError.unreachable)
      return
    }

    if #available(iOS 12, *) {
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: redirectURI.scheme,
        completionHandler: completionHandler
      )
      if #available(iOS 13, *) {
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = preferEphemeral
      }
      session.start()
      sessionToKeepAlive = session
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func openURL(url: URL, result: @escaping FlutterResult) {
    var sessionToKeepAlive: Any? = nil
    let completionHandler = { (url: URL?, error: Error?) in
      sessionToKeepAlive = nil
      if let error = error {
        if #available(iOS 12, *) {
          if case ASWebAuthenticationSessionError.canceledLogin = error {
            result(nil)
            return
          }
        }

        self.handleError(result: result, error: error)
        return
      }

      result(FlutterError.unreachable)
      return
    }
    if #available(iOS 12, *) {
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: "nocallback",
        completionHandler: completionHandler
      )
      if #available(iOS 13, *) {
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
      }
      session.start()
      sessionToKeepAlive = session
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func getDeviceInfo(result: FlutterResult) {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let nodename = withUnsafePointer(to: &systemInfo.nodename) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let release = withUnsafePointer(to: &systemInfo.release) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let sysname = withUnsafePointer(to: &systemInfo.sysname) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let version = withUnsafePointer(to: &systemInfo.version) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!

    let unameDict = [
      "machine": machine,
      "nodename": nodename,
      "release": release,
      "sysname": sysname,
      "version": version,
    ]

    let uiDeviceDict = [
      "name": UIDevice.current.name,
      "systemName": UIDevice.current.systemName,
      "systemVersion": UIDevice.current.systemVersion,
      "model": UIDevice.current.model,
      "userInterfaceIdiom": UIDevice.current.userInterfaceIdiom.name,
    ]

    var nsProcessInfoDict = [
      "isMacCatalystApp": false,
      "isiOSAppOnMac": false,
    ]
    if #available(iOS 13, *) {
      let info = ProcessInfo.processInfo
      nsProcessInfoDict["isMacCatalystApp"] = info.isMacCatalystApp
      if #available(iOS 14, *) {
        nsProcessInfoDict["isiOSAppOnMac"] = info.isiOSAppOnMac
      }
    }

    let infoDictionary = Bundle.main.infoDictionary!
    let nsBundleDict = [
      "CFBundleIdentifier": infoDictionary["CFBundleIdentifier"],
      "CFBundleName": infoDictionary["CFBundleName"],
      "CFBundleDisplayName": infoDictionary["CFBundleDisplayName"],
      "CFBundleExecutable": infoDictionary["CFBundleExecutable"],
      "CFBundleShortVersionString": infoDictionary["CFBundleShortVersionString"],
      "CFBundleVersion": infoDictionary["CFBundleVersion"],
    ]

    let iosDict = [
      "uname": unameDict,
      "UIDevice": uiDeviceDict,
      "NSProcessInfo": nsProcessInfoDict,
      "NSBundle": nsBundleDict,
    ]

    let root = [
      "ios": iosDict,
    ]

    result(root)
  }

  private func storageSetItem(key: String, value: String, result: FlutterResult) {
    let data = value.data(using: .utf8)!
    let updateQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
    let update: [String: Any] = [
      kSecValueData as String: data,
    ]

    let updateStatus = SecItemUpdate(updateQuery as CFDictionary, update as CFDictionary)
    switch updateStatus {
    case errSecSuccess:
      result(nil)
    default:
      let addQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
      ]

      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      switch addStatus {
      case errSecSuccess:
        result(nil)
      default:
        result(FlutterError(status: addStatus))
      }
    }
  }

  private func storageGetItem(key: String, result: FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]

    var item: CFTypeRef?
    let status = withUnsafeMutablePointer(to: &item) {
      SecItemCopyMatching(query as CFDictionary, $0)
    }

    switch status {
    case errSecSuccess:
      let value = String(data: item as! Data, encoding: .utf8)
      result(value)
    case errSecItemNotFound:
      result(nil)
    default:
      result(FlutterError(status: status))
    }
  }

  private func storageDeleteItem(key: String, result: FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]

    let status = SecItemDelete(query as CFDictionary)
    switch status {
    case errSecSuccess:
      result(nil)
    case errSecItemNotFound:
      result(nil)
    default:
      result(FlutterError(status: status))
    }
  }

  private func generateUUID(result: FlutterResult) {
    let uuid = UUID().uuidString
    result(uuid)
  }

  private func checkBiometricSupported(result: @escaping FlutterResult) {
    if #available(iOS 11.3, *) {
      let laContext = LAContext()
      var nsError: NSError? = nil
      _ = laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError)
      if let nsError = nsError {
        result(FlutterError(nsError: nsError))
      } else {
        result(nil)
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func createBiometricPrivateKey(arguments: [String: AnyObject], result: @escaping FlutterResult) {
    let kid = arguments["kid"] as! String
    let payload = arguments["payload"] as! [String: Any]
    let ios = arguments["ios"] as! [String: Any]
    let constraint = ios["constraint"] as! String
    let localizedReason = ios["localizedReason"] as! String
    let tag = "com.authgear.keys.biometric.\(kid)"

    if #available(iOS 11.3, *) {
      let flags = SecAccessControlCreateFlags(constraint: constraint)
      let laContext = LAContext()
      laContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: localizedReason) { _, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(error: error))
            return
          }

          switch self.generateBiometricPrivateKey() {
          case .failure(let error):
            result(FlutterError(error: error))
            return
          case .success(let secKey):
            if let error = self.addBiometricPrivateKey(privateKey: secKey, tag: tag, flags: flags) {
              result(FlutterError(error: error))
              return
            }

            switch self.signBiometricJWT(privateKey: secKey, kid: kid, payload: payload) {
            case .failure(let error):
              result(FlutterError(error: error))
              return
            case .success(let jwt):
              result(jwt)
              return
            }
          }
        }
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func removeBiometricPrivateKey(kid: String, result: FlutterResult) {
    let tag = "com.authgear.keys.biometric.\(kid)"
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: tag,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      result(FlutterError(status: status))
      return
    }

    result(nil)
  }

  private func signWithBiometricPrivateKey(kid: String, payload: [String: Any], result: FlutterResult) {
    if #available(iOS 10.0, *) {
      switch self.getBiometricPrivateKey(kid: kid) {
      case .failure(let error):
        result(FlutterError(error: error))
      case .success(let privateKey):
        switch self.signBiometricJWT(privateKey: privateKey, kid: kid, payload: payload) {
        case .failure(let error):
          result(FlutterError(error: error))
        case .success(let jwt):
          result(jwt)
        }
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  @available(iOS 11.3, *)
  private func generateBiometricPrivateKey() -> Result<SecKey, Error> {
    var error: Unmanaged<CFError>?
    let query: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: 2048,
    ]
    let secKey = SecKeyCreateRandomKey(query as CFDictionary, &error)
    guard let secKey = secKey else {
      return Result.failure(error!.takeRetainedValue() as Error)
    }
    return Result.success(secKey)
  }

  private func addBiometricPrivateKey(privateKey: SecKey, tag: String, flags: SecAccessControlCreateFlags) -> Error? {
    let laContext = LAContext()

    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      flags,
      &error
    ) else {
      return error!.takeRetainedValue() as Error
    }

    let query: [String: Any] = [
      kSecValueRef as String: privateKey,
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrAccessControl as String: accessControl,
      kSecUseAuthenticationContext as String: laContext,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      return NSError(osStatus: status)
    }

    return nil
  }

  private func getBiometricPrivateKey(kid: String) -> Result<SecKey, Error> {
    let tag = "com.authgear.keys.biometric.\(kid)"
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: tag,
      kSecReturnRef as String: true,
    ]

    var item: CFTypeRef?
    let status = withUnsafeMutablePointer(to: &item) {
      SecItemCopyMatching(query as CFDictionary, $0)
    }

    guard status == errSecSuccess else {
      return .failure(NSError(osStatus: status))
    }

    return .success(item as! SecKey)
  }

  @available(iOS 10.0, *)
  private func signBiometricJWT(privateKey: SecKey, kid: String, payload: [String: Any]) -> Result<String, Error> {
    var jwk: [String: Any] = [:]
    jwk["kid"] = kid

    if let error = getJWKFromPrivateKey(privateKey: privateKey, jwk: &jwk) {
      return .failure(error)
    }

    let header = makeBiometricJWTHeader(jwk: jwk)
    return signJWT(privateKey: privateKey, header: header, payload: payload)
  }

  @available(iOS 10.0, *)
  private func getJWKFromPrivateKey(privateKey: SecKey, jwk: inout [String: Any]) -> Error? {
    var error: Unmanaged<CFError>?

    let publicKey = SecKeyCopyPublicKey(privateKey)!
    guard let cfData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
      return error!.takeRetainedValue() as Error
    }

    let data = cfData as Data

    let n = data.subdata(in: Range(NSRange(location: data.count > 269 ? 9 : 8, length: 256))!)
    let e = data.subdata(in: Range(NSRange(location: data.count - 3, length: 3))!)

    jwk["alg"] = "RS256";
    jwk["kty"] = "RSA";
    jwk["n"] = n.base64urlEncodedString()
    jwk["e"] = e.base64urlEncodedString()

    return nil
  }

  private func makeBiometricJWTHeader(jwk: [String: Any]) -> [String: Any] {
    return [
      "typ": "vnd.authgear.biometric-request",
      "kid": jwk["kid"]!,
      "alg": jwk["alg"]!,
      "jwk": jwk,
    ]
  }

  @available(iOS 10.0, *)
  private func signJWT(privateKey: SecKey, header: [String: Any], payload: [String: Any]) -> Result<String, Error> {
    let headerJSON = JSONSerialization.serialize(value: header)
    let payloadJSON = JSONSerialization.serialize(value: payload)
    let headerString = headerJSON.base64EncodedString()
    let payloadString = payloadJSON.base64EncodedString()
    let strToSign = "\(headerString).\(payloadString)"
    let dataToSign = strToSign.data(using: .utf8)!
    switch self.signData(privateKey: privateKey, data: dataToSign) {
    case .failure(let error):
      return .failure(error)
    case .success(let signature):
      let signatureStr = signature.base64EncodedString()
      let jwt = "\(strToSign).\(signatureStr)"
      return .success(jwt)
    }
  }

  @available(iOS 10.0, *)
  private func signData(privateKey: SecKey, data: Data) -> Result<Data, Error> {
    var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
    }
    var error: Unmanaged<CFError>?
    guard let signedData = SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(buffer) as CFData, &error) else {
      return .failure(error!.takeRetainedValue() as Error)
    }

    return .success(signedData as Data)
  }

  @available(iOS 12.0, *)
  public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
  }

  private func handleError(result: FlutterResult, error: Error) {
    let nsError = error as NSError
    result(FlutterError(
      code: String(nsError.code),
      message: nsError.localizedDescription,
      details: nsError.userInfo
    ))
  }
}

fileprivate extension JSONSerialization {
  static func serialize(value: Any) -> Data {
    let data = try? JSONSerialization.data(withJSONObject: value, options: [])
    return data!
  }
}

fileprivate extension Data {
  func base64urlEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

fileprivate extension SecAccessControlCreateFlags {
  @available(iOS 11.3, *)
  init(constraint: String) {
    switch (constraint) {
    case "biometryAny":
      self = [.biometryAny]
    case "biometryCurrentSet":
      self = [.biometryCurrentSet]
    case "userPresence":
      self = [.userPresence]
    default:
      self = []
    }
  }
}

fileprivate extension NSError {
  convenience init(osStatus: OSStatus) {
    self.init(domain: NSOSStatusErrorDomain, code: Int(osStatus), userInfo: nil)
  }
}

fileprivate extension FlutterError {
  static var unreachable: FlutterError {
    return FlutterError(code: "UNREACHABLE", message: "unreachable", details: nil)
  }

  static var cancel: FlutterError {
    return FlutterError(code: "CANCEL", message: "cancel", details: nil)
  }

  static var unsupported: FlutterError {
    return FlutterError(code: "UNSUPPORTED", message: "flutter_authgear supports iOS >= 12", details: nil)
  }

  convenience init(status: OSStatus) {
    let nsError = NSError(osStatus: status)
    var message = String(status)
    if #available(iOS 11.3, *) {
      if let s = SecCopyErrorMessageString(status, nil) {
        message = s as String
      }
    }
    self.init(code: String(nsError.code), message: message, details: nil)
  }

  convenience init(nsError: NSError) {
    self.init(code: String(nsError.code), message: nsError.localizedDescription, details: nsError.userInfo)
  }

  convenience init(error: Error) {
    let nsError = error as NSError
    self.init(nsError: nsError)
  }
}

fileprivate extension UIUserInterfaceIdiom {
  var name: String {
    switch self {
    case .unspecified:
      return "unspecified"
    case .phone:
      return "phone"
    case .pad:
      return "pad"
    case .tv:
      return "tv"
    case .carPlay:
      return "carPlay"
    case .mac:
      return "mac"
    default:
      return "unknown"
    }
  }
}
