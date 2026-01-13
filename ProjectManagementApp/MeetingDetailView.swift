import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(meeting.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(meeting.date.formatted(date: .complete, time: .shortened))
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("\(meeting.duration) minutes")
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                        
                        if let location = meeting.location {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(location)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Meeting Details
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Meeting Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        DetailRow(title: "Type", value: meeting.meetingType.rawValue)
                        DetailRow(title: "Project", value: meeting.project ?? "General")
                        DetailRow(title: "Status", value: meeting.status.rawValue)
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Agenda
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Agenda")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(meeting.agenda)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    
                    // Participants
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(meeting.participants, id: \.self) { participant in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                Text(participant)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(.background)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }
}
