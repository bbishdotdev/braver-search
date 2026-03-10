//
//  MainView.swift
//  Braver Search
//
//  Created by Brenden Bishop on 1/19/25.
//

import SwiftUI
import os.log

struct MainView: View {
    @State private var isEnabled: Bool
    @State private var isShowingSupportSheet = false
    @StateObject private var monetization = MonetizationManager.shared
    @StateObject private var store = StoreManager.shared
    private let userDefaults: UserDefaults
    
    init() {
        let defaults = UserDefaults(suiteName: "group.xyz.bsquared.braversearch")!
        self.userDefaults = defaults
        
        // Initialize state from UserDefaults
        if defaults.object(forKey: "enabled") == nil {
            defaults.set(true, forKey: "enabled")
            defaults.synchronize()
            self._isEnabled = State(initialValue: true)
        } else {
            self._isEnabled = State(initialValue: defaults.bool(forKey: "enabled"))
        }
        
        os_log(.debug, "Braver Search: Initialized with enabled = %{public}@", String(describing: self._isEnabled.wrappedValue))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Braver Search", isOn: $isEnabled)
                        .onChange(of: isEnabled) { newValue in
                            os_log(.debug, "Braver Search: Toggle changed to %{public}@", String(describing: newValue))
                            userDefaults.set(newValue, forKey: "enabled")
                            userDefaults.synchronize()
                            IOSAppAnalytics.track(
                                "redirect_setting_changed",
                                properties: [
                                    "enabled": newValue,
                                    "surface": "ios_app",
                                ]
                            )
                        }
                } header: {
                    Text("Settings")
                } footer: {
                    Text("When enabled, searches from Safari with Google, DuckDuckGo, or Bing will be redirected to Brave Search")
                }
                
                Section {
                    NavigationLink(destination: InstallationGuideView()) {
                        Text("1. Open the Settings app on your iPhone and tap on Apps\n2. Search for or scroll down and tap Safari\n3. Scroll down and tap...")
                            .font(.footnote)
                    }
                } header: {
                    Text("How to Install")
                } footer: {
                    Text("Tap to view the full installation guide with screenshots.")
                }

                Section {
                    Link("Have an issue?", destination: URL(string: "https://github.com/btbishop93/braver-search")!).padding(.vertical, 10)
                    Link("Write a review", destination: MonetizationConfig.reviewURL)
                } header: {
                    Text("Help & Support")
                } footer: {
                    Text("Visit the project page for help, bug reports, and updates.")
                }

                if monetization.canShowSupport {
                    Section {
                        ForEach(MonetizationConfig.donationOptions) { option in
                            Button {
                                Task {
                                    await store.purchase(option: option)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(option.assetName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.displayName)
                                            .foregroundStyle(.primary)
                                        Text(option.description)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                        Text(store.priceText(for: option))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.activePurchaseProductID != nil)
                        }

                        if monetization.hasDonated {
                            Text("Thanks again for supporting Braver Search.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let purchaseMessage = store.purchaseMessage {
                            Text(purchaseMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Support Braver Search")
                    } footer: {
                        Text("Optional tips are available only for users who downloaded Braver Search before it became a paid app.")
                    }
                }
                
                Section {
                    Link("Visit Brave Search", destination: URL(string: "https://search.brave.com")!)
                        .foregroundColor(.orange)
                } footer: {
                    Text("Powered by Brave Search")
                }
            }
            .navigationTitle("Braver Search")
        }
        .task {
            MonetizationManager.shared.configureIfNeeded()
            await MonetizationManager.shared.resolveUserState()
            await StoreManager.shared.loadProductsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSupportFlow)) { _ in
            guard monetization.canShowSupport else {
                return
            }
            isShowingSupportSheet = true
        }
        .sheet(isPresented: $isShowingSupportSheet) {
            SupportSheetView()
        }
    }
}

#Preview {
    MainView()
} 
