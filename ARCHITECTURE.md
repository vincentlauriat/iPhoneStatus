# Architecture — iPhoneStatus

## Vue d'ensemble

```
┌───────────────────────────────────────────────────────────┐
│                  Barre de menu macOS                       │
│   icône iphone, colorée selon l'état :                     │
│   vert = connecté · orange = en attente de confiance ·     │
│   rouge = libimobiledevice absent · gris = aucun device      │
└─────────────────────────┬───────────────────────────────────┘
                          │ clic
                          ▼
┌───────────────────────────────────────────────────────────┐
│         iPhoneStatus.app (AppKit + SwiftUI, macOS 14+)     │
│                                                              │
│  StatusMenuController (NSStatusItem + NSPopover, transient) │
│    └─ NSHostingController → PopoverContentView (SwiftUI)    │
│         4 états : binaires absents / aucun device /         │
│                    en attente de confiance / connecté       │
│                                                              │
│  DeviceMonitor (actor, AsyncStream<DeviceConnectionState>)  │
│    ├─ poll présence :  idevice_id -l          toutes les ~2s│
│    └─ poll détails :   ideviceinfo (3 appels) toutes les    │
│                        ~10s, popover ouvert uniquement       │
│                                                              │
│  LibimobiledeviceService (Sendable, wrapping Process)        │
│    ├─ idevice_id -l                                          │
│    ├─ ideviceinfo -u <udid> -x                                │
│    ├─ ideviceinfo -u <udid> -q com.apple.mobile.battery -x    │
│    └─ ideviceinfo -u <udid> -q com.apple.disk_usage -x        │
│                                                              │
│  CLI libimobiledevice (Homebrew : /opt/homebrew/bin)         │
│    └─ usbmuxd (intégré à macOS) ──USB/pairing── iPhone       │
└───────────────────────────────────────────────────────────┘
```

## Stack technique

| Couche | Choix | Raison |
|---|---|---|
| Langage | Swift 5.9+ | Natif macOS |
| Coquille UI | AppKit (`NSStatusItem`, `NSPopover`) | Exigence explicite — app menu bar AppKit, pas `MenuBarExtra` SwiftUI |
| Contenu du popover | SwiftUI, hébergé via `NSHostingController` | Itération plus rapide sur les 4 états d'UI tout en gardant la coquille AppKit |
| Source des données | CLI libimobiledevice (`idevice_id`, `ideviceinfo`) via `Process` | Outil open-source mature et largement utilisé (formule Homebrew `libimobiledevice`, officielle/bottled) ; évite de maintenir une couche d'interop C pour un MVP maintenu en solo |
| Format de données | plist XML (option `-x`) décodé avec `PropertyListDecoder` | Sortie stable et typée de `ideviceinfo` |
| Concurrence | Swift Concurrency (`actor`, `AsyncStream`), `SWIFT_STRICT_CONCURRENCY: targeted` | Aligné sur la convention WifiManager/NetCheck (patron `ConnectivityMonitor`) |
| Tests | XCTest (`iPhoneStatusTests`) | Fonctions pures (parsing plist, classification stderr) — aucun device physique requis |
| Génération de projet | [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Aligné sur tous les projets sœurs |

## Pourquoi shell-out plutôt que lier la bibliothèque C libimobiledevice

Lier directement les en-têtes C de `libimobiledevice`/`libplist` éviterait le parsing texte/plist et donnerait des codes d'erreur typés, mais nécessite une module map C, une gestion manuelle de la mémoire autour de `idevice_t`/`lockdownd_client_t`, et une maintenance continue à mesure que l'API C amont évolue. Pour un utilitaire menu bar maintenu par une seule personne, shell-out vers les CLI (`idevice_id`, `ideviceinfo`) et parser leur sortie plist stable est le meilleur compromis — les binaires sont matures, le format de sortie est documenté et stable, et il n'y a aucune surface d'interop C à maintenir.

## Flux de confiance / pairing

`ideviceinfo` échoue avec un code de sortie non nul tant que le dialogue "Faire confiance à cet ordinateur" n'a pas été validé sur l'iPhone. `LibimobiledeviceService` capture stdout et stderr sur des **pipes séparés** (les mélanger corromprait le parseur de plist), et `StderrClassifier` fait correspondre le texte stderr, insensible à la casse, à un petit ensemble de sous-chaînes :

- contient `"denied"` → `.denied` ("La confiance a été refusée")
- contient `"password"` → `.passwordProtected` ("iPhone verrouillé par un code")
- tout le reste (couvre `"pending"`, `"trust"`, `"pair"`, `"lockdown"`, et tout message non reconnu) → `.pendingConfirmation` ("En attente de confiance")

Ce repli générique est délibéré : le libellé exact des messages d'erreur de `lockdownd` n'est pas garanti stable d'une version de libimobiledevice à l'autre, donc un message non reconnu se dégrade gracieusement vers le cas le plus courant plutôt que d'afficher une erreur brute.

## Stratégie de polling

- La **présence** (`idevice_id -l`) est sondée toutes les ~2s, que le popover soit ouvert ou non — c'est un appel local léger à `usbmuxd` qui ne nécessite pas de pairing.
- Les **détails** (`ideviceinfo` × 3 appels) sont récupérés une fois immédiatement à la détection d'un nouveau device, puis re-sondés toutes les ~10s **uniquement pendant que le popover est ouvert** — inutile de rafraîchir batterie/stockage quand l'utilisateur ne regarde pas.

## Sources Swift (`iPhoneStatus/Sources/`)

| Fichier | Rôle |
|---|---|
| `iPhoneStatusApp.swift` | Point d'entrée `@main` SwiftUI `App`, câble `AppDelegate` via `@NSApplicationDelegateAdaptor` |
| `AppDelegate.swift` | Définit la politique d'activation `.accessory` (pas d'icône Dock), crée `StatusMenuController` |
| `StatusMenuController.swift` | `NSStatusItem` + `NSPopover`, icône colorée selon l'état, possède `DeviceMonitor` et `DeviceStatusViewModel` |
| `DeviceMonitor.swift` | `actor` ; boucles de polling présence/détails ; publie un `AsyncStream<DeviceConnectionState>` |
| `LibimobiledeviceService.swift` | Encapsule les appels `Process` vers les binaires CLI ; classifie les échecs |
| `LibimobiledeviceBinaryLocator.swift` | Localise `idevice_id`/`ideviceinfo` sous `/opt/homebrew/bin` ou `/usr/local/bin` |
| `iPhoneStatusInfo.swift` | Modèles `Decodable` de plist (`DeviceGlobalInfo`, `DeviceBatteryInfo`, `DeviceDiskUsageInfo`) + le struct combiné `iPhoneStatusInfo` |
| `DeviceConnectionState.swift` | Enums `DeviceConnectionState` / `TrustIssue` + `StderrClassifier` |
| `PopoverContentView.swift` | Contenu SwiftUI du popover, une branche par cas de `DeviceConnectionState` |

## Tests (`iPhoneStatusTests/`)

| Fichier | Rôle |
|---|---|
| `PlistParsingTests.swift` | Décode des plists XML de fixture dans les modèles `Decodable` et vérifie `iPhoneStatusInfo.combining(...)` (y compris le calcul `usedDiskCapacity` et les valeurs de repli par défaut) |
| `ErrorDetectionTests.swift` | Envoie des chaînes `stderr` d'exemple à `StderrClassifier.classify(_:)` et vérifie le `TrustIssue` obtenu |

Les deux sont des tests de fonctions pures — aucune exécution de `Process`, aucun device physique requis.

## Hors périmètre du MVP

Les réglages (intervalle de rafraîchissement, Launch at Login), l'auto-update Sparkle, et un pipeline de release signé/notarisé ont été délibérément laissés de côté — voir `TODOS.md`.
