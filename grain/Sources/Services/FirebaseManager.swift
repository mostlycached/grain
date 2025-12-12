// FirebaseManager.swift
// Singleton for Firebase Auth and Firestore operations

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    // Computed properties to prevent early initialization crash
    private var db: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }
    
    private var auth: Auth? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth()
    }
    
    @Published var currentUser: GrainUser?
    @Published var isAuthenticated = false
    
    private init() {
        if FirebaseApp.app() != nil {
            setupAuthStateListener()
        }
    }
    
    // MARK: - Authentication
    
    private func setupAuthStateListener() {
        guard let auth = auth else { return }
        
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let uid = user?.uid {
                    await self?.fetchCurrentUser(uid: uid)
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }
    
    func signInAnonymously() async throws {
        guard let auth = auth else { throw FirebaseError.notConfigured }
        let result = try await auth.signInAnonymously()
        await createUserIfNeeded(uid: result.user.uid)
    }
    
    func signOut() throws {
        guard let auth = auth else { return }
        try auth.signOut()
        currentUser = nil
    }
    
    // MARK: - User Operations
    
    private func createUserIfNeeded(uid: String) async {
        guard let db = db else { return }
        let docRef = db.collection("users").document(uid)
        
        do {
            let doc = try await docRef.getDocument()
            if !doc.exists {
                let newUser = GrainUser()
                try docRef.setData(from: newUser)
                currentUser = newUser
            } else {
                currentUser = try doc.data(as: GrainUser.self)
            }
        } catch {
            print("Error creating/fetching user: \(error)")
        }
    }
    
    private func fetchCurrentUser(uid: String) async {
        guard let db = db else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            currentUser = try doc.data(as: GrainUser.self)
        } catch {
            print("Error fetching user: \(error)")
        }
    }
    
    func updateUser(_ user: GrainUser) async throws {
        guard let auth = auth, let db = db else { throw FirebaseError.notConfigured }
        guard let uid = auth.currentUser?.uid else { return }
        var updatedUser = user
        updatedUser.updatedAt = Date()
        try db.collection("users").document(uid).setData(from: updatedUser, merge: true)
        currentUser = updatedUser
    }
    
    // MARK: - Inventory Operations
    
    func fetchInventory(near location: GeoPoint? = nil, radius: Double = 5000) async throws -> [InventoryItem] {
        guard let db = db else { return [] }
        
        let query: Query = db.collection("inventory")
            .whereField("status", isEqualTo: "available")
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: InventoryItem.self) }
    }
    
    func addInventoryItem(_ item: InventoryItem) async throws {
        guard let db = db else { throw FirebaseError.notConfigured }
        try db.collection("inventory").addDocument(from: item)
    }
    
    // MARK: - Session Operations
    
    func createSession(userId: String, initialState: SessionState = .drift) async throws -> Session {
        guard let db = db else { throw FirebaseError.notConfigured }
        
        var session = Session(userId: userId)
        session.state = initialState
        session.stateHistory = [.idle]
        
        let docRef = try db.collection("sessions").addDocument(from: session)
        var createdSession = session
        createdSession.id = docRef.documentID
        return createdSession
    }
    
    func updateSession(_ session: Session) async throws {
        guard let db = db else { return }
        guard let id = session.id else { return }
        try db.collection("sessions").document(id).setData(from: session, merge: true)
    }
    
    func endSession(_ session: Session, pleasureVector: SessionPleasureVector) async throws {
        guard let db = db else { return }
        guard let id = session.id else { return }
        var finalSession = session
        finalSession.timestampEnd = Date()
        finalSession.pleasureVector = pleasureVector
        finalSession.transition(to: .reflection)
        
        try db.collection("sessions").document(id).setData(from: finalSession)
    }
    
    func fetchSessions(userId: String, limit: Int = 50) async throws -> [Session] {
        guard let db = db else { return [] }
        
        let snapshot = try await db.collection("sessions")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "timestamp_start", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Session.self) }
    }
    
    // MARK: - Vector Search (Firebase Vector Search)
    
    func findSimilarSessions(vector: [Double], limit: Int = 10) async throws -> [Session] {
        guard let db = db else { return [] }
        
        let snapshot = try await db.collection("sessions")
            .order(by: "pleasure_vector.embedding")
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Session.self) }
    }
}

enum FirebaseError: Error {
    case notConfigured
}

