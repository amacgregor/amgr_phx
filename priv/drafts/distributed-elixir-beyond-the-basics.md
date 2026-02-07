%{
title: "Distributed Elixir: Beyond the Basics",
category: "Programming",
tags: ["elixir", "distributed-systems", "otp", "clustering"],
description: "Node clustering, process groups, and handling network partitions in Elixir",
published: false
}
---

Distribution is Elixir's superpower and its most dangerous footgun. The BEAM makes connecting nodes trivially easy — a single `Node.connect/1` call and you have transparent message passing across machines. This elegance seduces teams into distributing too early, before they have exhausted simpler solutions and before they understand what network partitions will do to their carefully crafted supervision trees.

I have watched teams spend months debugging split-brain scenarios that would never have occurred if they had just run two independent instances behind a load balancer. Distribution is not a feature you adopt. It is a trade-off you accept.

## The Siren Song of Node Clustering

Connecting Elixir nodes manually works fine for development. In production, you need automatic discovery. The `libcluster` library has become the de facto standard, supporting multiple strategies for nodes to find each other.

The simplest strategy for Kubernetes deployments is DNS-based discovery:

```elixir
# config/runtime.exs
config :libcluster,
  topologies: [
    k8s_dns: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: "myapp-headless",
        application_name: "myapp",
        polling_interval: 5_000
      ]
    ]
  ]
```

This configuration polls a headless Kubernetes service every five seconds, discovering new nodes as pods scale up. The `application_name` must match your release name — libcluster uses it to construct the full node name.

For non-Kubernetes environments, gossip-based discovery works well:

```elixir
config :libcluster,
  topologies: [
    gossip: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: "0.0.0.0",
        multicast_addr: "230.1.1.1",
        broadcast_only: true
      ]
    ]
  ]
```

Gossip uses UDP multicast to announce node presence. It requires no external infrastructure but demands that your network allows multicast traffic. Many cloud VPCs do not. AWS VPCs block multicast by default. So does GCP. Azure supports it in specific configurations. Check your provider's documentation before committing to this strategy.

For Fly.io deployments, DNS-based discovery with their internal DNS works reliably:

```elixir
config :libcluster,
  topologies: [
    fly: [
      strategy: Cluster.Strategy.DNSPoll,
      config: [
        polling_interval: 5_000,
        query: "myapp.internal",
        node_basename: "myapp"
      ]
    ]
  ]
```

The libcluster supervisor should start early in your application tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])

    children = [
      {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]},
      # ... other children
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

Clustering is the easy part. Keeping state consistent across that cluster is where the real work begins.

## Process Groups: The Modern Way

OTP 23 introduced `:pg`, a complete rewrite of the older `:pg2` module. The new implementation is partition-tolerant by design — each node maintains its own view of group membership, and views eventually converge after a partition heals.

Starting a process group scope is straightforward:

```elixir
defmodule MyApp.Application do
  def start(_type, _args) do
    children = [
      {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]},
      %{id: :pg, start: {:pg, :start_link, [MyApp.PG]}},
      # ... other children
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

With the scope running, processes can join and leave groups dynamically:

```elixir
defmodule MyApp.Worker do
  use GenServer

  def start_link(topic) do
    GenServer.start_link(__MODULE__, topic)
  end

  def init(topic) do
    :pg.join(MyApp.PG, {:subscribers, topic}, self())
    {:ok, %{topic: topic}}
  end

  def terminate(_reason, state) do
    :pg.leave(MyApp.PG, {:subscribers, state.topic}, self())
    :ok
  end
end
```

Broadcasting to all members of a group requires iterating over the membership list:

```elixir
defmodule MyApp.Broadcaster do
  def notify(topic, message) do
    members = :pg.get_members(MyApp.PG, {:subscribers, topic})

    for pid <- members do
      send(pid, {:notification, message})
    end

    {:ok, length(members)}
  end

  def notify_local(topic, message) do
    # Only notify processes on this node — faster, no network hops
    members = :pg.get_local_members(MyApp.PG, {:subscribers, topic})

    for pid <- members do
      send(pid, {:notification, message})
    end

    {:ok, length(members)}
  end
end
```

The distinction between `get_members/2` and `get_local_members/2` matters. The former returns all members across the cluster; the latter returns only those on the current node. When you can use local members, you eliminate network round-trips entirely.

Process groups solve pub/sub elegantly. They do not solve singleton processes or distributed state.

One subtlety worth noting: `:pg` group membership is not persistent. If a process crashes, it is automatically removed from all groups. If your supervision tree restarts the process, it must rejoin groups explicitly. This is the correct behavior — a restarted process is a new process with a new PID — but it catches newcomers off guard.

The `:pg` module also supports multiple scopes. You can run separate `:pg` instances for different subsystems, preventing namespace collisions and allowing different sync behaviors:

```elixir
# Two independent process group scopes
children = [
  %{id: :pg_pubsub, start: {:pg, :start_link, [MyApp.PubSub]}},
  %{id: :pg_workers, start: {:pg, :start_link, [MyApp.Workers]}}
]
```

## Global vs Local Registration: Choose Your Pain

Elixir offers two registration models with fundamentally different failure characteristics.

Local registration through `Registry` is fast and partition-tolerant:

```elixir
# In your supervision tree
{Registry, keys: :unique, name: MyApp.Registry}

# In your GenServer
def start_link(id) do
  GenServer.start_link(__MODULE__, id, name: {:via, Registry, {MyApp.Registry, id}})
end

# Looking up a process
case Registry.lookup(MyApp.Registry, worker_id) do
  [{pid, _value}] -> {:ok, pid}
  [] -> {:error, :not_found}
end
```

Local registration works entirely within a single node. During a network partition, nothing breaks — you simply cannot see processes on other nodes. This is a feature, not a bug.

Global registration through `:global` provides cluster-wide unique names:

```elixir
def start_link(id) do
  case GenServer.start_link(__MODULE__, id, name: {:global, {:worker, id}}) do
    {:ok, pid} -> {:ok, pid}
    {:error, {:already_started, pid}} -> {:ok, pid}
  end
end

# Looking up a process anywhere in the cluster
case :global.whereis_name({:worker, id}) do
  :undefined -> {:error, :not_found}
  pid -> {:ok, pid}
end
```

Global registration extracts a heavy toll. Every registration and lookup requires coordination across nodes. During a partition, `:global` must make a choice: either allow duplicate names (violating its guarantee) or block operations until the partition heals. It chooses to block.

I have seen `:global` cause cascading failures when a single node becomes unreachable. The registration system locks up waiting for consensus, timeouts cascade through the calling code, and suddenly your entire cluster is wedged.

Use `:global` only when you genuinely need exactly one instance of something across the cluster and you can tolerate blocking during partitions. For most use cases, local registration with application-level routing is safer.

## Network Partitions: When Theory Meets Reality

The CAP theorem states that a distributed system can provide at most two of three guarantees: Consistency, Availability, and Partition tolerance. Since network partitions will happen — they are not optional — you are really choosing between consistency and availability.

Elixir's default primitives lean toward availability. Process groups remain available during partitions; each side of the partition maintains its own membership view. Messages to processes on the other side will fail, but local operations continue.

Detecting partitions requires monitoring node connections:

```elixir
defmodule MyApp.ClusterMonitor do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, %{nodes: MapSet.new()}}
  end

  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("Node joined: #{node}")
    {:noreply, %{state | nodes: MapSet.put(state.nodes, node)}}
  end

  def handle_info({:nodedown, node, _info}, state) do
    Logger.warning("Node left: #{node}")
    # Trigger partition handling logic here
    handle_potential_partition(node)
    {:noreply, %{state | nodes: MapSet.delete(state.nodes, node)}}
  end

  defp handle_potential_partition(node) do
    # Your partition response strategy:
    # - Fence off writes?
    # - Switch to degraded mode?
    # - Attempt reconnection?
  end
end
```

The challenge is distinguishing between a node that crashed and a network partition. A crashed node is gone; a partitioned node is still running, potentially accepting writes that will conflict with yours. There is no reliable way to tell the difference from inside the partition.

Conservative systems assume every `nodedown` event might be a partition and take protective action. Aggressive systems assume crashes are more common and continue operating normally. Your choice depends on whether duplicate operations or unavailability causes more damage.

A concrete example clarifies the stakes. Consider a payment processing system where a worker claims jobs from a queue. During a partition, both sides of the cluster might claim the same job. Without coordination, the payment processes twice. The conservative approach: stop claiming jobs when any node is unreachable. The aggressive approach: continue processing and deduplicate later using idempotency keys. Neither is universally correct. The choice depends on your business constraints.

Erlang's default partition handling is aggressive — nodes continue operating independently. If you need conservative behavior, you must implement it yourself. Libraries like `partisan` offer alternative distribution protocols with different trade-offs, but they require significant investment to adopt.

## Distributed State: Pick Your Consistency Model

When you genuinely need state shared across nodes, you have three main options in the Elixir ecosystem.

**Horde** provides distributed supervisors and registries using delta-state CRDTs:

```elixir
defmodule MyApp.DistributedRegistry do
  use Horde.Registry

  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  def init(opts) do
    [members: members()]
    |> Keyword.merge(opts)
    |> Horde.Registry.init()
  end

  defp members do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end
end

defmodule MyApp.DistributedSupervisor do
  use Horde.DynamicSupervisor

  def start_link(_) do
    Horde.DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Horde.DynamicSupervisor.init(
      strategy: :one_for_one,
      members: :auto
    )
  end

  def start_worker(id) do
    spec = {MyApp.Worker, id}
    Horde.DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
```

Horde guarantees eventual consistency. After a partition heals, conflicting registrations are resolved by keeping one process and terminating duplicates. Your processes must handle unexpected termination gracefully.

**DeltaCrdt** offers lower-level CRDT primitives for custom data structures:

```elixir
defmodule MyApp.SharedCounter do
  def start_link(name) do
    DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, name: name, sync_interval: 50)
  end

  def increment(counter, key) do
    DeltaCrdt.mutate(counter, :add, [key, 1], DeltaCrdt.AWLWWMap)
  end

  def get(counter, key) do
    DeltaCrdt.read(counter)
    |> Map.get(key, 0)
  end
end
```

CRDTs provide strong eventual consistency — all replicas converge to the same state without coordination. The trade-off is that not all operations are expressible as CRDTs. You cannot build a consistent counter that decrements arbitrarily, for example — you need a PN-Counter that tracks increments and decrements separately.

Understanding which CRDT type to use for your data is non-trivial. AWLWWMap (Add-Wins Last-Writer-Wins Map) works for key-value data where last write wins. ORSet (Observed-Remove Set) handles sets where concurrent adds and removes must both succeed. Choosing the wrong CRDT means your data converges to the wrong value.

**Phoenix.Tracker** is purpose-built for presence tracking:

```elixir
defmodule MyApp.Presence do
  use Phoenix.Tracker

  def start_link(opts) do
    Phoenix.Tracker.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server}}
  end

  def handle_diff(diff, state) do
    # React to presence changes
    {:ok, state}
  end

  def track(pid, topic, key, meta) do
    Phoenix.Tracker.track(__MODULE__, pid, topic, key, meta)
  end

  def list(topic) do
    Phoenix.Tracker.list(__MODULE__, topic)
  end
end
```

Phoenix.Tracker uses a CRDT internally and is optimized for the specific pattern of tracking which users are present in which channels. If your use case fits this model, it is more battle-tested than rolling your own.

## When Not to Distribute

Distribution adds complexity that compounds over time. Before reaching for clustering, exhaust these alternatives.

**Stateless nodes behind a load balancer.** If your nodes share nothing, partitions cannot cause inconsistency. Use external storage (PostgreSQL, Redis) for shared state and let the database handle consistency.

**Sticky sessions.** Route all requests from a user to the same node. Now that node owns the user's state locally. Failover means losing in-memory state, but you avoid distributed coordination entirely.

**External coordination services.** Need distributed locks? Use Redis or etcd. Need leader election? Use PostgreSQL advisory locks. These systems have years of production hardening that your custom Elixir solution lacks.

**Accept eventual inconsistency.** Sometimes the business can tolerate brief inconsistency. Two nodes both processing the same job might result in a duplicate email. Is that worse than the complexity of distributed locking? Often not.

The right time to distribute is when you have exhausted these options and still have a problem that requires nodes to coordinate in real-time. That is rarer than the Elixir community sometimes suggests.

A useful heuristic: if you can solve the problem with a database transaction, do that. Databases have decades of battle-tested consistency mechanisms. Your distributed Elixir solution has whatever you built last month. PostgreSQL's SKIP LOCKED, advisory locks, and serializable isolation levels solve most coordination problems without requiring node-to-node communication.

When real-time coordination is genuinely required — live collaboration, multiplayer games, distributed rate limiting — then distribution earns its complexity. But verify the requirement first. Many "real-time" features can tolerate 100 milliseconds of latency, which is enough time to round-trip to a database.

## The Partition Playbook

When you do distribute, have a plan for partitions before they happen.

First, instrument everything. Log node connections and disconnections. Track message delivery failures. Monitor process group membership changes. You cannot debug a partition after the fact without this data.

Second, design for graceful degradation. What does your system do when it cannot reach a peer? Returning an error is acceptable. Hanging indefinitely is not.

Third, test partition behavior explicitly. Tools like Toxiproxy can simulate network failures. Run chaos experiments before production teaches you the hard way.

Fourth, document your consistency choices. Future maintainers need to understand why you chose availability over consistency in that particular subsystem.

Distribution in Elixir is not difficult to implement. It is difficult to operate. The code that connects nodes is trivial; the wisdom to know when connection is the wrong choice takes longer to acquire.

---

**Claims to verify with current data:**
- OTP 23 introduction of `:pg` module (verify exact version)
- libcluster strategy names and configuration options (check current documentation)
- Horde CRDT implementation details (verify current API)
- DeltaCrdt module names and function signatures (verify current version)
