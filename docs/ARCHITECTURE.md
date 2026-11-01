# Architecture

## System

```mermaid
flowchart LR
  subgraph Device
    UI[Screens] --> S[AppStore interface]
    S --> C[Feature controllers]
    C --> B[Backend interface]
    B --> FB[FirebaseBackend]
    S -. debug only .-> DS[DemoAppStore]
  end
  FB -->|callable| CF[Cloud Functions]
  FB -->|read, own writes| FS[(Firestore)]
  FB -->|own uploads| ST[(Storage)]
  FB --> AU[Firebase Auth]
  CF --> FS
  CF --> ST
  CF --> AU
  CF --> FCM[Cloud Messaging]
  CF --> Stores[Apple and Google stores]
  FCM --> Device
```

**The rules:**

1. Every decision with consequences runs in a Cloud Function. Security rules are the
   boundary, and route guards are only for navigation.
2. A client writes only its own draft, read markers, journey step, answers, messages, and
   device tokens.
3. The server is the only source of truth for stage, claims, quotas, credits and
   entitlement.
4. Screens never touch Firebase. They talk to a controller; a controller talks to
   `Backend`.

## Flutter layers

| Layer | Location | Responsibility |
|---|---|---|
| Screens and widgets | `lib/screens`, `lib/widgets` | Rendering and local UI state |
| Feature controllers | `lib/features/*` | One `ChangeNotifier` per feature |
| Interface | `lib/providers/app_store.dart` | What screens see while they migrate to controllers |
| Production facade | `lib/providers/remote_app_store.dart` | Delegates to controllers |
| Demo | `lib/providers/demo_app_store.dart` | Debug-only local simulation, never in release |
| Backend interface | `lib/data/backend.dart` | The contract with the server |
| Implementation | `lib/data/firebase_backend.dart` | Firebase |
| Models | `lib/models` | Data and serialisation |

`lib/features` holds only what has been extracted. Files are not moved for their own sake.

## Backend

`functions/src/rules.ts` holds pure decision logic with no Firebase dependency, so each rule
has a unit test. The other modules hold Firebase code and call into it.

## Application start

```mermaid
flowchart TD
  A[Native splash] --> B[Firebase init]
  B -->|config missing| X[Setup required screen]
  B --> C[Restore auth session]
  C -->|signed out| L[Landing]
  C -->|signed in| D[Load account and draft]
  D -->|load failed| R[Retry screen]
  D -->|reviewer or member| E{Review stage}
  E -->|draft| S[Start or resume onboarding]
  E -->|submitted| W[Review pending]
  E -->|changes requested or rejected| F[Reason and edit]
  E -->|approved| P{Pledge accepted}
  P -->|no| Q[Approval pledge]
  P -->|yes| H[Home tabs]
  E -->|deleting| Z[Deletion status]
```

## Profile lifecycle

```mermaid
stateDiagram-v2
  [*] --> draft
  draft --> submitted: submitProfile
  submitted --> approved: reviewer approves
  submitted --> changes_requested: reviewer asks for changes
  submitted --> rejected: reviewer rejects
  changes_requested --> submitted: member resubmits
  rejected --> submitted: member resubmits
  approved --> approved: edits reviewed
  approved --> held: three reporters
  held --> approved: reviewer releases
  approved --> deactivated: member pauses
  deactivated --> approved: member returns
```

The server snapshots a submission. Approval publishes that snapshot, never the live draft.

## Proposal to match

```mermaid
stateDiagram-v2
  [*] --> pending: sendProposal
  pending --> accepted: recipient accepts, or a crossing proposal
  pending --> declined: recipient declines, or a block
  pending --> withdrawn: sender withdraws
  pending --> expired: scheduler
  accepted --> [*]: match opens
```

A match exists only through `openMatch`, called from a transaction after both sides have
acted. Every terminal state is final.

## Decisions

Recorded in `IMPLEMENTATION_ROADMAP.md`.
