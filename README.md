# DEFENDER — prototype (étape 1 du dossier technique)

Contenu : menu principal, 1 mission (5 vagues), 3 emplacements de tours,
tours Archers / Feu / Glace, 3 ennemis (gobelin, orc, chauve-souris),
base avec points de vie, victoire/défaite, pause, vitesse x2, sauvegarde locale.

Jeu : choisir une tour en bas, toucher un emplacement pour construire,
retoucher pour améliorer (niveau 3 max), puis « Lancer la vague ».

## Dans Termux
    pkg update && pkg install unzip git
    termux-setup-storage
    cp ~/storage/downloads/DEFENDER.zip ~/ && unzip DEFENDER.zip && cd DEFENDER
    git init && git branch -M main
    git add . && git commit -m "Prototype DEFENDER"
    git remote add origin https://github.com/TON_COMPTE/DEFENDER.git
    git push -u origin main

Ensuite GitHub > Actions > « Build APK » > télécharger l'artefact DEFENDER-apk.
Vérifier les versions (Godot 4.3, modèles d'export, SDK Android) si la compilation échoue.
Tous les visuels sont dessinés par code ; ajouter vos ressources avec leur licence.
