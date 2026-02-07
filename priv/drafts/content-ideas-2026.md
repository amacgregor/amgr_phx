# Content Ideas for 2026

20 article ideas for bi-weekly publication (40 weeks of content).
Based on trends from AppSignal, Dashbit blogs, and gaps in existing content.

---

## Elixir Core & OTP

### 1. Building Resilient Systems with OTP Supervisors
**Publish: Feb 2026**
Deep dive into supervisor strategies (one_for_one, one_for_all, rest_for_one), restart intensity, and designing supervision trees for real-world fault tolerance. Include a case study of a production system.

### 2. GenServer Patterns You Should Know
**Publish: Mar 2026**
Beyond the basics: call vs cast trade-offs, handle_continue for async init, state machine patterns, testing GenServers with mocks. Practical patterns from production systems.

### 3. Understanding BEAM Memory Management
**Publish: Mar 2026**
Process heaps, garbage collection strategies, binary handling, memory profiling with `:recon` and Observer. When to worry about memory and when not to.

### 4. Distributed Elixir: Beyond the Basics
**Publish: Apr 2026**
Node clustering, pg (process groups), global vs local processes, handling net splits, distributed state with Horde or Delta CRDTs.

---

## Phoenix & LiveView

### 5. LiveView Patterns for Complex UIs
**Publish: Apr 2026**
Component design, nested live views, PubSub patterns, handling long-running operations with async assigns, optimistic UI updates.

### 6. Building Real-Time Dashboards with LiveView
**Publish: May 2026**
Telemetry integration, charting libraries (VegaLite, Chart.js), streaming data, handling high-frequency updates efficiently.

### 7. Phoenix Contexts Done Right
**Publish: May 2026**
When to split contexts, cross-context communication patterns, avoiding the "god context" anti-pattern. Refactoring case study.

### 8. Zero Trust Authentication in Phoenix
**Publish: Jun 2026**
Implementing nimble_zta, identity-aware proxies, BeyondCorp concepts for Elixir apps. (Inspired by Dashbit's recent release)

---

## Data & Ecto

### 9. Advanced Ecto Queries: Window Functions and CTEs
**Publish: Jun 2026**
Using Ecto.Query fragments for window functions, recursive CTEs, lateral joins. Real examples for analytics and reporting.

### 10. Multi-Tenancy Patterns in Ecto
**Publish: Jul 2026**
Schema-based vs row-based multi-tenancy, dynamic repos, connection pooling strategies, query scoping with Ecto's prepare_query.

### 11. Event Sourcing with Elixir
**Publish: Jul 2026**
Building an event store, projections, snapshots, handling schema evolution. Comparison with Commanded.

---

## Testing & Quality

### 12. Property-Based Testing with StreamData
**Publish: Aug 2026**
Beyond example-based tests: generators, shrinking, finding edge cases you didn't think of. Testing Ecto schemas and business logic.

### 13. Testing LiveView Components in Isolation
**Publish: Aug 2026**
Component testing strategies, mocking parent assigns, testing JS hooks, snapshot testing for complex UIs.

### 14. Debugging Production Elixir with Observer and Recon
**Publish: Sep 2026**
Remote shell access, process inspection, memory leak hunting, tracing in production safely. War stories and patterns.

---

## Integration & Interop

### 15. Elixir and AI: Building LLM-Powered Features
**Publish: Sep 2026**
Using Instructor for structured LLM output, streaming responses in LiveView, building AI agents with Elixir. (Timely given Dashbit's "Why Elixir is best for AI" post)

### 16. Embedding Python in Elixir with Pythonx
**Publish: Oct 2026**
When to use Python interop vs native Elixir, ML model integration, data science workflows. (Based on Dashbit's Pythonx work)

### 17. Building APIs with Absinthe GraphQL
**Publish: Oct 2026**
Schema design, dataloader for N+1 prevention, subscriptions, authentication patterns, error handling.

---

## DevOps & Production

### 18. Deploying Elixir with Kamal 2
**Publish: Nov 2026**
Zero-downtime deployments, secrets management, rolling updates, health checks. Alternative to Fly.io for self-hosted deployments.

### 19. Observability for Elixir Applications
**Publish: Nov 2026**
OpenTelemetry integration, distributed tracing, structured logging with Logger metadata, building custom Telemetry reporters.

### 20. The Ash Framework: A Practical Introduction
**Publish: Dec 2026**
Domains, resources, actions, and policies. When Ash makes sense vs plain Phoenix. Building a real feature with Ash. (Based on AppSignal's recent Ash content)

---

## Schedule Summary

| Month | Articles |
|-------|----------|
| Feb 2026 | OTP Supervisors |
| Mar 2026 | GenServer Patterns, BEAM Memory |
| Apr 2026 | Distributed Elixir, LiveView Patterns |
| May 2026 | Real-Time Dashboards, Phoenix Contexts |
| Jun 2026 | Zero Trust Auth, Advanced Ecto |
| Jul 2026 | Multi-Tenancy, Event Sourcing |
| Aug 2026 | Property Testing, LiveView Testing |
| Sep 2026 | Production Debugging, Elixir & AI |
| Oct 2026 | Python Interop, Absinthe GraphQL |
| Nov 2026 | Kamal Deployment, Observability |
| Dec 2026 | Ash Framework |

---

## Notes

- Topics avoid overlap with existing published posts (NIFs/Rust, N+1, Flow-Based Programming, Metaprogramming, Circuit Breaker already covered)
- Mix of beginner-friendly (GenServer patterns) and advanced (Event Sourcing, Distributed Elixir)
- Aligned with ecosystem trends (Ash, AI/LLM, Pythonx, Zero Trust)
- Each can be 1500-2500 words with code examples
