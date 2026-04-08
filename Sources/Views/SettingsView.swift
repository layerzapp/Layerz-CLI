import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: EditorSettings

    var body: some View {
        Form {
            Section("Editor") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Stepper("\(settings.fontSize)px", value: $settings.fontSize, in: 8...32)
                        .frame(width: 120)
                }

                HStack {
                    Text("Tab Size")
                    Spacer()
                    Stepper("\(settings.tabSize)", value: $settings.tabSize, in: 1...8)
                        .frame(width: 100)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 160)
    }
}
