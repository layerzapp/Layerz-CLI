import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: EditorSettings

    private var monospacedFontNames: [String] {
        let manager = NSFontManager.shared
        let allFamilies = manager.availableFontFamilies
        return allFamilies.filter { family in
            guard let members = manager.availableMembers(ofFontFamily: family),
                  let first = members.first,
                  first.count > 3,
                  let traits = first[3] as? UInt else { return false }
            return (traits & NSFontTraitMask.fixedPitchFontMask.rawValue) != 0
                || family.lowercased().contains("mono")
                || family.lowercased().contains("meslo")
                || family.lowercased().contains("nerd")
                || family.lowercased().contains("code")
                || family.lowercased().contains("menlo")
                || family.lowercased().contains("courier")
                || family.lowercased().contains("consolas")
        }.sorted()
    }

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

            Section("Terminal") {
                Picker("Font", selection: $settings.terminalFontName) {
                    ForEach(monospacedFontNames, id: \.self) { name in
                        Text(name)
                            .font(.custom(name, size: 13))
                            .tag(name)
                    }
                }

                HStack {
                    Text("Font Size")
                    Spacer()
                    Stepper("\(settings.terminalFontSize)px", value: $settings.terminalFontSize, in: 8...32)
                        .frame(width: 120)
                }

                terminalFontPreview
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 360)
    }

    private var terminalFontPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text("❯ ls -la  ➜  main ✗ ⚡")
                .font(.custom(settings.terminalFontName, size: CGFloat(settings.terminalFontSize)))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black)
                .foregroundColor(.green)
                .cornerRadius(6)
        }
    }
}
