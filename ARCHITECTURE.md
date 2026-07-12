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
│    ├─ ideviceinfo -u <udid> -x         (matériel/système/    │
│    │     cellulaire aussi décodés depuis ce dump global)      │
│    ├─ ideviceinfo -u <udid> -q com.apple.mobile.battery -x    │
│    ├─ ideviceinfo -u <udid> -q com.apple.disk_usage -x        │
│    ├─ ideviceinfo -u <udid> -q com.apple.mobile.backup -x     │
│    ├─ ideviceinfo -u <udid> -q com.apple.mobile.iTunes -x     │
│    │     (résolution écran uniquement, best-effort)           │
│    └─ idevicediagnostics -u <udid> ioregentry                 │
│         AppleSmartBattery  (enrichissement best-effort)       │
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
| Source des données | CLI libimobiledevice (`idevice_id`, `ideviceinfo`, `idevicediagnostics`) via `Process` | Outil open-source mature et largement utilisé (formule Homebrew `libimobiledevice`, officielle/bottled) ; évite de maintenir une couche d'interop C pour un MVP maintenu en solo |
| Format de données | plist XML (option `-x`) décodé avec `PropertyListDecoder` | Sortie stable et typée de `ideviceinfo`/`idevicediagnostics` |
| Composant carte UI | `MetricCard` porté fidèlement | Aligné sur le design system de MacInside, une autre app menu bar de Vincent |
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

## Diagnostics batterie enrichis

`idevicediagnostics ioregentry AppleSmartBattery` renvoie un plist bien plus riche que le domaine lockdown `com.apple.mobile.battery` : cycles de charge, capacités détaillées (design/nominale/pleine charge), tension, courant, puissance et type du chargeur, numéro de série batterie, et un blob `ManufacturerData` qui se décode en identifiant de cellule. Cet appel est traité comme un **enrichissement optionnel** (`try?`, même pattern que les appels des domaines batterie/disque) — le pourcentage de batterie de base et l'état de charge proviennent toujours du domaine `com.apple.mobile.battery` garanti, donc un échec ici se traduit juste par moins de lignes de détail, pas par une section batterie cassée.

Le pourcentage de santé batterie affiché dans l'UI est calculé par `round(NominalChargeCapacity / DesignCapacity * 100)` (`BatteryCapacityDetail.healthPercent` dans `iPhoneStatusInfo.swift`) — ce qui reproduit exactement le pourcentage affiché dans Réglages iOS sous Santé de la batterie, vérifié sur un vrai device. Deux champs sont délibérément **non affichés** : un nom de fabricant batterie deviné (aucun mapping vérifié préfixe de série→fabricant trouvé) et la température (non exposée par cette méthode — affichée comme un placeholder même par l'outil tiers utilisé comme référence pendant le développement).

## Statut « très très complet »

Au-delà de la batterie, le popover affiche près de 20 champs supplémentaires, la plupart décodés depuis le dump global déjà récupéré `ideviceinfo -u <udid> -x` (`DeviceGlobalInfo` dans `iPhoneStatusInfo.swift`) — aucun appel process supplémentaire nécessaire pour ceux-là : matériel (`HardwareModel`, `ModelNumber`, `CPUArchitecture`), système (`HumanReadableProductVersionString` avec un badge Beta quand `ReleaseType == "Beta"`, `ActivationState`, `TimeZone`), et cellulaire (`TelephonyCapability`, `SIM1IsEmbedded`, `SIMStatus`, IMEI/IMEI2, ICCID, IMSI, numéro de téléphone, nom d'opérateur dérivé de `CarrierBundleInfoArray`). Deux appels domaine optionnels supplémentaires ont été ajoutés en suivant le même pattern `try?` de dégradation gracieuse : `com.apple.mobile.backup` (statut sauvegarde iCloud) et `com.apple.mobile.iTunes` (résolution écran uniquement — décodé dans un struct étroit `DeviceScreenInfo` qui ignore les ~2400 lignes de certificats FairPlay en blobs que renvoie le reste de ce domaine).

Les champs cellulaires (IMEI, IMEI2, ICCID, IMSI, numéro de téléphone) sont **masqués par défaut** (`SensitiveDataMasking.apply`, ne garde que les 4 derniers caractères, ex. `••••9012`) depuis le passage de l'app à un usage public. Un bouton œil dans l'en-tête de la carte Cellulaire (`@AppStorage("showSensitiveIdentifiers")`) permet de révéler/masquer à la volée, réglage persisté par machine. Ce comportement remplace la décision initiale d'affichage sans masquage (justifiée à l'époque par un usage strictement personnel) — voir `TESTDEVICESN01`/`TESTCELLIDVALUE1` etc. dans les fixtures de test, volontairement synthétiques depuis l'audit de données perso avant publication.

`DeviceGlobalInfo` porte un initialiseur écrit à la main (pas seulement celui synthétisé automatiquement) qui donne une valeur par défaut `nil` à chaque champ ajouté après les 8 champs d'origine, pour que les call-sites existants (tests écrits avant l'existence de ces champs) continuent de compiler sans avoir à les passer.

## Layout du popover : deux colonnes, sans scroll

Avec le contenu de 4 cartes, une seule colonne défilante ne tient plus dans un popover de barre de menu sans forcer l'utilisateur à scroller (demande explicite de Vincent : cartes côte à côte "comme MacInside", sans scroll). Le cas `.connected` de `PopoverContentView` dispose les 4 `MetricCard` sur deux colonnes de largeur fixe (318pt) dans un `HStack` — Batterie+Stockage à gauche, Appareil+Cellulaire (conditionnelle) à droite — au lieu d'une `ScrollView` + `VStack` unique. La vue de contenu externe fait `680pt` de large et utilise `.fixedSize(horizontal: false, vertical: true)` pour que sa hauteur suive le contenu réel plutôt qu'une valeur figée.

`StatusMenuController` ne fixe plus manuellement `NSPopover.contentSize` ; à la place, `NSHostingController.sizingOptions = [.preferredContentSize]` (macOS 13+) est utilisé pour que le popover se redimensionne automatiquement à la hauteur naturelle du contenu SwiftUI à chaque changement (ex. apparition/disparition de la carte Cellulaire). Plus robuste que de deviner une hauteur fixe, car la hauteur réelle du contenu varie selon le device (badge Beta, IMEI2 dual-SIM, capacité cellulaire, etc.).

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
| `iPhoneStatusInfo.swift` | Modèles `Decodable` de plist (`DeviceGlobalInfo` — champs matériel/système/cellulaire étendus, `CarrierBundleInfo`, `DeviceBatteryInfo`, `DeviceDiskUsageInfo`, `DeviceBackupInfo`, `DeviceScreenInfo`, `BatterySmartInfo`/`BatterySmartRegistry`/`BatteryCapacityDetail`/`AdapterDetail`) + le struct combiné `iPhoneStatusInfo` |
| `DeviceConnectionState.swift` | Enums `DeviceConnectionState` / `TrustIssue` + `StderrClassifier` |
| `MetricCard.swift` | Composant carte réutilisable (`MetricCard`, `InfoRow`, `StatusDotRow`) porté du design system de MacInside |
| `PopoverContentView.swift` | Contenu SwiftUI du popover — une branche par cas de `DeviceConnectionState` ; `.connected` affiche 4 `MetricCard` côte à côte sur deux colonnes de largeur fixe (Batterie+Stockage, Appareil+Cellulaire — cette dernière conditionnelle à `hasCellularInfo`), sans `ScrollView` |

## Tests (`iPhoneStatusTests/`)

| Fichier | Rôle |
|---|---|
| `PlistParsingTests.swift` | Décode des plists XML de fixture dans les modèles `Decodable` (y compris les champs étendus de `DeviceGlobalInfo`, `DeviceBackupInfo`, `DeviceScreenInfo`) et vérifie `iPhoneStatusInfo.combining(...)` (y compris le calcul `usedDiskCapacity`, la dérivation du nom d'opérateur, et les valeurs de repli par défaut) |
| `BatterySmartInfoParsingTests.swift` | Décode une fixture de plist `ioregentry AppleSmartBattery`, vérifie la formule de santé, le décodage `ManufacturerData` → ID cellule, les champs étendus (`AvgTimeToEmpty`, `FullyCharged`, `AtCriticalLevel`, `NominalChargeCapacity`), et la dégradation gracieuse si l'appel d'enrichissement échoue |
| `ErrorDetectionTests.swift` | Envoie des chaînes `stderr` d'exemple à `StderrClassifier.classify(_:)` et vérifie le `TrustIssue` obtenu |

Les 29 tests sont des tests de fonctions pures — aucune exécution de `Process`, aucun device physique requis.

## Hors périmètre du MVP

Les réglages (intervalle de rafraîchissement, Launch at Login), l'auto-update Sparkle, et un pipeline de release signé/notarisé ont été délibérément laissés de côté — voir `TODOS.md`.
