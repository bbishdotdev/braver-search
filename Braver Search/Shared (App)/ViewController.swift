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

    override func viewDidAppear() {
        super.viewDidAppear()
#if os(macOS)
        configureWindowLayout()
#endif
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
                    "description": option.description,
                    "price": StoreManager.shared.priceText(for: option),
                    "imageDataURL": imageDataURL(for: option.assetName) ?? "",
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

#if os(macOS)
    private func configureWindowLayout() {
        guard let window = view.window else {
            return
        }

        let minimumSize = NSSize(width: 760, height: 860)
        window.minSize = minimumSize

        let currentSize = window.frame.size
        guard currentSize.width < minimumSize.width || currentSize.height < minimumSize.height else {
            return
        }

        let frame = window.frame
        let targetSize = NSSize(
            width: max(frame.size.width, minimumSize.width),
            height: max(frame.size.height, minimumSize.height)
        )
        let newOrigin = NSPoint(
            x: frame.origin.x - ((targetSize.width - frame.size.width) / 2),
            y: frame.origin.y - (targetSize.height - frame.size.height)
        )

        window.setFrame(NSRect(origin: newOrigin, size: targetSize), display: true, animate: false)
    }

    private func imageDataURL(for assetName: String) -> String? {
        guard let image = NSImage(named: assetName) else {
            return nil
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }
#endif

}
