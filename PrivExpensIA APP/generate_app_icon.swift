#!/usr/bin/swift

import SwiftUI
import AppKit

// MARK: - App Icon Generator for PrivExpensIA
struct AppIconGenerator {
    
    static func generateIcon(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background gradient
        let gradient = NSGradient(colors: [
            NSColor(red: 0.4, green: 0.2, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        ])!
        
        let rect = NSRect(origin: .zero, size: size)
        gradient.draw(in: rect, angle: -45)
        
        // Glass effect overlay
        let glassGradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.3),
            NSColor.clear
        ])!
        
        let glassRect = NSRect(x: 0, y: size.height * 0.5, width: size.width, height: size.height * 0.5)
        glassGradient.draw(in: glassRect, angle: -90)
        
        // Center icon
        let iconString = "📱"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.width * 0.5),
            .foregroundColor: NSColor.white
        ]
        
        let textSize = iconString.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        iconString.draw(in: textRect, withAttributes: attributes)
        
        // Secondary icon overlay
        let secondaryIcon = "💰"
        let secondaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.width * 0.25),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        
        let secondarySize = secondaryIcon.size(withAttributes: secondaryAttributes)
        let secondaryRect = NSRect(
            x: size.width * 0.6,
            y: size.height * 0.15,
            width: secondarySize.width,
            height: secondarySize.height
        )
        
        secondaryIcon.draw(in: secondaryRect, withAttributes: secondaryAttributes)
        
        image.unlockFocus()
        return image
    }
    
    static func saveIcon(size: Int, filename: String) {
        let iconSize = CGSize(width: size, height: size)
        let icon = generateIcon(size: iconSize)
        
        guard let tiffData = icon.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to generate PNG for size \(size)")
            return
        }
        
        let url = URL(fileURLWithPath: filename)
        do {
            try pngData.write(to: url)
            print("✅ Generated \(filename) (\(size)x\(size))")
        } catch {
            print("❌ Failed to save \(filename): \(error)")
        }
    }
}

// Generate all required sizes
let sizes = [
    (20, "Icon-20.png"),
    (29, "Icon-29.png"),
    (40, "Icon-40.png"),
    (58, "Icon-58.png"),
    (60, "Icon-60.png"),
    (76, "Icon-76.png"),
    (80, "Icon-80.png"),
    (87, "Icon-87.png"),
    (120, "Icon-120.png"),
    (152, "Icon-152.png"),
    (167, "Icon-167.png"),
    (180, "Icon-180.png"),
    (1024, "Icon-1024.png")
]

let basePath = "~/moulinsart/PrivExpensIA/PrivExpensIA/Assets.xcassets/AppIcon.appiconset/"

// Create directory if needed
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: basePath) {
    try? fileManager.createDirectory(atPath: basePath, withIntermediateDirectories: true)
}

// Generate all icons
for (size, filename) in sizes {
    AppIconGenerator.saveIcon(size: size, filename: basePath + filename)
}

// Generate Contents.json
let contentsJson = """
{
  "images" : [
    {
      "filename" : "Icon-40.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-60.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-58.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-87.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-80.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-120.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-120.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-180.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-20.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-40.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-29.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-58.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-40.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-80.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-76.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-152.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-167.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "Icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsUrl = URL(fileURLWithPath: basePath + "Contents.json")
try? contentsJson.write(to: contentsUrl, atomically: true, encoding: .utf8)

print("✅ App Icon set generated successfully!")
print("📁 Location: \(basePath)")