// PleasureSpaceView.swift
// 2D/3D visualization of 16-dimensional pleasure space using Swift Charts

import SwiftUI
import Charts

struct PleasureSpaceView: View {
    let sessions: [Session]
    
    @State private var selectedProjection: Projection = .pca
    @State private var selectedDimX: PleasureProfile.Dimension = .order
    @State private var selectedDimY: PleasureProfile.Dimension = .mobility
    @State private var selectedSession: Session?
    @State private var showClusters = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Controls
                controlsSection
                
                // Chart
                chartSection
                    .frame(maxHeight: .infinity)
                
                // Legend
                legendSection
            }
            .navigationTitle("Pleasure Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Projection picker
            Picker("Projection", selection: $selectedProjection) {
                Text("PCA").tag(Projection.pca)
                Text("Custom").tag(Projection.custom)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedProjection == .custom {
                HStack {
                    Picker("X", selection: $selectedDimX) {
                        ForEach(PleasureProfile.Dimension.allCases, id: \.self) { dim in
                            Text(dim.displayName).tag(dim)
                        }
                    }
                    
                    Picker("Y", selection: $selectedDimY) {
                        ForEach(PleasureProfile.Dimension.allCases, id: \.self) { dim in
                            Text(dim.displayName).tag(dim)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Toggle("Show Clusters", isOn: $showClusters)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Chart
    
    private var chartSection: some View {
        let points = projectedPoints
        
        return Chart {
            if showClusters {
                // Draw cluster backgrounds
                ForEach(clusterData, id: \.id) { cluster in
                    PointMark(
                        x: .value("X", cluster.x),
                        y: .value("Y", cluster.y)
                    )
                    .foregroundStyle(cluster.color.opacity(0.3))
                    .symbolSize(cluster.size)
                }
            }
            
            // Session points
            ForEach(points) { point in
                PointMark(
                    x: .value("X", point.x),
                    y: .value("Y", point.y)
                )
                .foregroundStyle(point.color)
                .symbolSize(point.isSelected ? 200 : 80)
            }
        }
        .chartXAxisLabel(selectedProjection == .custom ? selectedDimX.displayName : "Component 1")
        .chartYAxisLabel(selectedProjection == .custom ? selectedDimY.displayName : "Component 2")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .padding()
    }
    
    // MARK: - Legend
    
    private var legendSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                legendItem(color: .purple, label: "Drift")
                legendItem(color: .orange, label: "Mastery")
                legendItem(color: .green, label: "Social")
                legendItem(color: .indigo, label: "Reflection")
            }
            
            if let session = selectedSession {
                selectedSessionInfo(session)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
        }
    }
    
    private func selectedSessionInfo(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            
            HStack {
                Text(session.timestampStart.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(session.state.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorFor(session.state).opacity(0.2))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 6) {
                ForEach((session.pleasureVector?.dominantDimensions ?? []).prefix(4), id: \.self) { dim in
                    Text(dim.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Data Processing
    
    private var projectedPoints: [PlotPoint] {
        sessions.compactMap { session -> PlotPoint? in
            let embedding = session.pleasureVector?.embedding ?? []
            guard embedding.count == 16 else { return nil }
            
            let (x, y): (Double, Double)
            
            switch selectedProjection {
            case .pca:
                // Simple PCA-like projection using first two principal components
                // In practice, you'd want to compute actual PCA
                (x, y) = simplePCA(embedding)
            case .custom:
                guard let xIndex = PleasureProfile.Dimension.allCases.firstIndex(of: selectedDimX),
                      let yIndex = PleasureProfile.Dimension.allCases.firstIndex(of: selectedDimY) else {
                    return nil
                }
                x = embedding[xIndex]
                y = embedding[yIndex]
            }
            
            return PlotPoint(
                id: session.id ?? UUID().uuidString,
                x: x,
                y: y,
                color: colorFor(session.state),
                session: session,
                isSelected: session.id == selectedSession?.id
            )
        }
    }
    
    private var clusterData: [ClusterPoint] {
        guard showClusters else { return [] }
        
        let clusters = VectorService.shared.clusterSessions(sessions)
        let colors: [Color] = [.purple, .orange, .green, .blue]
        
        return clusters.enumerated().map { index, cluster in
            let centroid = VectorService.shared.centroid(of: cluster)
            let (x, y) = simplePCA(centroid)
            
            return ClusterPoint(
                id: UUID().uuidString,
                x: x,
                y: y,
                color: colors[index % colors.count],
                size: Double(cluster.count * 500)
            )
        }
    }
    
    private func simplePCA(_ vector: [Double]) -> (Double, Double) {
        // Simplified projection: sum of spatial dims vs embodied dims
        // Real implementation would use actual PCA
        guard vector.count >= 16 else { return (0, 0) }
        
        // Spatial/cognitive component (first 7 dims)
        let component1 = (vector[0] + vector[1] + vector[2] + vector[3] + vector[4] + vector[5] + vector[6]) / 7
        
        // Embodied/relational component (last 9 dims)
        let component2 = (vector[7] + vector[8] + vector[9] + vector[10] + vector[11] + vector[12] + vector[13] + vector[14] + vector[15]) / 9
        
        return (component1, component2)
    }
    
    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let origin = geometry[proxy.plotFrame!].origin
        let adjustedLocation = CGPoint(
            x: location.x - origin.x,
            y: location.y - origin.y
        )
        
        guard let x: Double = proxy.value(atX: adjustedLocation.x),
              let y: Double = proxy.value(atY: adjustedLocation.y) else { return }
        
        // Find nearest point
        var nearestSession: Session?
        var nearestDistance = Double.infinity
        
        for point in projectedPoints {
            let distance = sqrt(pow(point.x - x, 2) + pow(point.y - y, 2))
            if distance < nearestDistance && distance < 0.2 {
                nearestDistance = distance
                nearestSession = point.session
            }
        }
        
        selectedSession = nearestSession
    }
    
    private func colorFor(_ state: SessionState) -> Color {
        switch state {
        case .idle: return .gray
        case .drift: return .purple
        case .mastery: return .orange
        case .socialSync: return .green
        case .reflection: return .indigo
        }
    }
}

// MARK: - Supporting Types

enum Projection {
    case pca
    case custom
}

struct PlotPoint: Identifiable {
    let id: String
    let x: Double
    let y: Double
    let color: Color
    let session: Session
    let isSelected: Bool
}

struct ClusterPoint: Identifiable {
    let id: String
    let x: Double
    let y: Double
    let color: Color
    let size: Double
}

// MARK: - Radar Chart (Alternative Visualization)

struct RadarChartView: View {
    let dimensions: [PleasureProfile.Dimension: Double]
    
    var body: some View {
        Canvas { context, size in
            drawRadar(context: context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func drawRadar(context: GraphicsContext, size: CGSize) {
        let centerX: CGFloat = size.width / 2
        let centerY: CGFloat = size.height / 2
        let center = CGPoint(x: centerX, y: centerY)
        let minDim = min(size.width, size.height)
        let radius: CGFloat = minDim / 2 - 40
        
        // Draw grid circles
        let levels: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
        for level in levels {
            let scaledRadius = radius * level
            let circleRect = CGRect(
                x: centerX - scaledRadius,
                y: centerY - scaledRadius,
                width: scaledRadius * 2,
                height: scaledRadius * 2
            )
            let circlePath = Circle().path(in: circleRect)
            context.stroke(circlePath, with: .color(.gray.opacity(0.3)))
        }
        
        // Draw axis lines
        for index in 0..<16 {
            let angle = (Double(index) / 16.0) * 2 * Double.pi - Double.pi / 2
            var path = Path()
            path.move(to: center)
            let endX = centerX + cos(angle) * radius
            let endY = centerY + sin(angle) * radius
            path.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(path, with: .color(.gray.opacity(0.3)))
        }
        
        // Draw data polygon
        var dataPath = Path()
        let dims = PleasureProfile.Dimension.allCases
        for (index, dim) in dims.enumerated() {
            let value = dimensions[dim] ?? 0
            let angle = (Double(index) / 16.0) * 2 * Double.pi - Double.pi / 2
            let pointX = centerX + cos(angle) * radius * value
            let pointY = centerY + sin(angle) * radius * value
            let point = CGPoint(x: pointX, y: pointY)
            
            if index == 0 {
                dataPath.move(to: point)
            } else {
                dataPath.addLine(to: point)
            }
        }
        dataPath.closeSubpath()
        
        context.fill(dataPath, with: .color(.purple.opacity(0.3)))
        context.stroke(dataPath, with: .color(.purple), lineWidth: 2)
    }
}

#Preview {
    PleasureSpaceView(sessions: [])
}
