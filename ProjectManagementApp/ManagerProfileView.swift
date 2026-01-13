import SwiftUI

struct ManagerProfileView: View {
    var availablePanels: [UserRole] = []
    var currentPanel: UserRole? = nil
    var onSwitchPanel: ((UserRole) -> Void)? = nil
    
    var body: some View {
        ProfileView(availablePanels: availablePanels, currentPanel: currentPanel, onSwitchPanel: onSwitchPanel)
    }
}
