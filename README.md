## XAML Interface Management Script

Ce dépôt contient un script PowerShell pour gérer une interface utilisateur XAML. Le script permet de charger une interface XAML, de gérer les événements et les interactions utilisateur, et d'effectuer des opérations sur Active Directory et les permissions NTFS.

### Fonctionnalités

- **Chargement de l'interface XAML** : Utilise `PresentationFramework` et `System.Windows.Forms` pour charger et afficher une interface utilisateur définie dans un fichier XML.
- **Gestion des logs** : Fonctions pour écrire des messages d'erreur et d'information dans des fichiers de log.
- **Activation/Désactivation des champs** : Fonctions pour activer ou désactiver les champs de l'interface en fonction des interactions utilisateur.
- **Recherche Active Directory** : Fonction pour rechercher des utilisateurs dans Active Directory par `SamAccountName`, `DisplayName` ou `Mail`.
- **Gestion des permissions NTFS** : Fonction pour obtenir et filtrer les permissions NTFS sur un répertoire sélectionné.
- **Événements et interactions** : Gestion des événements pour les boutons et les champs de texte, y compris la recherche d'utilisateurs et la sélection de répertoires.

### Utilisation

1. **Charger l'interface** : Le script charge l'interface XAML à partir d'un fichier XML spécifié.
2. **Interagir avec l'interface** : Les utilisateurs peuvent interagir avec les champs et les boutons pour effectuer des recherches et gérer les permissions.
3. **Logs** : Les erreurs et les informations sont enregistrées dans des fichiers de log pour un suivi et une résolution faciles.

### Prérequis

- PowerShell
- Modules `PresentationFramework` et `System.Windows.Forms`
- Accès à Active Directory pour les recherches d'utilisateurs
- Permissions nécessaires pour lire et modifier les permissions NTFS

### Installation

1. Clonez le dépôt :
   ```sh
   git clone https://github.com/votre-utilisateur/votre-repo.git
2. Accédez au répertoire du projet :
cd votre-repo
3. Exécutez le script PowerShell :
.\votre-script.ps1
