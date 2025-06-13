//
//  MainView.swift
//  Braver Search
//
//  Created by Brenden Bishop on 1/19/25.
//

import SwiftUI

struct MainView: View {
    @AppStorage("enabled", store: UserDefaults(suiteName: "group.xyz.bsquared.braversearch"))
    private var isEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Braver Search", isOn: $isEnabled)
                } header: {
                    Text("Settings")
                } footer: {
                    Text("When enabled, searches from Safari will be redirected to Brave Search")
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