
import SwiftUI

struct PaginationControls: View {
    @Binding var currentPage: Int
    @Binding var itemsPerPage: Int
    let totalPages: Int
    
    var body: some View {
        VStack(spacing: 8) {
            // Top Row: Status & Page Size
            HStack {
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("Cards per page")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button("6") { itemsPerPage = 6 }
                        Button("12") { itemsPerPage = 12 }
                        Button("18") { itemsPerPage = 18 }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(itemsPerPage)")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.primary)
                    }
                }
            }
            
            // Bottom Row: Navigation Buttons
            HStack(spacing: 12) {
                Button(action: { if currentPage > 1 { currentPage -= 1 } }) {
                    Text("Previous")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(currentPage > 1 ? .primary : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(currentPage <= 1)
                
                Button(action: { if currentPage < totalPages { currentPage += 1 } }) {
                    Text("Next")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(currentPage < totalPages ? .primary : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(currentPage >= totalPages)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
