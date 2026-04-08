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

                Picker("Theme", selection: $settings.theme) {
                    ForEach(EditorSettings.themes, id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }

                Toggle("Line Wrapping", isOn: $settings.lineWrapping)
                Toggle("Show Line Numbers", isOn: $settings.showLineNumbers)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 260)
    }
}
