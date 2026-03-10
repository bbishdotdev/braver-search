//
//  ViewController.swift
//  Shared (App)
//
//  Created by Brenden Bishop on 1/18/25.
//

import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
#elseif os(macOS)
import Cocoa
import SafariServices
typealias PlatformViewController = NSViewController
#endif

let extensionBundleIdentifier = "xyz.bsquared.Braver-Search.Extension"

class ViewController: PlatformViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!

    private var monetizationObserver: NSObjectProtocol?
    private var supportFlowObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView.navigationDelegate = self

#if os(iOS)
        self.webView.scrollView.isScrollEnabled = false
#endif

        self.webView.configuration.userContentController.add(self, name: "controller")

        self.webView.loadFileURL(Bundle.main.url(forResource: "Main", withExtension: "html")!, allowingReadAccessTo: Bundle.main.resourceURL!)

        monetizationObserver = NotificationCenter.default.addObserver(
            forName: .monetizationStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMonetizationUI()
        }

        supportFlowObserver = NotificationCenter.default.addObserver(
            forName: .openSupportFlow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.focusSupportUI()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
#if os(iOS)
        webView.evaluateJavaScript("show('ios')")
#elseif os(macOS)
        webView.evaluateJavaScript("show('mac')")

        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (state, error) in
            guard let state = state, error == nil else {
                // Insert code to inform the user that something went wrong.
                return
            }

            DispatchQueue.main.async {
                if #available(macOS 13, *) {
                    webView.evaluateJavaScript("show('mac', \(state.isEnabled), true)")
                } else {
                    webView.evaluateJavaScript("show('mac', \(state.isEnabled), false)")
                }
                self.updateMonetizationUI()
            }
        }
#endif
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
#if os(macOS)
        if let action = message.body as? String, action == "open-preferences" {
            SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
                guard error == nil else {
                    return
                }

                DispatchQueue.main.async {
                    NSApp.terminate(self)
                }
            }
            return
        }

        guard let payload = message.body as? [String: Any],
              let action = payload["action"] as? String else {
            return
        }

        switch action {
        case "open-review":
            NSWorkspace.shared.open(MonetizationConfig.reviewURL)
        case "purchase":
            guard let productID = payload["productId"] as? String,
                  let option = MonetizationConfig.donationOptions.first(where: { $0.id == productID }) else {
                return
            }

            Task {
                await StoreManager.shared.purchase(option: option)
                await MainActor.run {
                    self.updateMonetizationUI()
                }
            }
        default:
            return
        }
#endif
    }

    deinit {
        if let monetizationObserver {
            NotificationCenter.default.removeObserver(monetizationObserver)
        }

        if let supportFlowObserver {
            NotificationCenter.default.removeObserver(supportFlowObserver)
        }
    }

    private func updateMonetizationUI() {
#if os(macOS)
        let payload: [String: Any] = [
            "canTip": MonetizationManager.shared.canShowSupport,
            "hasDonated": MonetizationManager.shared.hasDonated,
            "reviewURL": MonetizationConfig.reviewURL.absoluteString,
            "products": MonetizationConfig.donationOptions.map { option in
                [
                    "id": option.id,
                    "displayName": option.displayName,
                    "price": StoreManager.shared.priceText(for: option),
                ]
            },
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("updateMonetization(\(json))")
#endif
    }

    private func focusSupportUI() {
#if os(macOS)
        updateMonetizationUI()
        webView.evaluateJavaScript("focusSupportSection()")
#endif
    }

}
