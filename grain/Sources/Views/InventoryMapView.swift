// InventoryMapView.swift
// Map view showing owned and public inventory items

import SwiftUI
import MapKit

struct InventoryMapView: View {
    @StateObject private var firebase = FirebaseManager.shared
    @State private var items: [InventoryItem] = []
    @State private var selectedItem: InventoryItem?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var filterMode: FilterMode = .all
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case owned = "Owned"
        case publicItems = "Public"
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, selection: $selectedItem) {
                ForEach(filteredItems) { item in
                    if let coord = item.coordinate {
                        Annotation(item.name, coordinate: coord) {
                            ItemMarker(item: item, isSelected: selectedItem?.id == item.id)
                        }
                        .tag(item)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            
            // Filter bar
            HStack {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Button {
                        filterMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(filterMode == mode ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(filterMode == mode ? Color.purple : Color.gray.opacity(0.2))
                            .foregroundStyle(filterMode == mode ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.top)
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(item: item)
                .presentationDetents([.medium])
        }
        .task {
            await loadItems()
        }
    }
    
    private var filteredItems: [InventoryItem] {
        switch filterMode {
        case .all:
            return items
        case .owned:
            return items.filter { $0.accessMode == .owned }
        case .publicItems:
            return items.filter { $0.accessMode == .publicLibrary }
        }
    }
    
    private func loadItems() async {
        do {
            items = try await firebase.fetchInventory()
        } catch {
            print("Error loading inventory: \(error)")
        }
    }
}

// MARK: - Item Marker

struct ItemMarker: View {
    let item: InventoryItem
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                
                Image(systemName: itemIcon)
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundStyle(.white)
            }
            
            // Triangle pointer
            Triangle()
                .fill(markerColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .shadow(radius: 3)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private var markerColor: Color {
        switch item.type {
        case .tool: return .purple
        case .space: return .blue
        case .expert: return .orange
        }
    }
    
    private var itemIcon: String {
        switch item.type {
        case .tool: return "wrench.and.screwdriver"
        case .space: return "building.2"
        case .expert: return "person.fill"
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Item Detail Sheet

struct ItemDetailSheet: View {
    let item: InventoryItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Label(item.type.rawValue.capitalized, systemImage: typeIcon)
                        Text("•")
                        Text(item.accessMode.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: item.status)
            }
            
            Divider()
            
            // Affordances
            VStack(alignment: .leading, spacing: 8) {
                Text("Affordances")
                    .font(.headline)
                
                ForEach(Array(item.affordances.enumerated()), id: \.offset) { _, affordance in
                    HStack(spacing: 12) {
                        if let sense = affordance.sense {
                            Label(sense.rawValue.capitalized, systemImage: senseIcon(sense))
                                .font(.caption)
                        }
                        
                        if let intensity = affordance.intensity {
                            Text(intensity.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(intensityColor(intensity).opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        if let dims = affordance.pleasureDimensions {
                            ForEach(dims, id: \.self) { dim in
                                Text(dim.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            // Temporal tags
            if let temporal = item.temporalTags {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Best Times")
                        .font(.headline)
                    
                    HStack {
                        ForEach(temporal.bestTimes, id: \.self) { time in
                            Text(time.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let duration = temporal.durationRange {
                        Text("\(duration.min)-\(duration.max) minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action button
            Button {
                // TODO: Add to mission or start session with this item
                dismiss()
            } label: {
                Text("Use in Mission")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
    }
    
    private var typeIcon: String {
        switch item.type {
        case .tool: return "wrench"
        case .space: return "building.2"
        case .expert: return "person"
        }
    }
    
    private func senseIcon(_ sense: Affordance.Sense) -> String {
        switch sense {
        case .visual: return "eye"
        case .auditory: return "ear"
        case .olfactory: return "nose"
        case .gustatory: return "mouth"
        case .tactile: return "hand.raised"
        case .kinesthetic: return "figure.walk"
        case .technical: return "gearshape"
        }
    }
    
    private func intensityColor(_ intensity: Affordance.Intensity) -> Color {
        switch intensity {
        case .subtle: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .overwhelming: return .red
        }
    }
}

struct StatusBadge: View {
    let status: InventoryItem.ItemStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .available: return .green
        case .booked: return .orange
        case .maintenance: return .red
        }
    }
}

#Preview {
    InventoryMapView()
}
