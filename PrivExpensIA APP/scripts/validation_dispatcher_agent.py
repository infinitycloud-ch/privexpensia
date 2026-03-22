#!/usr/bin/env python3
"""
Agent Dispatcher Intelligent pour Validation
Analyse les rapports AI et dispatche automatiquement aux bonnes équipes
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Tuple

class ValidationDispatcher:
    """
    Agent qui analyse les erreurs et les assigne intelligemment
    """

    # Mapping des types d'erreurs vers les responsables
    RESPONSIBILITY_MATRIX = {
        # DUPONT2 - Localisation pure
        "underscore": "dupont2",
        "missing_translation": "dupont2",
        "wrong_translation": "dupont2",
        "lproj_file": "dupont2",
        "localizable_strings": "dupont2",

        # DUPONT1 - Code Swift/UI
        "localization_manager": "dupont1",
        "swift_implementation": "dupont1",
        "ui_layout": "dupont1",
        "glass_effect": "dupont1",
        "corner_radius": "dupont1",
        "hardcoded_text": "dupont1",
        "api_call": "dupont1",

        # TINTIN - Validation/Tests
        "test_failure": "tintin",
        "screenshot_issue": "tintin",
        "validation_needed": "tintin",

        # DÉCISIONS PARTAGÉES
        "date_format": "both",  # Dupont2 pour format, Dupont1 pour implémentation
        "currency_display": "both",
        "number_format": "both"
    }

    def __init__(self):
        self.tasks_dupont1 = []
        self.tasks_dupont2 = []
        self.tasks_tintin = []

    def analyze_error(self, error: Dict) -> Tuple[str, str]:
        """
        Analyse une erreur et détermine qui doit la corriger
        """
        problem = error.get('problem', '').lower()
        view = error.get('view', '')
        expected = error.get('expected', '')

        # Détection intelligente du responsable
        if '_' in problem or 'underscore' in problem:
            return 'dupont2', 'underscore'

        if any(keyword in problem for keyword in ['good morning', 'good evening', 'today\'s spending', 'budget left']):
            # C'est un texte non traduit
            if 'localizationmanager' in problem.lower():
                return 'dupont1', 'localization_manager'
            else:
                return 'dupont2', 'missing_translation'

        if 'corner' in problem or 'glass' in problem or 'transparent' in problem:
            return 'dupont1', 'ui_layout'

        if 'hardcoded' in problem or 'literal string' in problem:
            return 'dupont1', 'hardcoded_text'

        # Par défaut, si c'est une traduction
        if expected and problem != expected:
            return 'dupont2', 'wrong_translation'

        return 'tintin', 'validation_needed'

    def parse_ai_report(self, report_path: str) -> List[Dict]:
        """
        Parse le rapport AI et extrait les erreurs
        """
        errors = []

        with open(report_path, 'r') as f:
            content = f.read()

        # Extraire les problèmes avec regex
        pattern = r'⏱️ \[([^\]]+)\]\s+🌍 Langue: ([^\n]+)\s+📱 Vue: ([^\n]+)\s+❌ Problème: ([^\n]+)\s+✅ Attendu: ([^\n]+)\s+🚨 Priorité: ([^\n]+)'

        matches = re.findall(pattern, content)
        for match in matches:
            errors.append({
                'timestamp': match[0],
                'language': match[1],
                'view': match[2],
                'problem': match[3],
                'expected': match[4],
                'priority': match[5]
            })

        return errors

    def dispatch_tasks(self, errors: List[Dict]) -> Dict:
        """
        Dispatche les tâches aux bonnes personnes
        """
        for error in errors:
            assignee, error_type = self.analyze_error(error)

            task = {
                'error': error,
                'type': error_type,
                'action': self.generate_action(error, error_type)
            }

            if assignee == 'dupont1':
                self.tasks_dupont1.append(task)
            elif assignee == 'dupont2':
                self.tasks_dupont2.append(task)
            elif assignee == 'both':
                # Diviser la tâche intelligemment
                self.split_task(task)
            else:
                self.tasks_tintin.append(task)

        return {
            'dupont1': self.tasks_dupont1,
            'dupont2': self.tasks_dupont2,
            'tintin': self.tasks_tintin
        }

    def generate_action(self, error: Dict, error_type: str) -> str:
        """
        Génère une instruction d'action précise
        """
        view = error['view']
        problem = error['problem']
        expected = error['expected']
        lang = error['language']

        actions = {
            'underscore': f"Ajouter traduction pour '{problem}' → '{expected}' dans {lang}.lproj/Localizable.strings",
            'missing_translation': f"Traduire '{problem}' → '{expected}' dans {lang}.lproj, vue {view}",
            'localization_manager': f"Vérifier que LocalizationManager charge correctement la clé pour '{expected}' dans {view}",
            'hardcoded_text': f"Remplacer le texte hardcodé '{problem}' par LocalizedStringKey dans {view}",
            'ui_layout': f"Corriger le problème UI dans {view}: {problem}",
            'wrong_translation': f"Corriger la traduction dans {lang}.lproj: '{problem}' → '{expected}'"
        }

        return actions.get(error_type, f"Investiguer et corriger: {problem}")

    def split_task(self, task: Dict):
        """
        Divise une tâche complexe entre plusieurs agents
        """
        # Dupont2 s'occupe du fichier de traduction
        self.tasks_dupont2.append({
            **task,
            'action': f"Vérifier/ajouter les traductions dans les fichiers .lproj"
        })

        # Dupont1 s'occupe de l'implémentation
        self.tasks_dupont1.append({
            **task,
            'action': f"Vérifier l'utilisation correcte dans le code Swift"
        })

    def generate_emails(self, tasks: Dict) -> List[Dict]:
        """
        Génère les emails personnalisés pour chaque agent
        """
        emails = []

        # Email pour DUPONT1
        if tasks['dupont1']:
            email_dupont1 = {
                'to': 'dupont1@moulinsart.local',
                'subject': f"🔧 {len(tasks['dupont1'])} corrections Swift/UI requises",
                'body': self.format_email_body('DUPONT1', tasks['dupont1'], 'Swift/UI')
            }
            emails.append(email_dupont1)

        # Email pour DUPONT2
        if tasks['dupont2']:
            email_dupont2 = {
                'to': 'dupont2@moulinsart.local',
                'subject': f"🌍 {len(tasks['dupont2'])} traductions à corriger",
                'body': self.format_email_body('DUPONT2', tasks['dupont2'], 'Localisation')
            }
            emails.append(email_dupont2)

        # Email pour TINTIN
        if tasks['tintin']:
            email_tintin = {
                'to': 'tintin@moulinsart.local',
                'subject': f"🧪 Revalidation requise après corrections",
                'body': "Les corrections sont en cours. Prépare-toi à revalider."
            }
            emails.append(email_tintin)

        return emails

    def format_email_body(self, agent: str, tasks: List[Dict], domain: str) -> str:
        """
        Formate le corps de l'email avec les tâches
        """
        priority_map = {
            'CRITIQUE': '🔴',
            'HAUTE': '🟠',
            'MOYENNE': '🟡'
        }

        body = f"Bonjour {agent},\n\n"
        body += f"L'analyse AI a détecté {len(tasks)} problèmes dans ton domaine ({domain}):\n\n"

        # Grouper par priorité
        critical = [t for t in tasks if 'CRITIQUE' in t['error'].get('priority', '')]
        high = [t for t in tasks if 'HAUTE' in t['error'].get('priority', '')]
        medium = [t for t in tasks if 'MOYENNE' in t['error'].get('priority', '')]

        if critical:
            body += "🔴 CRITIQUE (à corriger immédiatement):\n"
            for task in critical:
                body += f"  - {task['action']}\n"
            body += "\n"

        if high:
            body += "🟠 HAUTE PRIORITÉ:\n"
            for task in high:
                body += f"  - {task['action']}\n"
            body += "\n"

        if medium:
            body += "🟡 PRIORITÉ MOYENNE:\n"
            for task in medium:
                body += f"  - {task['action']}\n"
            body += "\n"

        body += "Merci de traiter ces corrections dans l'ordre de priorité.\n"
        body += "Une fois terminé, lance: ./scripts/validation_video_ai.sh\n"

        return body

def create_dispatcher_instructions():
    """
    Crée les instructions pour un subagent Task
    """
    return """
Tu es un agent dispatcher intelligent pour la validation d'apps iOS.

Ton rôle:
1. Analyser les rapports d'erreurs de localisation
2. Déterminer QUI doit corriger QUOI
3. Envoyer des instructions PRÉCISES à chaque agent

Règles de dispatch:
- DUPONT2: Tout ce qui touche aux fichiers .lproj et traductions
- DUPONT1: Code Swift, LocalizationManager, UI
- TINTIN: Tests et revalidation
- Si les deux sont concernés, divise intelligemment

Pour chaque erreur, génère:
- Une action CONCRÈTE (pas "corriger le problème")
- Le fichier exact à modifier si possible
- La ligne de code ou la clé exacte

Sois PRÉCIS et ACTIONABLE.
"""

if __name__ == "__main__":
    import sys

    dispatcher = ValidationDispatcher()

    # Utiliser le dernier rapport
    if len(sys.argv) > 1:
        report_path = sys.argv[1]
    else:
        reports = list(Path("~/moulinsart/PrivExpensIA/validation/videos").glob("*_AI_analysis.md"))
        if reports:
            report_path = str(max(reports, key=lambda p: p.stat().st_mtime))
        else:
            print("❌ Aucun rapport trouvé")
            sys.exit(1)

    print(f"📊 Analyse du rapport: {Path(report_path).name}")
    print("="*60)

    # Parser les erreurs
    errors = dispatcher.parse_ai_report(report_path)
    print(f"📍 {len(errors)} erreurs trouvées")

    # Dispatcher
    tasks = dispatcher.dispatch_tasks(errors)

    # Afficher le résultat
    print(f"\n📧 Dispatch intelligent:")
    print(f"  → DUPONT1 (Swift/UI): {len(tasks['dupont1'])} tâches")
    print(f"  → DUPONT2 (Localisation): {len(tasks['dupont2'])} tâches")
    print(f"  → TINTIN (Validation): {len(tasks['tintin'])} tâches")

    # Générer les emails
    emails = dispatcher.generate_emails(tasks)

    # Sauvegarder les instructions
    output_dir = Path(report_path).parent
    for email in emails:
        agent_name = email['to'].split('@')[0]
        instruction_file = output_dir / f"instructions_{agent_name}.txt"

        with open(instruction_file, 'w') as f:
            f.write(f"To: {email['to']}\n")
            f.write(f"Subject: {email['subject']}\n\n")
            f.write(email['body'])

        print(f"\n📝 Instructions sauvées: {instruction_file}")

    print("\n✅ Dispatch terminé!")
    print("Les agents peuvent maintenant travailler en parallèle sur leurs tâches respectives.")