import SwiftUI

struct ResourceDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
    }
}

struct ManagementStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(width: 160)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Generic Form Components

struct CustomAddResourceField: View {
    let icon: String
    let label: String
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = false
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    @State private var isVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
                Spacer()
            }
            
            HStack {
                if isSecure && !isVisible {
                    SecureField(placeholder, text: $text)
                        .autocapitalization(.none)
                } else {
                    TextField(placeholder, text: $text)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
                }
                
                if isSecure {
                    Button(action: { isVisible.toggle() }) {
                        Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .keyboardType(keyboardType)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }
}

struct CustomDropdownField: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { selection = option }) {
                        Text(option)
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select \(label)" : selection)
                        .foregroundColor(selection.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
        }
    }
}
