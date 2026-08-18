
import SwiftUI

struct SettingsView: View {
    @AppStorage("appAppearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage("actionButtonSide") private var actionButtonSideRaw: String = ActionButtonSide.trailing.rawValue
    // used to dismiss the sheet
    @Environment(\.dismiss) private var dismiss

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private var actionButtonSide: Binding<ActionButtonSide> {
        Binding(
            get: { ActionButtonSide(rawValue: actionButtonSideRaw) ?? .trailing },
            set: { actionButtonSideRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    // Deliberately no .accessibilityLabel/.accessibilityValue here:
                    // with .pickerStyle(.inline) they cascade down to every row
                    // inside the picker rather than just summarizing the picker as a
                    // whole, so VoiceOver announced "Appearance, Light" on every row
                    // regardless of which option it actually was. Each row's own
                    // Text already gives it a correct, distinct label on its own.
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how Launch Control looks, or match your device's system setting.")
                }

                Section {
                    Picker("Action Button", selection: actionButtonSide) {
                        ForEach(ActionButtonSide.allCases) { side in
                            Text(side.label).tag(side)
                        }
                    }
                    .pickerStyle(.inline)
                    // See the comment on the Appearance picker above.
                } header: {
                    Text("Action Button")
                } footer: {
                    Text("Choose which side of the screen the add and toggle buttons appear on.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityHint("Closes settings.")
                }
            }
        }
        // Applied here too (not just at the app root) so the sheet itself updates
        // live as the picker changes — a sheet's hosting controller otherwise only
        // picks up a preferredColorScheme change set above it once it's re-presented.
        .preferredColorScheme(appearance.wrappedValue.colorScheme)
    }
}

#Preview {
    SettingsView()
}
