# Movement Anti-Cheat

A lightweight Roblox movement anti-cheat built around server-side validation, client movement samples, and server correction.

The system is designed to catch common movement abuse without replacing Roblox's default character controller. It watches player movement from the server, compares it against expected limits, and reacts when movement looks unsafe or impossible.

## What It Checks

- WalkSpeed values above the configured limit
- Large position jumps or teleport-like movement
- Sustained speed above the allowed movement window
- Acceleration spikes
- Hovering or slow fall
- Noclip movement through collidable parts
- Suspicious vertical velocity
- Bad ground states, steep slopes, or missing floor data
- Client/server position desync
- Replayed, malformed, or out-of-order movement packets
- Network ownership mismatches

## How It Works

Clients send compact movement samples at a fixed rate. The server unpacks those samples, rate-limits them, and compares them with server-observed character data. Each player has a session that stores recent samples, score data, safe positions, and short grace windows for respawns or safe teleports.

When a violation is detected, the system can:

- Log the violation
- Add score toward punishment
- Correct the player back to the last safe position
- Reset unsafe velocity
- Kick the player if the configured punishment score is reached

## Folder Layout

```text
ReplicatedStorage
└── App
    ├── Config
    │   └── MovementConfig
    ├── Enums
    │   └── Reason
    ├── Networking
    │   ├── MovementPackets
    │   └── MovementRemotes
    ├── Types
    │   └── MovementTypes
    └── Utilities
        ├── Janitor
        ├── MovementMath
        ├── RateLimiter
        └── Trail

ServerScriptService
└── App
    ├── Services
    │   └── MoveAC
    ├── SubServices
    │   ├── MoveSampler
    │   ├── MovementChecks
    │   ├── MovementRemotes
    │   ├── PhysicsChecks
    │   ├── PlayerSession
    │   ├── Reconciler
    │   └── ViolationHandler
    ├── Modules
    │   └── ServiceRunner
    ├── Debug
    │   └── Logger
    └── Types
        └── ServerTypes
```

## Setup

1. Put the shared modules in `ReplicatedStorage.App`.
2. Put the server modules in `ServerScriptService.App`.
3. Keep the main boot script in `ServerScriptService`.
4. Make sure the boot script requires `ServerScriptService.App.Services.MoveAC`.
5. Adjust values in `ReplicatedStorage.App.Config.MovementConfig` for your game.

The remote folder is created automatically if it does not already exist.

## Public API

`MoveAC` exposes a few server-side methods:

```lua
MoveAC:SetExempt(player, true)
MoveAC:SetExempt(player, false)
MoveAC:NoteSafeTeleport(player, cframe, "reason")
MoveAC:SetDebug(true)
MoveAC:SetDebug(false)
```

Use `SetExempt` for trusted temporary states where movement checks should be ignored.

Use `NoteSafeTeleport` before or after server-controlled teleports so the anti-cheat does not treat the move as an exploit.

## Configuration

Most behavior is tuned from `MovementConfig`.

Important values include:

- `serverHz` and `clientHz` for sampling rate
- `maxSpeed`, `speedMult`, and `speedMargin` for speed checks
- `maxTeleport` for teleport-like movement
- `maxAirTime`, `hoverTopY`, and `hoverHoldFrames` for fly checks
- `fixGrace`, `fixCooldown`, and `fixScore` for correction behavior
- `kickEnabled`, `kickScore`, and `kickMessage` for final punishment

## Notes

- The server does not fully trust client movement packets.
- Short grace windows are used for respawns, safe teleports, and landing edge cases.
- Climbing, swimming, ragdoll, and similar states are treated more leniently to reduce false positives.
- This is not a complete exploit prevention system.
