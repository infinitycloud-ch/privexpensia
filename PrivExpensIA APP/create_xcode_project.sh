#!/bin/bash

# Create Xcode iOS App project structure
mkdir -p PrivExpensIA
cd PrivExpensIA

# Create basic structure
mkdir -p PrivExpensIA
mkdir -p PrivExpensIA.xcodeproj

# Create AppDelegate
cat > PrivExpensIA/AppDelegate.swift << 'APPDELEGATE'
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
APPDELEGATE

# Create SceneDelegate
cat > PrivExpensIA/SceneDelegate.swift << 'SCENEDELEGATE'
import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: ContentView())
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
SCENEDELEGATE

echo "Xcode project structure created"
