%{
title: "Zero Trust Authentication in Phoenix",
category: "Programming",
tags: ["elixir", "phoenix", "security", "authentication"],
description: "Implementing Zero Trust Authentication with nimble_zta and identity-aware proxies",
published: false
}
---

The perimeter is dead. If you're still thinking about security in terms of "inside the network" versus "outside the network," you're defending a castle that no longer has walls.

Zero Trust isn't a product you can buy or a checkbox you can tick. It's a fundamental shift in how we think about authentication and authorization. And for Phoenix developers building applications that will run in cloud environments, behind load balancers, or accessed by distributed teams, understanding Zero Trust isn't optional—it's table stakes.

---

## The VPN Illusion

For decades, enterprise security followed a simple model: build a wall, put everyone you trust inside it, and keep everyone else out. VPNs became the drawbridge to this castle. Once you're in, you're trusted.

Here's the problem: that model assumes attackers are outside and employees are inside. Modern breaches have demolished this assumption. Compromised credentials, insider threats, lateral movement—once an attacker gets past the perimeter, they often have free reign. The 2020 SolarWinds attack didn't breach a firewall. It walked through the front door with valid credentials.

Google recognized this vulnerability back in 2011 after the Aurora attacks. Their response was BeyondCorp, an internal initiative that eventually became the blueprint for what we now call Zero Trust Architecture. The core principle is brutally simple: never trust, always verify. Every request, every time, regardless of where it originates.

## Identity-Aware Proxies: The Gatekeepers

Identity-Aware Proxies (IAPs) are the enforcement mechanism for Zero Trust. Instead of granting network-level access, they verify identity and context at the application layer for every single request.

Here's how it works:

1. A user attempts to access your application
2. The request first hits the identity-aware proxy
3. The proxy checks: Is this user authenticated? With which identity provider? What are their attributes?
4. If valid, the proxy forwards the request with cryptographically signed headers containing the user's identity
5. Your application receives the request with verified identity claims already attached

The beauty of this model is separation of concerns. Your application doesn't handle the authentication dance—no OAuth flows, no session management, no token refresh logic. The proxy handles all of that. Your application simply trusts the signed headers from the proxy.

Google Cloud's Identity-Aware Proxy, Cloudflare Access, and AWS's ALB with OIDC integration all implement this pattern. Each injects user identity information into requests using signed JWT tokens or proprietary header formats.

## Enter nimble_zta

Dashbit's `nimble_zta` library provides Phoenix applications with a clean abstraction for consuming identity information from various identity-aware proxies. Rather than writing custom header parsing logic for each cloud provider, you get a unified interface.

Add it to your dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:nimble_zta, "~> 0.1"}
  ]
end
```

The library ships with adapters for major providers:

- Google Cloud Identity-Aware Proxy
- Cloudflare Access
- AWS Application Load Balancer with OIDC
- Custom JWT-based solutions

Each adapter knows how to extract and verify the identity claims from that provider's specific header format.

## Implementing ZTA in Phoenix: Step by Step

Let's build this from the ground up. We'll create a Phoenix application that trusts identity information from an identity-aware proxy while maintaining defense in depth.

### Step 1: Configure the Provider

First, configure nimble_zta with your identity provider's settings:

```elixir
# config/config.exs
config :my_app, :zta,
  provider: NimbleZTA.Google,
  audience: "your-project-id.apps.googleusercontent.com",
  # Optional: restrict to specific domains
  allowed_domains: ["yourcompany.com"]
```

For Cloudflare Access:

```elixir
config :my_app, :zta,
  provider: NimbleZTA.Cloudflare,
  team_domain: "yourteam.cloudflareaccess.com",
  audience: "your-application-audience-tag"
```

### Step 2: Create the ZTA Plug

Build a plug that extracts and verifies identity on every request:

```elixir
defmodule MyAppWeb.Plugs.ZeroTrustAuth do
  @moduledoc """
  Extracts and verifies user identity from identity-aware proxy headers.

  This plug expects requests to have already passed through an IAP.
  It will reject requests that don't contain valid identity claims.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    zta_config = Application.get_env(:my_app, :zta)
    provider = Keyword.fetch!(zta_config, :provider)

    case provider.verify_identity(conn, zta_config) do
      {:ok, identity} ->
        conn
        |> assign(:current_user_identity, identity)
        |> assign(:zta_verified, true)

      {:error, reason} ->
        Logger.warning("ZTA verification failed: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Identity verification failed"})
        |> halt()
    end
  end
end
```

The `identity` struct returned contains the verified claims:

```elixir
%NimbleZTA.Identity{
  email: "developer@yourcompany.com",
  subject: "accounts.google.com:1234567890",
  issued_at: ~U[2024-01-15 10:30:00Z],
  expires_at: ~U[2024-01-15 11:30:00Z],
  provider: :google,
  raw_claims: %{...}
}
```

### Step 3: Wire It Into Your Router

Apply the plug to protected routes:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :zta_protected do
    plug MyAppWeb.Plugs.ZeroTrustAuth
  end

  # Public endpoints - no ZTA required
  scope "/health", MyAppWeb do
    pipe_through :api
    get "/", HealthController, :check
  end

  # Protected endpoints - require verified identity
  scope "/api", MyAppWeb do
    pipe_through [:api, :zta_protected]

    resources "/accounts", AccountController
    resources "/transactions", TransactionController
  end
end
```

### Step 4: Access Identity in Controllers

With the identity verified and assigned, controllers can use it directly:

```elixir
defmodule MyAppWeb.AccountController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    identity = conn.assigns.current_user_identity

    # Use the verified email to scope queries
    accounts = Accounts.list_for_user(identity.email)

    json(conn, %{
      accounts: accounts,
      authenticated_as: identity.email
    })
  end

  def show(conn, %{"id" => id}) do
    identity = conn.assigns.current_user_identity

    # Authorization: ensure user can access this specific account
    case Accounts.get_for_user(id, identity.email) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Account not found"})

      account ->
        json(conn, account)
    end
  end
end
```

## Integrating with Identity Providers

Each identity provider has its quirks. Here's what you need to know for the major ones.

### Google Cloud IAP

Google's IAP injects a signed JWT in the `x-goog-iap-jwt-assertion` header. The JWT is signed with Google's public keys, which rotate periodically. nimble_zta handles key rotation automatically by fetching keys from Google's JWKS endpoint.

Configuration requirements:
- Your GCP project ID
- The OAuth client ID created for IAP
- Optionally, a list of allowed email domains

```elixir
config :my_app, :zta,
  provider: NimbleZTA.Google,
  audience: "/projects/PROJECT_NUMBER/apps/PROJECT_ID",
  issuer: "https://cloud.google.com/iap"
```

### Cloudflare Access

Cloudflare Access uses a similar JWT approach but with different header names and claim structures. The token appears in the `Cf-Access-Jwt-Assertion` header.

```elixir
config :my_app, :zta,
  provider: NimbleZTA.Cloudflare,
  team_domain: "yourteam.cloudflareaccess.com",
  # The audience tag from your Cloudflare Access application
  audience: "32eafc7c7e4e7d3c..."
```

Cloudflare also provides a `Cf-Access-Authenticated-User-Email` header with the plain email, but you should verify the JWT rather than trusting this header directly—it could be spoofed if someone bypasses the proxy.

### AWS ALB with OIDC

AWS Application Load Balancers can authenticate users via OIDC providers (Okta, Auth0, Cognito) and forward identity in the `x-amzn-oidc-data` header.

```elixir
config :my_app, :zta,
  provider: NimbleZTA.AWSALB,
  region: "us-east-1",
  # ALB public key endpoint
  key_endpoint: "https://public-keys.auth.elb.us-east-1.amazonaws.com"
```

## Defense in Depth: Combining ZTA with Traditional Auth

Zero Trust at the proxy level is powerful, but it's not the only layer you should have. Defense in depth means multiple, independent security controls.

Here's a pattern I've used in production: ZTA provides the primary identity verification, but the application maintains its own session and authorization layer.

```elixir
defmodule MyAppWeb.Plugs.HybridAuth do
  @moduledoc """
  Combines ZTA identity with application-level sessions.

  The ZTA layer proves WHO the user is.
  The application layer tracks WHAT they can do.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, identity} <- verify_zta(conn),
         {:ok, user} <- load_or_create_user(identity),
         {:ok, permissions} <- load_permissions(user) do
      conn
      |> assign(:current_user, user)
      |> assign(:permissions, permissions)
      |> assign(:zta_identity, identity)
    else
      {:error, :zta_failed} ->
        unauthorized(conn, "Identity verification failed")

      {:error, :user_disabled} ->
        forbidden(conn, "Account has been disabled")

      {:error, _} ->
        unauthorized(conn, "Authentication failed")
    end
  end

  defp verify_zta(conn) do
    # Delegate to nimble_zta
    config = Application.get_env(:my_app, :zta)
    provider = Keyword.fetch!(config, :provider)
    provider.verify_identity(conn, config)
  end

  defp load_or_create_user(identity) do
    case Accounts.get_user_by_email(identity.email) do
      nil ->
        # First time seeing this user - create a record
        Accounts.create_user_from_identity(identity)

      %{disabled: true} = _user ->
        {:error, :user_disabled}

      user ->
        {:ok, user}
    end
  end

  defp load_permissions(user) do
    permissions = Authorization.get_permissions(user)
    {:ok, permissions}
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: message})
    |> halt()
  end

  defp forbidden(conn, message) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{error: message})
    |> halt()
  end
end
```

This hybrid approach gives you:

1. **Identity verification** from the IAP (cryptographically strong)
2. **User management** in your application (can disable users, track activity)
3. **Fine-grained authorization** (roles, permissions, resource-level access)
4. **Audit trail** (every access linked to a verified identity)

The IAP proves the user is who they claim to be. Your application decides what they're allowed to do.

## Handling the Edge Cases

Real-world deployments surface edge cases that documentation rarely covers.

### Local Development

Your laptop isn't behind an identity-aware proxy. You need a way to develop without one.

```elixir
# config/dev.exs
config :my_app, :zta,
  provider: NimbleZTA.Development,
  mock_email: "developer@localhost",
  mock_subject: "dev-user-123"
```

The development provider injects a mock identity without requiring real infrastructure. Just remember to never ship this configuration to production.

### Health Checks and Monitoring

Load balancers need health check endpoints that don't require authentication:

```elixir
scope "/health", MyAppWeb do
  pipe_through :api
  # No ZTA pipeline - these must be accessible
  get "/live", HealthController, :live
  get "/ready", HealthController, :ready
end
```

### WebSocket Connections

Phoenix Channels present a challenge: the identity is verified on the initial HTTP upgrade, but subsequent messages come through the WebSocket. Capture the identity during connection:

```elixir
defmodule MyAppWeb.UserSocket do
  use Phoenix.Socket

  def connect(params, socket, connect_info) do
    # The ZTA headers are available in connect_info
    case verify_zta_from_connect_info(connect_info) do
      {:ok, identity} ->
        {:ok, assign(socket, :current_user_identity, identity)}

      {:error, _} ->
        :error
    end
  end

  defp verify_zta_from_connect_info(connect_info) do
    # Extract and verify the JWT from headers
    headers = connect_info[:x_headers] || []
    # ... verification logic
  end

  def id(socket), do: "user:#{socket.assigns.current_user_identity.email}"
end
```

## The Security Tradeoffs

Zero Trust via IAP isn't a panacea. Know the tradeoffs.

**What you gain:**
- Centralized authentication you don't have to implement
- Cryptographically verified identity on every request
- Consistent security policy across all applications
- Reduced attack surface in your application code

**What you're trusting:**
- The identity provider's security (Google, Cloudflare, etc.)
- The integrity of the network path between proxy and app
- The correctness of nimble_zta's verification logic

That middle point matters. If an attacker can inject requests directly to your application, bypassing the proxy, they could forge headers. Mitigations include:

1. **Network segmentation**: Only allow traffic from the IAP's IP ranges
2. **Mutual TLS**: Require the proxy to present a client certificate
3. **Signed tokens**: Always verify the JWT signature, never trust plain headers

## Conclusion

Zero Trust Authentication represents a fundamental shift from perimeter security to identity-centric security. For Phoenix applications, nimble_zta provides the plumbing to consume verified identity from identity-aware proxies without reinventing the wheel.

The implementation is straightforward: configure your provider, create a verification plug, and wire it into your router. But the real power comes from the architectural clarity. Your application stops being responsible for the messy business of authentication. It receives verified identity claims and makes authorization decisions.

That's not just a technical improvement. It's a reduction in the attack surface you're responsible for defending.

The perimeter is dead. Long live the identity.

---

**Claims to verify:**
- [DATA NEEDED: Verify current nimble_zta version and exact API - the library may have evolved since this was written]
- [DATA NEEDED: Confirm exact header names and JWT claim structures for each provider]
- [DATA NEEDED: Verify Dashbit is the publisher of nimble_zta - this should be confirmed against Hex.pm]
- The SolarWinds attack details and 2011 Google Aurora attack timeline are historical facts but specific dates should be verified for any published article
