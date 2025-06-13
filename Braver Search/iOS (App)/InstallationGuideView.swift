import SwiftUI

struct Step: Identifiable {
    let id = UUID()
    let text: String
    let imageName: String
}

let installationSteps: [Step] = [
    Step(text: "1. Open the Settings app on your iPhone and tap on Apps (indicated by the pointer emoji).", imageName: "braver_search_setup_1"),
    Step(text: "2. Search for or scroll down and tap Safari (indicated by the pointer emoji).", imageName: "braver_search_setup_2"),
    Step(text: "3. Scroll down and tap Extensions inside Safari settings (indicated by the pointer emoji).", imageName: "braver_search_setup_3"),
    Step(text: "4. Find and tap Braver Search in the list of extensions, then toggle the switch next to Braver Search to the \"On\" position (indicated by the pointer emoji).", imageName: "braver_search_setup_4"),
    Step(text: "5. Open Safari and do a search, noticing it still goes to your default search (indicated by the pointer emoji).", imageName: "braver_search_setup_5"),
    Step(text: "6. Tap on the extensions icon to bring up the Safari extensions menu (indicated by the pointer emoji).", imageName: "braver_search_setup_6"),
    Step(text: "7. Tap on the Braver Search option in the Safari menu (indicated by the pointer emoji).", imageName: "braver_search_setup_7"),
    Step(text: "8. When the extension requests access, confirm by tapping Always Allow.... Alternatively, if you prefer temporary access, tap Allow for One Day, though this may need to be repeated (indicated by the pointer emoji).", imageName: "braver_search_setup_8"),
    Step(text: "9. When prompted, tap Always Allow on Every Website to grant full access (indicated by the pointer emoji).", imageName: "braver_search_setup_9"),
    Step(text: "10. Tap Done to now have your searches redirected to Brave and, if needed, adjust additional settings via the Braver Search option (indicated by the pointer emoji).", imageName: "braver_search_setup_10")
]

struct InstallationGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(installationSteps) { step in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(step.text)
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