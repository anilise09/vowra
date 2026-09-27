# What Tinder's open-source work teaches Vawra

Research date: 2026-09-27. Source: every public repository at https://github.com/Tinder (18 repos),
the documentation and core source of the relevant ones, and Tinder's engineering articles linked
from them. No code was copied: the repositories are licensed by Match Group (modified BSD-3), and
Vawra takes ideas only, written fresh for Flutter and our Node backend. The UI teardown lives in
`TINDER_UI_TEARDOWN.md`; this file is about engineering.

## The repositories

| Repo | What it is | Relevant to Vawra? |
| --- | --- | --- |
| Scarlet (3.2k stars, Kotlin) | WebSocket client for Android; connection driven by a state machine and the app's lifecycle; pluggable back-off. A 0.2.x branch adds Server-Sent Events, STOMP and MQTT. | Yes: real-time chat and matches. |
| StateMachine (2.1k, Kotlin + Swift) | Tiny finite-state-machine DSL: states, events, side effects; used inside Scarlet. | Yes: how to model connections and flows. |
| Nodes (Swift) | Tinder's iOS app architecture: every screen is a node with Context (logic), Flow (routing), View (display); Workers; Plugins; leak detection. | Yes: structure and lifecycle discipline. |
| circuit-breaker (archived, JS) | Fail fast after a failure rate/count, retry after a reset timeout. | Yes, once outside providers exist. |
| GeneralizedAdditiveModels (archived, Python) | Interpretable statistical models. | Principle only: ranking we can explain. |
| sharded-redis-client (JS) | Consistent-hash sharding of Redis by key. | Later, at scale. |
| crap (archived, JS) | Layering and dependency injection for Node services. | Already done: `Services` is injected. |
| bazel-diff (Rust) | Run only the tests affected by a change. | Later, for CI time. |
| Layout, CombineUI, CollectionBuilders, Nodes-Tree-Visualizer (Swift) | UIKit/Combine helpers. | No (iOS UIKit specific). |
| sign-here, GitQuery, spellcheck-cli, Commit-Message-Validation-Hook, homebrew-tap, tinder.github.io | Build and release tooling. | No. |

## Lessons, and what Vawra does with each

### 1. Push a nudge, then fetch (biggest win)

Tinder's app used to poll every two seconds; almost every answer was "nothing new". That wasted
mobile data and servers and still averaged about a second of delay. Their replacement ("Keepalive")
pushes a **nudge**: a tiny message that only says *something is new*. The app then fetches the real
data through its normal, authenticated API. A lost nudge is harmless because the next update sends
another, and the app still checks in now and then.

Vawra today polls matches every 10 s and an open chat every 3 s. We adopt the nudge pattern:

- `GET /v1/events`: one authenticated Server-Sent Events stream per signed-in app. It carries only
  `{kind: message|match|like, match_id?}`, never message text, names or photos, so nothing
  sensitive travels through the push path and every read stays behind the normal access checks.
- The app refetches on a nudge, and on every reconnect (to cover nudges missed while offline).
- A slow safety check stays (60 s while the stream is up), so a missed nudge costs at most a minute.
- SSE rather than WebSocket: server-to-app is all we need, it is plain HTTP (auth header, proxies,
  TLS as usual), and Scarlet's own newer branch supports it.

### 2. Connect only while it makes sense (Scarlet's lifecycle)

Scarlet connects only while *every* condition holds (app in the foreground, network available,
user signed in), treats any stopped condition as stopped, and smooths out flicker (500-1000 ms) so
a system dialog does not tear the connection down. Vawra's polling timers currently keep running
in the background. We tie the stream and all timers to the app lifecycle: stop when the app is
paused or hidden, reconnect and catch up when it resumes, stop for good on sign-out.

### 3. Retry with exponential back-off and full jitter

Scarlet retries a dropped connection after `random(0, min(max, base * 2^n))`. The randomness stops
thousands of phones reconnecting in lockstep after a server restart. Vawra uses the same shape
(base 1 s, cap 60 s), and a connection that stays up resets the count.

### 4. Model connections as a pure state machine

Scarlet's connection is a small machine: Disconnected, Connecting, Connected, WaitingToRetry,
Stopped. Tinder's StateMachine makes each transition a pure function of (state, event) returning
the next state plus side effects as values; an event that makes no sense in a state is reported as
invalid instead of silently doing something. That makes every rule testable without timers or
sockets. Vawra writes its nudge connection this way, with the side effects (open, schedule retry,
refetch) executed by a thin driver.

### 5. Every background job belongs to a lifecycle (Nodes Workers)

Nodes gives each screen Workers that start and stop with the screen, plus a leak detector that
checks a finished screen really went away. For Vawra: timers and streams are owned by the widget
that needs them, started in one place and cancelled in `dispose`; tests fail if a timer outlives
its screen (Flutter's test runner already reports pending timers).

### 6. Separate logic, routing and display; gate features in one place (Nodes)

Nodes keeps business logic out of views and decides whether a feature exists with a Plugin that
checks its conditions (state, flags) before it is even built. Vawra's server flow already routes
from one function (`openSignedIn`); the next step is the same discipline for features that depend
on server capabilities (photos, location, calls): one check decides whether the entry point is
shown, instead of scattered `if`s.

### 7. Fail fast around outside services (circuit-breaker)

When a dependency fails beyond a rate or count, stop calling it for a reset period instead of
piling up slow failures. Vawra has no outside providers yet; when email delivery, age assurance and
media arrive, each goes behind a breaker, and sign-in keeps its same non-revealing answer while the
breaker is open.

### 8. Ranking we can explain (GAMs), location in coarse cells (geosharding)

Tinder published interpretable additive models, and describes geosharding people into S2 cells.
For Vawra: when ranking arrives, use additive, explainable signals (intent match, interests,
activity, distance band) rather than a hidden desirability score; and when location arrives, snap
positions to coarse cells server-side before computing a distance band, which also resists
triangulation as the lifecycle contract requires.

## What we are building from this now

1. Nudge stream (`GET /v1/events`) with an in-process event bus behind an interface, so a shared
   broker can replace it when there is more than one server.
2. App: a pure nudge-connection state machine, full-jitter back-off, lifecycle-bound start/stop,
   refetch on nudge and on reconnect, slower safety checks; chat threads refresh on their nudge.
3. Tests for the machine, the back-off bounds, the stream parser, the server stream (auth, content,
   isolation between accounts) and the app refreshing on a nudge without waiting for a timer.

## Sources

- https://github.com/Tinder (all public repositories, read 2026-09-27)
- Scarlet: README, `Connection.kt` state machine, lifecycle combination, back-off strategies
- StateMachine: README
- Nodes: README, Plugin, Worker, LeakDetector docs
- "How Tinder delivers your matches and messages at scale", Tinder Tech Blog (Medium); summaries at
  diff.blog and in search results (the article itself returned 403 to automated fetches)
- "Taming WebSocket with Scarlet", Tinder Engineering (Medium, linked from the Scarlet README)
