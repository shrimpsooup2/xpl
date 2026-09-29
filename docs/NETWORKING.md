# xtrapartial — Multiplayer

Status: both styles built and tested on one machine: hosting from the menu, joining, dedicated servers, a lobby, and every part of a game played over the network (see [Phases](#phases), and [Known limits](#known-limits) for what isn't done). Not yet tested over a real network with latency and packet loss. Expands GDD §15.2.

## Goals

- **Two ways to play online, one game.** A player can host from the menu and friends join them (player-hosted), or anyone can run a **dedicated server**: the same game, headless, no window, that players connect to.
- **Fair and smooth at 60 Hz.** The movement is the game, so your own movement must feel local (prediction), everyone else must move smoothly (interpolation), and shots must land on what you saw (lag compensation).
- **Safe by default.** Nothing a client sends is trusted, nothing a server sends can make a client run code or load arbitrary files, and the risks we can't remove are written down (below) so players and server operators know them.

## Two ways to play online

| | Player-hosted | Dedicated server |
|---|---|---|
| Who runs the game | One player's game (the host) is also the server; the others connect to it | A headless build of the game (`--server`), on any machine or VPS |
| Starts from | The menu: *host*, pick a style and map pool, share your address | A command line and a config file (see [Running a server](#running-a-server)) |
| Authority | The host's machine | The server |
| Players | 2–8 | 2–16 (the team maps are built for 8, 4 a side) |
| Reaching it | Direct address (LAN, or the host's public address with the port forwarded; the game tries UPnP to forward it automatically). A relay (Steam or noray) later, to get through NAT without port forwarding and to hide addresses | Direct address and port |
| Best for | Friends, LAN, quick games | Public games, communities, anything competitive |

"Player-hosted" is often called peer-to-peer, but it's a **listen server**: one machine decides the game and everyone talks to it, never to each other. A true peer-to-peer mesh (everyone simulating and trusting everyone) doesn't suit a fast shooter: there's no one to settle disagreements, and every player can cheat for everyone. Both styles run exactly the same code, the host is simply a server that also has a player at the keyboard.

## Architecture

### Authority

The **server decides everything**: movement results, hits, damage, deaths, scores, pickups, pads, respawns, the match flow. This is already how the game is built offline: the `Match` (`src/game/match.gd`) runs on "the machine that runs the match", and players are driven by `InputCommand`s through one fixed-tick simulation (`Player.tick()`). Online, clients send the server their inputs and the server sends back what happened.

### Transport

Godot's high-level multiplayer (`SceneMultiplayer`) over **ENet** (UDP, reliable and unreliable channels), both built into the engine: no plugin, no external service, works for LAN, direct connections and dedicated servers today. Everything above it talks to Godot's `MultiplayerPeer` interface, so a relay can be dropped in later without touching the game code:
- **Steam Networking Sockets** (through GodotSteam's `SteamMultiplayerPeer`) for the Steam release: NAT traversal and Valve's relay network, and players' addresses stay hidden from each other.
- **noray** (netfox's open-source NAT punch-through and relay server, self-hostable) for builds outside Steam.

### Session

`Net` (`src/net/`) owns the connection: hosting (with optional UPnP), joining, and the dedicated server's loop. Before a client is let in, it passes a **handshake** (Godot's `SceneMultiplayer` authentication step, before any game message is accepted): the protocol version must match, the name is cleaned (as on the title screen), the look (hat, colour) must be from the known lists, the server's password if it has one, and the server must have room. Then the server adds them to the **roster** (a `PlayerInfo` per player, the same one the offline match uses), picks their team, and tells everyone.

Games start on the server: it picks the style and map, and every client loads that map **by name from the game's own list** (never a path or file from the network). Each player's body in every level has the same name on every machine (`Player_<id>`), so messages about it find it. The round waits until every client says it has the map loaded (at most 8 s, then it starts without the slow ones), and a client that loads late, or joins mid-game, is sent where everyone is, what they hold, the pads and the loose weapons.

In the menu, **online** opens a page with *host a game* (style, port, an optional password, and whether to ask the router to open the port with UPnP) and *join a game* (an address like `192.168.1.20` or `example.com:27960`, and the password). Then the **lobby**: who's in, where friends can reach you (your address on the local network, and your internet address if UPnP worked), and for the host the style, the number of bots, and *start*. Everyone goes back to the lobby when a game ends. On a dedicated server the lobby just waits: the server starts the next game itself a few seconds after someone's there.

### Netcode

| | |
|---|---|
| Tick | 60 Hz fixed, the same `Player.tick()` offline, on the server and in prediction |
| Client → server | Input commands, numbered by tick, the last few repeated in each packet so one lost packet costs nothing (unreliable, ordered) |
| Server → clients | Snapshots at 30 Hz: every player's position, velocity, view, movement mode and flags, health (unreliable, ordered), and the loose weapons that moved; events when they happen (reliable): maps, spawns, damage, deaths, kills, shots fired, what everyone holds, pads, loose weapons appearing and going, match state, scores |
| The server running your player | It runs your commands in order, one a tick, never guessing: if the next one hasn't arrived, your player waits for it; if several are queued (a burst after a hitch), it runs two a tick until it's caught up. So prediction and the server always run exactly the same commands |
| Your player | Predicted: moves at once on your input. When a snapshot says where the server had you after a command, the client goes back there and replays the commands since (reconciliation) at the next physics tick; when prediction was right (within 5 cm), nothing moves, and when it wasn't, the difference is eased away on screen |
| Other players | Interpolated about 100 ms behind between snapshots, so they move smoothly; not simulated on the client |
| Your shots | Shown at once (tracer, muzzle flash, sound); damage, hit markers and kills only when the server confirms them |
| Hit registration | Server-side. Next: lag compensation, rewinding the other players' hit shapes to what the shooter saw (capped at 150 ms, GDD §15.2) |
| Pickups | Granted by the server; the client asks (its commands carry the button), the server decides (and settles two players grabbing at once). Loose weapons (dropped on death, swapped out, thrown) exist on the server; clients have copies it places, smoothed between updates |

### How it's built

| File | What it does |
|---|---|
| `src/net/net_session.gd` | `NetSession`: hosting, joining, the handshake, the roster, bots in the lobby, rate limits and kicking, UPnP |
| `src/net/dedicated_server.gd` | `DedicatedServer`: settings from the command line and a config file, and the loop that starts games while anyone's connected |
| `src/net/match_sync.gd` | `MatchSync`: under the `Match` on every machine; the server's inputs queue per player, snapshots and events, and the client's side of each |
| `src/net/prediction.gd` | `Prediction`: your own player on a client (history, sending commands, reconciliation) |
| `src/net/puppet.gd` | `Puppet`: everyone else on a client, interpolated between snapshots |
| `src/net/net_codec.gd` | `NetCodec`: every packed message, and checking what comes off the wire |
| `src/ui/online_menu.gd` | The menu's online page and lobby |
| `src/game/match.gd`, `game.gd` | The same match offline and online: `authority` says whether this machine decides it or follows the server |

The offline game didn't change shape to go online: the `Match` still decides everything (on the server), the player still runs one fixed tick from an `InputCommand` (on the server from the client's commands, on the client for prediction), and the UI follows the match's signals either way.

### What each message may contain

Every message has a fixed, small shape: plain numbers, strings and packed arrays, never objects. Everything received is **checked before use**: types, sizes, ranges (a move vector's length, view angles, a tick number near the expected one), and who sent it (a client can only send inputs for its own player). Anything malformed is dropped and counted; a client that keeps sending junk or floods is kicked.

## Plugins considered

| | What it is | For us |
|---|---|---|
| **Built-in** (`SceneMultiplayer` + ENet) | The engine's own networking | **Chosen** as the base: no dependency, dedicated servers and LAN work today, full control of prediction |
| **GD-Sync** | A hosted service: lobbies, matchmaking, relay, synced nodes | Easy lobbies, but the game would depend on a third-party backend and its pricing, it can't run our own dedicated servers, and its node syncing doesn't do prediction and reconciliation for a movement shooter. Not chosen |
| **netfox** (+ noray) | Open-source (MIT) addons: tick loop, time sync, rollback and interpolation helpers; noray for NAT punch-through and relay | A good fit, and the fallback if our own prediction grows too complex. We already have a fixed-tick sim and input commands, so a thin prediction layer of our own is less code to fit around. **noray is the plan for relays outside Steam** |
| **GodotSteam** | Steamworks for Godot: lobbies, relay networking, invites | **Planned for the Steam release**: NAT traversal, hidden addresses, friends and invites. Needs the Steam build and an app ID |
| Epic Online Services | Free lobbies, relay, accounts, cross-platform | An alternative to Steam's, if we ship outside Steam |
| Nakama | Open-source game server for accounts, matchmaking, chat | More than we need before there are public servers to list |

## Security

### What the game does

- **The server decides.** Clients send only inputs; they can't set their position, health, ammo, scores or anyone else's. Movement comes out of the server's own simulation, so speed and teleport hacks do nothing. Fire rate, ammo and weapon cooldowns are enforced on the server.
- **Nothing from the network runs as code.** Object decoding stays off (Godot's default: a message can't create objects or scripts), maps are loaded only by name from the built-in list, and no file path or resource from the network is ever loaded.
- **Everything is checked.** Message shapes, sizes and ranges; the sender (clients can't send as someone else, and can't message each other through the server: relaying is off); names cleaned and length-limited; looks only from the known lists.
- **Limits.** A maximum number of players; a handshake timeout; per-client rate limits on messages (inputs, requests); kicking on repeated junk or floods; optional server password.
- **Protocol version check.** Old and new builds refuse each other cleanly.
- **Dedicated servers** can run as an unprivileged user, locked down (a sample is in [Running a server](#running-a-server)); they don't need the network beyond their game port.

### Risks we accept (and can't fully prevent)

These are inherent to online games, and especially to one anyone can host. They're stated plainly so nobody is surprised:

1. **The host or server operator is trusted.** Whoever runs the game decides it. A modified host or server can cheat (invincibility, seeing everyone, deciding hits) and can log what players send. *Play on hosts and servers you trust; public and competitive play belongs on dedicated servers run by people you trust.*
2. **Addresses are visible.** With direct connections, the host or server sees every player's IP address, and players see the host's or server's. That can be misused (for example to flood someone's connection). *Relays (Steam, noray) hide addresses; until then, host only for people you know, and don't publish a home address.*
3. **Client cheats exist.** The server stops cheats that change the game's rules (speed, damage, ammo), but not cheats that play better than a person: aim assistance, triggerbots, reading other players' positions from memory or traffic (wallhacks). No anti-cheat is fully effective, and this game is built on an open engine. *Server-side checks and, later, not sending players you can't see reduce this; they don't remove it.*
4. **Traffic isn't encrypted by default.** ENet sends game packets in the clear: positions, names and inputs can be read by anyone on the network path. *Encryption (DTLS) is planned as an option for dedicated servers. Nothing sensitive is sent: there are no accounts, emails or payment details in the game.*
5. **Floods and denial of service.** Rate limits and connection caps stop a single misbehaving client, not a large attack on a server's connection. *That's the hosting provider's to mitigate.*
6. **Engine and library bugs.** A vulnerability in Godot's networking or ENet would affect every game built on it. *We stay on current Godot releases.*
7. **Names are public and unmoderated.** Anyone can pick any name (cleaned of control characters, 16 characters). *There's no chat yet; when there is, it needs mute, report and server-side filtering.*

## Phases

**Built**
1. The `net` layer: hosting (with UPnP), joining by address, the dedicated server, the handshake (version, name, look, password, room), the roster, disconnects, rate limits and kicking.
2. Message codecs with validation for inputs, players, your own movement state and loose weapons, unit-tested (including thousands of random junk packets).
3. Server-authoritative play: the match and every player's simulation run on the server; clients send inputs and receive snapshots and events. Rounds wait for everyone's map to load; latecomers are caught up.
4. Client prediction and reconciliation for your own player; interpolation for everyone else.
5. Combat online: shots, hits, damage, deaths, kills, pads, and loose weapons, decided by the server and shown on every client.
6. The menu: host and join, a lobby before the game and between games; leaving and ending games from the pause menu.
7. Tests (`tools/run_tests.sh`): codecs, validation and prediction in-process; then, in real time, a dedicated server in another process that this one joins (a wrong password refused, the game followed, movement predicted, a round played out, a latecomer joining mid-game, junk getting you kicked), and this one hosting a game a friend's process joins (their player driven by what they send, a thrown gun seen landing where it landed).

**Next**
- Lag compensation (rewinding hit shapes to the shooter's view).
- Interest management: don't send what a player can't see (fewer wallhacks, less bandwidth).
- A relay: GodotSteam for the Steam build, noray otherwise (NAT without port forwarding, hidden addresses).
- A server browser (a small master server listing public dedicated servers).
- Optional DTLS encryption for dedicated servers.
- Reconnecting to a game in progress, spectators, chat with moderation.
- The GDD §15.2 test matrix: 50–150 ms latency, jitter and packet loss.

### Known limits

- **Only tested on one machine** (loopback, no latency or loss). Expect tuning once it's played over real networks: the interpolation delay, how long the server waits for a client's commands, and the correction tolerance are first guesses.
- **No lag compensation yet**: the server tests shots against where players are now, so at 100 ms you have to lead moving targets a little.
- **A stalling client stands still.** The server waits for a player's commands rather than guessing, so on everyone else's screens a player with a bad connection freezes, then catches up.
- **Hits wait for the server.** Your own shots, tracers and muzzle flash show at once, but hit markers and damage numbers come back a round trip later.
- **Your look is sent when you join**: changing your name, hat or colour means rejoining. Teams are balanced by the server; nobody picks a side yet.
- **No reconnecting**: leaving and coming back is a new player with a fresh score.

## Running a server

```
godot --headless --path . -- --server [--port 27960] [--mode ffa|teams] [--maps stack,rift] [--max-players 8] [--bots 0] [--password secret] [--name "my server"] [--start-delay 5] [--config server.cfg]
```

or an exported server build with the same arguments after `--`. Everything can also go in a config file (see [`docs/server.example.cfg`](server.example.cfg), which explains each setting); command-line arguments win. The server logs to standard output. It runs games of its style back to back, rotating its map pool (bots fill in if you ask for them), and waits for players when there's nobody. Players need UDP on the game port.

Don't run it as root. On Linux, a systemd unit along these lines runs it as its own user with most of the system out of reach:

```ini
[Unit]
Description=xtrapartial server
After=network-online.target

[Service]
User=xtrapartial
WorkingDirectory=/opt/xtrapartial
ExecStart=/opt/xtrapartial/godot --headless --path /opt/xtrapartial -- --server --config /etc/xtrapartial/server.cfg
Restart=on-failure
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
# Godot's user:// (logs) goes here, the only place it may write.
StateDirectory=xtrapartial
Environment=XDG_DATA_HOME=/var/lib/xtrapartial
MemoryMax=1G

[Install]
WantedBy=multi-user.target
```
