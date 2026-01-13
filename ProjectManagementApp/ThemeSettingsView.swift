import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Theme & Appearance")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Picker("Appearance", selection: $themeManager.appearance) {
                            Text("Light").tag(ThemeAppearance.light)
                            Text("Dark").tag(ThemeAppearance.dark)
                            Text("Auto").tag(ThemeAppearance.system)
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(ThemeAccent.allCases, id: \.self) { acc in
                                Button(action: { themeManager.accent = acc }) {
                                    ZStack {
                                        Circle()
                                            .fill(acc.color)
                                            .frame(width: 32, height: 32)
                                        if themeManager.accent == acc {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .tint(themeManager.accentColor)
    }
}
