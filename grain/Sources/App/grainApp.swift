// grainApp.swift
// Main entry point for the grain iOS application

import SwiftUI
import FirebaseCore

@main
struct grainApp: App {
    
    init() {
        configureFirebase()
    }
    
    private func configureFirebase() {
        // 1. Check the main bundle root (default location)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            if let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
                return
            }
        }
        
        // 2. Check "Resources" subdirectory (in case it was added as a folder reference)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist", inDirectory: "Resources") {
            if let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
                return
            }
        }
        
        // 3. Fail gracefully if not found
        print("----------------------------------------------------------------")
        print("⚠️ ERROR: GoogleService-Info.plist not found in the app bundle.")
        print("The file exists at grain/Resources/GoogleService-Info.plist on disk,")
        print("but it has not been added to the Xcode target.")
        print("")
        print("👉 ACTION REQUIRED:")
        print("1. In Xcode, right-click the 'grain' folder in the left sidebar.")
        print("2. Choose 'Add Files to \"grain\"...'.")
        print("3. Navigate to grain/Resources/ and select GoogleService-Info.plist.")
        print("4. Ensure 'Add to targets' is checked for your app.")
        print("----------------------------------------------------------------")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SessionStateMachine())
        }
    }
}
