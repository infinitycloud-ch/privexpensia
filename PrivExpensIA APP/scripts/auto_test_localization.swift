#!/usr/bin/swift

import Foundation

// Script Swift pour automatiser le changement de langue et la capture de screenshots

let languages = ["en", "fr"]  // Juste 2 langues pour le test
let views = ["Home", "Expenses", "Scan", "Stats", "Settings"]
let screenshotsDir = "~/moulinsart/PrivExpensIA/validation/localization_auto"

// Créer le dossier
let fileManager = FileManager.default
try? fileManager.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)

// Fonction pour exécuter une commande shell
func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

// Fonction pour taper sur l'écran
func tap(x: Int, y: Int) {
    _ = shell("xcrun simctl io booted tap \(x) \(y)")
    Thread.sleep(forTimeInterval: 1.5)
}

// Fonction pour capturer un screenshot
func screenshot(filename: String) {
    _ = shell("xcrun simctl io booted screenshot \"\(screenshotsDir)/\(filename)\"")
    print("📸 Captured: \(filename)")
}

// Positions des onglets (pour iPhone 16)
let tabPositions = [
    "Home": (75, 1350),
    "Expenses": (225, 1350),
    "Scan": (375, 1350),
    "Stats": (525, 1350),
    "Settings": (675, 1350)
]

print("🚀 Test de localisation automatique FR vs EN")
print("============================================")
print("")

// Pour chaque langue
for lang in languages {
    print("\n🌍 Testing language: \(lang)")

    // 1. Aller dans Settings
    print("  📱 Navigating to Settings...")
    tap(x: tabPositions["Settings"]!.0, y: tabPositions["Settings"]!.1)

    // 2. Ouvrir le sélecteur de langue
    print("  🔤 Opening language selector...")
    tap(x: 375, y: 280)  // Position approximative du bouton langue
    Thread.sleep(forTimeInterval: 2)

    // 3. Sélectionner la langue
    print("  ✅ Selecting \(lang)...")
    let langY = lang == "en" ? 250 : 340  // English ou Français
    tap(x: 375, y: langY)

    // 4. Fermer le sélecteur
    tap(x: 620, y: 165)  // Bouton Done
    Thread.sleep(forTimeInterval: 2)

    // 5. Capturer toutes les vues
    for view in views {
        print("  📍 Capturing \(view)...")
        let position = tabPositions[view]!
        tap(x: position.0, y: position.1)
        Thread.sleep(forTimeInterval: 1)
        screenshot(filename: "\(lang)_\(view).png")
    }
}

print("\n✅ Test completed!")
print("📊 10 screenshots captured in: \(screenshotsDir)")