#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from pathlib import Path
import datetime

def print_colored(text, color):
    colors = {
        "green": 32, "yellow": 33, "blue": 34,
        "magenta": 35, "cyan": 36, "red": 31
    }
    color_code = colors.get(color, 0)
    print(f"\033[{color_code}m{text}\033[0m")

def find_files(extensions=[".swift", "info.plist"]):
    root = Path.cwd()
    print_colored(f"Scan du dossier: {root}", "blue")
    
    files = []
    for ext in extensions:
        if ext.startswith("."):
            files.extend(list(root.glob(f"**/*{ext}")))
        else:
            files.extend(list(root.glob(f"**/{ext}")))
    
    if not files:
        print_colored(f"Aucun fichier trouvé avec les extensions: {extensions}", "yellow")
        return []
    
    return root, files

def display_file_paths():
    root, files = find_files()
    if not files:
        return
    
    print_colored(f"{len(files)} fichiers trouvés:", "green")
    for file in files:
        relative_path = file.relative_to(root)
        print(f"- {relative_path}")

def generate_markdown_file():
    root, files = find_files()
    if not files:
        return
    
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    output_file = Path(f"code_output_{timestamp}.md")
    with output_file.open("w", encoding="utf-8") as f:
        f.write(f"# Code du projet `{root.name}`\n\n")
        f.write(f"## Généré le {datetime.datetime.now().strftime('%Y-%m-%d à %H:%M:%S')}\n\n")
        f.write("## Structure des dossiers\n\n")
        for dirpath, dirnames, filenames in os.walk(root):
            level = dirpath.replace(str(root), '').count(os.sep)
            indent = '  ' * level
            f.write(f"{indent}- {Path(dirpath).name}\n")

        f.write("\n---\n\n")

        print_colored(f"{len(files)} fichiers trouvés:", "green")
        for file in files:
            relative_path = file.relative_to(root)
            print(f"- {relative_path}")
            f.write(f"## {relative_path}\n\n")
            
            if file.suffix.lower() == ".swift":
                f.write("```swift\n")
            elif file.name.lower() == "info.plist":
                f.write("```xml\n")
            else:
                f.write("```\n")
                
            try:
                f.write(file.read_text(encoding='utf-8'))
            except Exception as e:
                f.write(f"// Erreur de lecture: {e}\n")
            f.write("\n```\n\n")

    print_colored(f"\n✅ Code extrait dans {output_file}", "cyan")

def show_menu():
    while True:
        print("\n" + "="*50)
        print_colored("ZORO - Explorateur de Code", "cyan")
        print("="*50)
        print("1. Afficher les chemins des fichiers (.swift et info.plist)")
        print("2. Générer un fichier Markdown avec structure et code")
        print("0. Quitter")
        
        choice = input("\nChoisissez une option (0-2): ")
        
        if choice == "1":
            display_file_paths()
        elif choice == "2":
            generate_markdown_file()
        elif choice == "0":
            print_colored("Au revoir!", "green")
            break
        else:
            print_colored("Option invalide. Veuillez réessayer.", "red")

def main():
    show_menu()

if __name__ == "__main__":
    main() 
