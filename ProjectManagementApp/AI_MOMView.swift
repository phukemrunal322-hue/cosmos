import SwiftUI

struct AI_MOMView: View {
    let meeting: Meeting
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("AI-Generated Minutes of Meeting")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        Text(meeting.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(meeting.date.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                    
                    // MOM Content
                    if let mom = meeting.mom {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Meeting Summary")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(mom)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .background(.background)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    } else {
                        Text("MOM being generated...")
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                    
                    // AI Features
                    VStack(alignment: .leading, spacing: 15) {
                        Text("AI Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "checkmark.circle.fill", title: "Auto-transcribed", description: "Conversation automatically transcribed")
                        FeatureRow(icon: "list.bullet", title: "Action Items", description: "Key decisions and tasks extracted")
                        FeatureRow(icon: "clock.fill", title: "Smart Reminders", description: "Follow-ups scheduled automatically")
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                }
                .padding()
            }
            .navigationBarItems(
                leading: Button("Share") {
                    // Share functionality
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}
