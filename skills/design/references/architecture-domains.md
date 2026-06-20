# System-design domain cues

The harness's quick-reference cues per architecture domain, to apply *before* committing a design
in `/harness-claude:architect`. Match the change to a domain, apply the cues, and ground specifics
with **context7** (live API docs) so the design doesn't assume capabilities a library/platform
doesn't actually have.

## Universal first principles
- **SOLID** at module seams; **CAP / BASE / eventual consistency** for anything distributed.
- **Security:** defense-in-depth · least privilege · zero trust.
- Prefer **boring, proven** patterns; justify every new dependency and every new failure mode.

## API design
- Resources = plural nouns, verbs in the HTTP method (`GET /users/{id}`, not `/getUser`).
- Correct status codes (201 create, 204 no-content, 401 vs 403, 409 conflict, 422 validation).
- Version explicitly; paginate list endpoints; consistent response envelope + error shape.
- Choose REST vs GraphQL vs gRPC by access pattern, not fashion. Idempotency on retried writes.

## Caching
- Layer the cache: client → CDN → gateway → app/in-proc → distributed (Redis) → DB. Each step
  trades latency for consistency.
- Cache-Aside is the default read pattern; name your write strategy (write-through / write-behind / invalidate).
- Guard the **three failures:** penetration (cache empty keys / bloom filter), breakdown
  (lock/single-flight on hot-key expiry), avalanche (jitter TTLs).
- State the consistency guarantee and the staleness window explicitly — don't leave it implicit.

## Cloud-native
- Multi-stage container builds; non-root user; minimal base image; pin versions.
- Twelve-factor config (env, not baked-in). Health/readiness probes. Stateless services; externalize state.
- Right-size requests/limits; design for horizontal scale and graceful shutdown.

## Message queue / event-driven
- Point-to-point (queue) vs pub/sub (topic) — pick by fan-out. Producer → broker → consumer-group.
- Partition for parallelism + ordering-within-key; track offsets; plan consumer-group rebalancing.
- Delivery semantics are a **decision:** at-least-once (idempotent consumers + dedup) vs exactly-once
  (cost). Dead-letter queues for poison messages. CQRS/Saga for distributed workflows + compensation.

## Security architecture
- Zero trust: never trust, always verify; assume breach; verify every request explicitly.
- AuthN (MFA/SSO) distinct from AuthZ (least-privilege, deny-by-default). Network micro-segmentation.
- Data protection: encrypt at rest + in transit; key management; classify data + map compliance scope.
- Threat-model the change (STRIDE-style): what's the trust boundary, what's the blast radius?

---
**Use in the ADR:** name the domain(s) this change touches, the specific cues you applied, and the
trade-offs you accepted — including the non-functional ones (scale, latency, cost, failure).
