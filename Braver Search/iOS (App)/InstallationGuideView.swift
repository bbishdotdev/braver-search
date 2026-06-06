import SwiftUI

struct Step: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let imageName: String
}

let installationSteps: [Step] = [
    Step(title: "1. Open Settings", detail: "Open the Settings app and tap Apps.", imageName: "braver_search_setup_1"),
    Step(title: "2. Open Safari Settings", detail: "Search for Safari or scroll down and tap Safari.", imageName: "braver_search_setup_2"),
    Step(title: "3. Open Extensions", detail: "Scroll down inside Safari settings and tap Extensions.", imageName: "braver_search_setup_3"),
    Step(title: "4. Turn On Braver Search", detail: "Tap Braver Search, then turn on the switch next to Braver Search.", imageName: "braver_search_setup_4"),
    Step(title: "5. Open Safari", detail: "Open Safari and make a quick search so Safari can show the extension permission controls.", imageName: "braver_search_setup_5"),
    Step(title: "6. Open The Extensions Menu", detail: "Tap Safari's extensions button in the address bar.", imageName: "braver_search_setup_6"),
    Step(title: "7. Choose Braver Search", detail: "Tap Braver Search in Safari's extension menu.", imageName: "braver_search_setup_7"),
    Step(title: "8. Always Allow", detail: "When Safari asks for access, tap Always Allow. One-day access works, but redirects may stop later.", imageName: "braver_search_setup_8"),
    Step(title: "9. Allow Every Website", detail: "When prompted, tap Always Allow on Every Website so supported search engines can redirect.", imageName: "braver_search_setup_9"),
    Step(title: "10. Finish", detail: "Tap Done. You can return to this menu later to change Braver Search settings.", imageName: "braver_search_setup_10"),
    Step(title: "11. Test A Search", detail: "Search from Safari again. The address should change to search.brave.com.", imageName: "braver_search_setup_11")
]

struct InstallationGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Turn On Braver Search")
                        .font(.system(size: 26, weight: .bold))

                    Text("Safari setup has two parts: enable the extension in Settings, then allow website access from Safari.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(installationSteps) { step in
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.title)
                                .font(.system(size: 18, weight: .bold))

                            Text(step.detail)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Image(step.imageName)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Installation Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        InstallationGuideView()
    }
}
