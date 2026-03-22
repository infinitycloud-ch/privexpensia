aarimport XCTest

class LocalizationScreenshotTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // TEST PRINCIPAL - Lance ce test avec Cmd+U ou en cliquant sur le diamant
    func testCaptureAllLanguages() throws {
        // ÉTAPE 1: Définir les 8 langues de PrivExpensIA
        let languagesToTest = [
            "en",  // English
            "fr",  // Français
            "de",  // Deutsch
            "it",  // Italiano
            "es",  // Español
            "ja",  // 日本語
            "ko",  // 한국어
            "sk"   // Slovenčina
        ]
        
        // ÉTAPE 2: Pour chaque langue
        for language in languagesToTest {
            print("🔄 Testing language: \(language)")
            
            // Créer une nouvelle instance de l'app
            let app = XCUIApplication()
            
            // Forcer la langue
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-UITEST_SKIP_SPLASH"]
            
            // Lancer l'app
            app.launch()
            
            // Attendre que l'app se charge (skip splash screen)
            sleep(3)
            
            // ÉTAPE 3: Capturer la page d'accueil
            takeScreenshot(name: "01_home_\(language)")
            
            // ÉTAPE 4: Naviguer dans les 5 tabs de PrivExpensIA
            // Tab 1: Home (déjà capturé)
            
            // Tab 2: Expenses
            if app.tabBars.buttons.element(boundBy: 1).exists {
                app.tabBars.buttons.element(boundBy: 1).tap()
                sleep(1)
                takeScreenshot(name: "02_expenses_\(language)")
            }
            
            // Tab 3: Scanner
            if app.tabBars.buttons.element(boundBy: 2).exists {
                app.tabBars.buttons.element(boundBy: 2).tap()
                sleep(1)
                takeScreenshot(name: "03_scanner_\(language)")
            }
            
            // Tab 4: Statistics
            if app.tabBars.buttons.element(boundBy: 3).exists {
                app.tabBars.buttons.element(boundBy: 3).tap()
                sleep(1)
                takeScreenshot(name: "04_statistics_\(language)")
            }
            
            // Tab 5: Settings - IMPORTANT pour voir le language picker
            if app.tabBars.buttons.element(boundBy: 4).exists {
                app.tabBars.buttons.element(boundBy: 4).tap()
                sleep(1)
                takeScreenshot(name: "05_settings_\(language)")
                
                // Essayer de capturer le language picker ouvert
                // Chercher le picker de langue (peut varier selon l'implémentation)
                let languageCells = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'language' OR identifier CONTAINS 'Language'"))
                if languageCells.count > 0 {
                    languageCells.firstMatch.tap()
                    sleep(1)
                    takeScreenshot(name: "06_language_picker_\(language)")
                }
            }
            
            // ÉTAPE 5: Vérifier que la localisation fonctionne
            // Vérifier qu'on ne voit pas de clés underscore
            let underscoreTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '_'"))
            if underscoreTexts.count > 0 {
                print("⚠️ WARNING: Found \(underscoreTexts.count) texts with underscores in \(language)")
                for i in 0..<min(underscoreTexts.count, 3) {
                    print("  - \(underscoreTexts.element(boundBy: i).label)")
                }
            }
            
            print("✅ Captured screenshots for \(language)")
            
            // Fermer l'app avant de passer à la langue suivante
            app.terminate()
        }
    }
    
    // TEST RAPIDE - Juste français pour debug
    func testQuickFrenchOnly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-UITEST_SKIP_SPLASH"]
        app.launch()
        
        sleep(3) // Skip splash
        
        // Capturer Home
        takeScreenshot(name: "quick_home_fr")
        
        // Aller dans Settings directement (5ème tab)
        if app.tabBars.buttons.count >= 5 {
            app.tabBars.buttons.element(boundBy: 4).tap()
            sleep(1)
            takeScreenshot(name: "quick_settings_fr")
            
            // Vérifier si on voit "Paramètres" au lieu de "Settings"
            let frenchTexts = ["Paramètres", "Langue", "Monnaie", "Notifications"]
            var foundFrench = false
            for text in frenchTexts {
                if app.staticTexts[text].exists {
                    print("✅ Found French text: \(text)")
                    foundFrench = true
                }
            }
            
            if !foundFrench {
                print("❌ No French text found - localization might be broken")
            }
        }
        
        // Vérifier les underscores
        let underscoreCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '_'")).count
        if underscoreCount > 0 {
            print("❌ Found \(underscoreCount) underscore keys - localization is broken!")
            XCTFail("Localization keys are visible")
        } else {
            print("✅ No underscore keys visible")
        }
    }
    
    // FONCTION HELPER pour prendre les screenshots
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("📸 Screenshot taken: \(name)")
    }
    
    // TEST DE CHANGEMENT DE LANGUE DANS L'APP
    func testLanguageChangeInApp() throws {
        let app = XCUIApplication()
        app.launch()
        
        sleep(3) // Skip splash
        
        // Aller dans Settings (5ème tab)
        if app.tabBars.buttons.count >= 5 {
            app.tabBars.buttons.element(boundBy: 4).tap()
            sleep(1)
            
            takeScreenshot(name: "before_language_change")
            
            // Chercher le picker de langue
            // Dans PrivExpensIA, il devrait y avoir un picker pour la langue
            let pickers = app.pickers
            if pickers.count > 0 {
                // Le premier picker est probablement la langue
                let languagePicker = pickers.firstMatch
                
                // Essayer de sélectionner Français
                languagePicker.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Français")
                sleep(2)
                
                takeScreenshot(name: "after_language_change_fr")
                
                // Retourner à Home pour vérifier
                app.tabBars.buttons.element(boundBy: 0).tap()
                sleep(1)
                takeScreenshot(name: "home_after_french")
                
                // Vérifier que ça a changé
                let frenchGreetings = ["Bonjour", "Bonsoir", "Bonne nuit"]
                var foundFrench = false
                for greeting in frenchGreetings {
                    if app.staticTexts[greeting].exists {
                        print("✅ French localization working: found '\(greeting)'")
                        foundFrench = true
                        break
                    }
                }
                
                XCTAssertTrue(foundFrench, "L'interface devrait être en français maintenant")
            }
        }
    }
    
    // TEST: Ouvrir l'app, aller dans Settings et scroller jusqu'en bas
    func testOpenSettingsAndScrollToBottom() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_SKIP_SPLASH", "-UITEST_SELECTED_TAB", "settings"]
        app.launch()

        sleep(1)
        takeScreenshot(name: "settings_tab_opened")
        
        // Déterminer l'élément scrollable principal
        let table = app.tables.firstMatch
        let scrollView = app.scrollViews.firstMatch
        
        // Faire plusieurs swipes vers le haut pour atteindre le bas
        for _ in 0..<8 {
            if table.exists {
                table.swipeUp()
            } else if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
            usleep(500_000)
        }
        
        takeScreenshot(name: "settings_scrolled_bottom")
    }
}
