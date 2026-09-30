# Load and abuse testing

Status: first in-process runs, 2026-09-29 (BE-17). A staging run against production-like PostgreSQL
over the network is still needed before launch; it needs hosting.

## Abuse: blocks never leak (automated, every test run)

`backend/test/block_leakage.test.ts` plays three seeded random sequences (60 steps each) of likes,
Super Likes, matches, messages, blocks and unblocks between six members. After every step, for every
blocked pair and in both directions, it checks that neither person appears in the other's Discover
or Likes you, the match is gone from both chat lists, messages in either direction fail as
`conversation_closed`, reading the thread fails, and liking fails as `not_found`. Unblocking never
reopens an old conversation. Removing the block check from Discover's eligibility rule fails it at
once. Earlier checkpoints add the other abuse limits (likes, reports, messages, uploads, sign-in).

## Load: `npm run load` (in process)

A fresh in-memory database, 100 members signed in from their own addresses, about 300 matches, then
a random mix of Discover, chat list, like or pass, sending a message, reading a thread and reading
the profile. It measures the server's own work (routing, rules, SQL) without the network.

| Run | Requests | Throughput | Reads (p50 / p95) | Likes and messages (p50 / p95) | Server errors |
|---|---|---|---|---|---|
| 25 at a time | 3000 | 114 per second | 4-17 ms / 6-24 ms | 617-627 ms / 813-840 ms | 0 |
| 1 at a time | 900 | 116 per second | 4-17 ms / 5-22 ms | 7-8 ms / 10-11 ms | 0 |

What it means: every request is fast on its own (Discover, the heaviest, is 17 ms at the median).
Throughput is the same with 1 or 25 people at once, because the development database (PGlite, one
process) runs one thing at a time, and each like or message is a transaction that holds it. Under
25 simultaneous users the writes therefore queue for about 0.6 s. That is a property of the
development database, not of the service code: production uses PostgreSQL with a connection pool
(`openPostgres`, 10 connections), where these transactions run in parallel.

The few 404 and 429 answers are expected: liking yourself-adjacent or ineligible people in a random
mix, and the per-minute message limit.

## Before launch

- Run the same mix against PostgreSQL on the chosen host, over the network, with a target of p95
  under 300 ms at the expected peak (to be set from the launch plan), and record it here.
- Exercise the shared sign-in throttle from multiple server instances against PostgreSQL on the
  chosen host (`docs/SECURITY_REVIEW.md`).
- Load the live-update streams (5 per account) and photo reads, which this run does not cover.
