// ContentView.swift
// Root navigation view for grain

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var stateMachine: SessionStateMachine
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Architect", systemImage: "building.2")
                }
            
            ActiveSessionView()
                .tabItem {
                    Label("Guide", systemImage: "waveform")
                }
            
            LogBookView()
                .tabItem {
                    Label("Scribe", systemImage: "book.closed")
                }
        }
        .tint(.purple)
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStateMachine())
}
