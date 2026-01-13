import SwiftUI

struct ClientProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showThemeSettings = false
    @State private var showAccountDetails = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Logout Button Section
                VStack(spacing: 12) {
                    Text("Account Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: { showAccountDetails = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeManager.accentColor)
                            }

                            Text("Account")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }

                    Button(action: { showThemeSettings = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeManager.accentColor)
                            }

                            Text("Themes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }

                    Button(action: {
                        // Logout action
                        appState.logout()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                            }

                            Text("Logout")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15))
                        )
                    }
                    
                    Text("You will be returned to the portal selection screen")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.background)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.1), radius: 5)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle("Profile & Settings")
        .sheet(isPresented: $showThemeSettings) {
            ThemeSettingsView().environmentObject(themeManager)
        }
        .sheet(isPresented: $showAccountDetails) {
            ProfileView.AccountDetailsSheet().environmentObject(themeManager)
        }
    }
}

struct ClientStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}


struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}
