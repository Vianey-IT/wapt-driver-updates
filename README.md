# wapt-driver-updates
Paquets WAPT — Mise à jour automatique pilotes + BIOS — HP (HPCMSL) · Dell (DCU CLI) · Lenovo (LSUClient)

Ensemble de paquets WAPT permettant d'automatiser les mises à jour de pilotes, BIOS et firmware sur un parc hétérogène HP, Dell et Lenovo.

Développé et testé sur **WAPT 2.6.1** / **Windows 10-11**.

---

## Présentation

### Problématique

Les outils constructeurs installés directement sur les postes (HP Support Assistant, Dell Command Update en mode UI) ne sont pas maintenables en entreprise : mises à jour manuelles, pas de visibilité sur l'état du parc, pas de traçabilité.

### Solution

Une architecture WAPT basée sur 3 paquets groupe (un par constructeur), chacun composé de :

- Un paquet **outil** installant le moteur de mise à jour adapté
- Un paquet **scheduled** déployant une tâche planifiée hebdomadaire pour les drivers
- Un paquet **audit** remontant le statut dans la console WAPT

Et un paquet **now** par constructeur pour la mise en service complète (drivers + BIOS + Firmware).

---

## Architecture

```
Paquet groupe (par constructeur)
├── Paquet outil        ← moteur de mise à jour (HPCMSL / LSUClient / DCU CLI)
├── Paquet scheduled    ← tâche planifiée hebdomadaire (drivers uniquement)
└── Paquet audit        ← remontée statut console WAPT (commun aux 3 constructeurs)

Paquet now (par constructeur, hors groupe)
└── Tâche temporaire    ← mise en service (drivers + BIOS + Firmware, déclenchement manuel)
```

### Outils utilisés par constructeur

| Constructeur | Outil | Paquet outil |
|---|---|---|
| HP | HPCMSL (HP Client Management Script Library) | `tis-hpcmsl` |
| Dell | Dell Command Update CLI (`dcu-cli.exe`) | `tis-dell-command-update-uwp` (dépôt TIS) |
| Lenovo | LSUClient (module PowerShell open-source) | `tis-lsuclient-lenovo` |

---

## Paquets

### Paquets groupe

| Paquet groupe | Contenu |
|---|---|
| `Déploiement Pilotes HP` | `tis-hpcmsl` + `tis-driver-update-scheduled-hp` + `tis-audit-driver-update` |
| `Déploiement Pilotes Dell` | `tis-dell-command-update-uwp` + `tis-driver-update-scheduled-dell` + `tis-audit-driver-update` |
| `Déploiement Pilotes Lenovo` | `tis-lsuclient-lenovo` + `tis-driver-update-scheduled-lenovo` + `tis-audit-driver-update` |

### Paquets now (mise en service)

Déclenchés **manuellement** depuis la console WAPT lors de la mise en service d'un poste.

| Paquet | Catégories installées |
|---|---|
| `tis-driver-update-now-hp` | Drivers + BIOS + Firmware + Dock |
| `tis-driver-update-now-dell` | Drivers + BIOS |
| `tis-driver-update-now-lenovo` | Drivers + BIOS (via LSUClient, filtre `Unattended`) |

### Paquets scheduled (maintenance)

Tâche planifiée **permanente** sur le poste — lundi à 14h, rattrapage au démarrage si manqué (`StartWhenAvailable`).

| Paquet | Catégories installées |
|---|---|
| `tis-driver-update-scheduled-hp` | Drivers + Dock (sans BIOS ni Firmware) |
| `tis-driver-update-scheduled-dell` | Drivers (sans BIOS) |
| `tis-driver-update-scheduled-lenovo` | Drivers (sans BIOS, filtre `Type -ne BIOS`) |

### Paquet audit

`tis-audit-driver-update` — commun aux 3 constructeurs.

Lit `HKLM:\SOFTWARE\WAPT\DriverUpdate` et remonte dans la console WAPT :

| Statut | Condition |
|---|---|
| `OK` | Dernière MAJ réussie et récente (< 30 jours) |
| `WARNING` | Dernière MAJ > 30 jours ou clé registre absente |
| `ERROR` | Code retour invalide |

Le message inclut : fabricant, statut, ancienneté, détail et extrait du dernier log.

---

## Traçabilité

### Registre commun — `HKLM:\SOFTWARE\WAPT\DriverUpdate`

Alimenté par tous les paquets `now` et `scheduled` après chaque exécution.

| Valeur | Description |
|---|---|
| `LastRun` | Date/heure de la dernière exécution |
| `Manufacturer` | Fabricant détecté (HP, Dell Inc., LENOVO) |
| `LastStatus` | Statut lisible |
| `LastExitCode` | 0=rien / 1=MAJ installées / 3010=reboot requis / -1=erreur |
| `LastDetail` | Description détaillée |
| `LastLogFile` | Chemin du dernier fichier log |

Consultation rapide :
```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\WAPT\DriverUpdate'
```

### Trace HP — `HKLM:\SOFTWARE\WAPT\HPSoftpaqs`

Spécifique HP — évite la réinstallation systématique à chaque passage. Un SoftPaq n'est réinstallé que si HP publie une nouvelle version.

### Logs fichiers — `C:\Logs\wapt-drivers\`

Un fichier log horodaté par exécution :

```
C:\Logs\wapt-drivers\
├── hp_update_now_2026-07-01_09-07.log
├── hp_update_2026-06-30_14-00.log
├── dell_update_now.log
├── dell_update_2026-06-30_14-00.log
├── lenovo_update_now_2026-07-01_09-00.log
└── lenovo_update_2026-06-30_14-00.log
```

---

## Prérequis

### Généraux

- WAPT 2.6.x
- Accès internet sur les postes (téléchargement des drivers depuis les CDN constructeurs)
- PowerShell 5.1 minimum

### HP

- Télécharger `hp-cmsl-1.8.6.exe` depuis `https://hpia.hpcloud.hp.com/downloads/cmsl/hp-cmsl-1.8.6.exe` et le placer dans le paquet `tis-hpcmsl`
- NuGet et PowerShellGet sont mis à jour automatiquement par le paquet

### Dell

- Utiliser le paquet `tis-dell-command-update-uwp` du dépôt Tranquil IT
- Le paquet `tis-driver-update-scheduled-dell` et `tis-driver-update-now-dell` en dépendent

### Lenovo

- LSUClient s'installe depuis PowerShell Gallery — accès internet requis à l'installation du paquet `tis-lsuclient-lenovo`

---

## Installation

### 1. Déployer les paquets groupe sur le parc

Assigner le paquet groupe correspondant au fabricant sur les postes :
- `Déploiement Pilotes HP` → postes HP
- `Déploiement Pilotes Dell` → postes Dell
- `Déploiement Pilotes Lenovo` → postes Lenovo

WAPT résout automatiquement les dépendances et installe l'outil + la tâche planifiée + l'audit.

### 2. Mise en service d'un nouveau poste

Déclencher manuellement le paquet `now` correspondant au fabricant depuis la console WAPT.  
Le paquet installe tous les drivers + BIOS + Firmware, puis se valide en `OK` si tout s'est bien passé.  
Si la clé registre `HKLM:\SOFTWARE\WAPT\DriverUpdate` n'est pas créée après exécution, c'est qu'une erreur s'est produite.

### 3. Maintenance automatique

La tâche planifiée tourne chaque lundi à 14h. Si le poste était éteint ce jour-là, elle s'exécute au prochain démarrage (`StartWhenAvailable`).

---

## Points d'attention

- **Mutex** — un mutex par constructeur (`Global\HPDriverUpdate`, `Global\DellDriverUpdate`, `Global\LenovoDriverUpdate`) empêche les conflits si `now` et `scheduled` tournent simultanément
- **BIOS exclus du scheduled** — le flash BIOS est réservé au paquet `now` déclenché par un technicien, pour éviter tout risque en production non supervisée
- **Firmware SSD exclus du scheduled HP** — même raison
- **Erreurs réseau** — en cas de coupure internet pendant l'exécution, les SoftPaqs non téléchargés seront retentés à la prochaine exécution (non tracés en cas d'échec)
- **Plateforme non supportée** — si HPCMSL ou LSUClient ne trouve pas de catalogue pour le modèle, une erreur est loggée et le paquet remonte `ERROR` dans l'audit

---

## Structure du dépôt

```
wapt-driver-updates/
├── README.md
├── hp/
│   ├── setup_now.py
│   ├── setup_scheduled.py
│   ├── setup_hpcmsl.py
│   ├── create_task_hp_now.ps1
│   ├── create_task_hp.ps1
│   ├── run_driver_updates_hp_now.ps1
│   └── run_driver_updates_hp.ps1
├── dell/
│   ├── setup_now.py
│   ├── setup_scheduled.py
│   ├── create_task_dell.ps1
│   └── run_driver_updates_dell.ps1
├── lenovo/
│   ├── setup_now.py
│   ├── setup_scheduled.py
│   ├── create_task_lenovo_now.ps1
│   ├── create_task_lenovo.ps1
│   ├── run_driver_updates_lenovo_now.ps1
│   └── run_driver_updates_lenovo.ps1
└── audit/
    └── setup_audit.py
```

---

## Contributions

Les retours et améliorations sont les bienvenus — ouvrir une issue ou une pull request.

---

*Testé sur WAPT 2.6.1, Windows 10/11, parc HP / Dell / Lenovo
