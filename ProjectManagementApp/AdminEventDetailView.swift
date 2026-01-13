import SwiftUI

struct AdminEventDetailView: View {
    let event: Meeting
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Title and Actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("by admin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            
            Divider()
            
            // Details Grid
            VStack(alignment: .leading, spacing: 8) {
                detailRow(label: "Time:", value: event.date.formatted(date: .omitted, time: .shortened))
                detailRow(label: "Client:", value: event.project ?? "—") 
                detailRow(label: "Duration:", value: "\(event.duration) minutes")
                detailRow(label: "Email:", value: event.createdByEmail ?? "—")
                detailRow(label: "Notes:", value: event.agenda.isEmpty ? "—" : event.agenda)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
        )
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
