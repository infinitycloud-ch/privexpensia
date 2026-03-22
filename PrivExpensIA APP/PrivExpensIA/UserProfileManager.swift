import Foundation
import CoreData

// MARK: - User Profile Manager
// Singleton for managing user profile data

class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()

    @Published var currentProfile: UserProfile?
    @Published var isProfileSetup: Bool = false

    private let context: NSManagedObjectContext

    private init() {
        self.context = CoreDataManager.shared.persistentContainer.viewContext
        loadProfile()
    }

    // MARK: - Computed Properties

    var firstName: String {
        currentProfile?.firstName ?? ""
    }

    var preferredCurrency: String {
        currentProfile?.preferredCurrency ?? "CHF"
    }

    var hasProfile: Bool {
        currentProfile != nil && !(currentProfile?.firstName?.isEmpty ?? true)
    }

    // MARK: - Load Profile

    func loadProfile() {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.fetchLimit = 1

        do {
            let profiles = try context.fetch(request)
            if let profile = profiles.first {
                currentProfile = profile
                isProfileSetup = !(profile.firstName?.isEmpty ?? true)
            } else {
                currentProfile = nil
                isProfileSetup = false
            }
        } catch {
            currentProfile = nil
            isProfileSetup = false
        }
    }

    // MARK: - Create Profile

    @discardableResult
    func createProfile(firstName: String, preferredCurrency: String = "CHF") -> UserProfile {
        // Delete any existing profile first (only one profile allowed)
        deleteAllProfiles()

        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.firstName = firstName
        profile.preferredCurrency = preferredCurrency
        profile.createdAt = Date()

        do {
            try context.save()
            currentProfile = profile
            isProfileSetup = true

            // Update CurrencyManager with preferred currency
            CurrencyManager.shared.currentCurrency = preferredCurrency

            // Post notification
            NotificationCenter.default.post(name: .userProfileChanged, object: nil)
        } catch {
            context.rollback()
        }

        return profile
    }

    // MARK: - Update Profile

    func updateProfile(firstName: String? = nil, preferredCurrency: String? = nil) {
        guard let profile = currentProfile else { return }

        if let firstName = firstName {
            profile.firstName = firstName
        }

        if let currency = preferredCurrency {
            profile.preferredCurrency = currency
            CurrencyManager.shared.currentCurrency = currency
        }

        do {
            try context.save()
            objectWillChange.send()
            NotificationCenter.default.post(name: .userProfileChanged, object: nil)
        } catch {
            context.rollback()
        }
    }

    // MARK: - Delete Profile

    private func deleteAllProfiles() {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()

        do {
            let profiles = try context.fetch(request)
            for profile in profiles {
                context.delete(profile)
            }
            try context.save()
        } catch {
            context.rollback()
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let userProfileChanged = Notification.Name("userProfileChanged")
}
