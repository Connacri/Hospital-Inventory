import os
import subprocess
import re
import sys
from datetime import datetime

def run_command(args, shell=True, check=True):
    """Exécute une commande et retourne la sortie standard."""
    try:
        # Sur Windows, shell=True est nécessaire pour les fichiers .bat comme flutter
        result = subprocess.run(
            args, 
            shell=shell, 
            check=check, 
            capture_output=True, 
            text=True,
            encoding='utf-8'
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        if check:
            cmd_str = " ".join(args) if isinstance(args, list) else args
            print(f"❌ Erreur lors de l'exécution de : {cmd_str}")
            print(f"Sortie d'erreur : {e.stderr}")
            sys.exit(1)
        return None

def check_tools():
    """Vérifie que les outils nécessaires sont installés."""
    tools = ['flutter', 'git', 'gh', 'python']
    for tool in tools:
        try:
            # shell=True est vital ici pour Windows pour détecter flutter.bat, etc.
            subprocess.run(f"{tool} --version", shell=True, capture_output=True, check=True)
        except Exception:
            print(f"❌ Erreur : L'outil '{tool}' est introuvable.")
            print(f"💡 Vérifiez que {tool} est bien dans votre variable d'environnement PATH.")
            sys.exit(1)

def main():
    if not os.path.exists('pubspec.yaml'):
        print("❌ Erreur : Lancez le script depuis la racine du projet.")
        sys.exit(1)

    check_tools()
    
    repo_url = 'https://github.com/Connacri/Hospital-Inventory.git'
    
    print("--- 1. Synchronisation des versions GitHub ---")
    run_command("git fetch --tags origin")

    # Recherche du dernier tag sur GitHub
    current_version = "1.0.0+0"
    tag = run_command("git describe --tags --abbrev=0", check=False)

    if tag and re.match(r"v\d+\.\d+\.\d+\+\d+", tag):
        current_version = tag.lstrip('v')
        print(f"✅ Version GitHub la plus récente : {current_version}")
    else:
        print("ℹ️ Aucun tag trouvé sur GitHub. Lecture du pubspec.yaml local...")
        with open("pubspec.yaml", 'r', encoding='utf-8') as f:
            content = f.read()
            match = re.search(r"^version:\s*(\d+\.\d+\.\d+\+\d+)", content, re.MULTILINE)
            if match:
                current_version = match.group(1)

    print(f"📈 Version de référence : {current_version}")

    print("\n--- 2. Incrémentation du numéro de build ---")
    # Format attendu : X.Y.Z+Build
    match = re.match(r"(\d+\.\d+\.\d+)\+(\d+)", current_version)
    if match:
        ver_base = match.group(1)
        new_build = int(match.group(2)) + 1
        new_version = f"{ver_base}+{new_build}"
    else:
        new_version = "1.0.0+1"
    
    new_tag = f"v{new_version}"

    # Mise à jour du fichier local
    with open("pubspec.yaml", 'r', encoding='utf-8') as f:
        lines = f.readlines()
    with open("pubspec.yaml", 'w', encoding='utf-8') as f:
        for line in lines:
            if line.startswith("version:"):
                f.write(f"version: {new_version}\n")
            else:
                f.write(line)
    
    print(f"🚀 Nouvelle version préparée : {new_version}")

    description = f"""🚀 IA Release {new_version} ({datetime.now().strftime('%d/%m/%Y %H:%M')})

CHANGELOG :
- UI : Thème Playfair Display expert, contrastes et tailles augmentées.
- UX : Navigation adaptative (PC/Mobile) via LayoutBuilder.
- Auth : Système sécurisé avec appairage QR Code (Provisioning).
- Admin : Gestion complète Utilisateurs, Services et Catégories.
- Sync : Intégration cloud Supabase avec résolution de conflits.
- Fix : Optimisation des filtres ObjectBox pour les alertes stock.
"""

    print("\n--- 3. Build APK Release (Obfuscation) ---")
    # On utilise subprocess.call pour voir la progression flutter en direct
    # Correction: flutter build apk est souvent un .bat sur Windows
    build_cmd = "flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols"
    ret = subprocess.call(build_cmd, shell=True)
    if ret != 0:
        print("❌ Échec du build Flutter.")
        sys.exit(1)

    print("\n--- 4. Git Commit & Push ---")
    # Création d'un fichier de message pour éviter les problèmes de caractères spéciaux
    with open("commit_msg.txt", "w", encoding="utf-8") as f:
        f.write(description)
    
    run_command("git add .")
    run_command("git commit -F commit_msg.txt")
    os.remove("commit_msg.txt")
    
    # Récupération branche actuelle
    branch = run_command("git rev-parse --abbrev-ref HEAD")
    print(f"📤 Envoi vers GitHub (branche {branch})...")
    run_command(f"git push origin {branch}")

    print("\n--- 5. Création de la Release GitHub ---")
    run_command(f"git tag {new_tag}")
    run_command(f"git push origin {new_tag}")

    apk_path = "build/app/outputs/flutter-apk/app-release.apk"
    # Création du fichier temporaire pour les notes de release
    with open("release_notes.txt", "w", encoding="utf-8") as f:
        f.write(description)

    # Commande gh release avec notes-file pour éviter les problèmes de quotes
    release_cmd = f'gh release create {new_tag} "{apk_path}" --title "Release {new_tag}" --notes-file release_notes.txt'
    
    result = subprocess.run(release_cmd, shell=True)
    if os.path.exists("release_notes.txt"):
        os.remove("release_notes.txt")

    if result.returncode == 0:
        print(f"\n✨ SUCCÈS : L'application est publiée !")
        print(f"🔗 https://github.com/Connacri/Hospital-Inventory/releases/tag/{new_tag}")
    else:
        print("\n⚠️ Release créée mais l'upload de l'APK a échoué (gh non connecté ?)")

if __name__ == "__main__":
    main()
