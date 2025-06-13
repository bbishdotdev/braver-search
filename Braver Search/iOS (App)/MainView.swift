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
                    Link(destination: URL(string: "https://buymeacoffee.com/brendenbishop")!) {
                        Image("BmcButton")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .padding(.vertical, 5)
                    }
                } header: {
                    Text("Help & Support")
                } footer: {
                    Text("Feel free to donate to help support the app. (optional)")
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
    }
}

#Preview {
    MainView()
} 