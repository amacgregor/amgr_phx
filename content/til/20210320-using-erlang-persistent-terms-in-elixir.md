%{
title: "Using Erlang Persistent Terms In Elixir",
category: "Programming",
tags: ["programming","elixir","erlang","functional programming"],
description: "Persistent term is a new data storage introduced in erlang 21 that is exceptional well suited for readonly use cases",
published: true
}
---

<!--Persistent_term is a new data storage introduced in Erlang 21 that is exceptional well suited for readonly use cases.-->

Recently I learned about an erlang module introduced on OTP 21.2 called `persistent_term`. 

The module is similar to `ets`, but it has been greatly optimized for reading speeds at the cost more expensive writes and updates to existing terms. Let's take a quick look at an example of persistent_terms.

```elixir
iex(1)> :persistent_term.info()
%{count: 11, memory: 1160}

iex(2)> :persistent_term.get() 
[
  {:logger_proxy, {:logger_proxy, #PID<0.73.0>, {:logger_olp, :logger_proxy}}},
  {{:logger_config, {:"$handler_config$", Logger}}, 10},
  {{:logger_olp, :logger_std_h_default}, :async},
  {{:logger_config, :supervisor_bridge}, 7},
  {:rex_nodes_observer, #Reference<0.4121486589.1675493377.224648>},
  {{:logger_olp, :logger_proxy}, :async},
  {{:logger_config, :supervisor}, 7},
  {{:logger_config, :"$primary_config$"}, 7},
  {{:logger_config, {:"$handler_config$", :simple}}, :undefined},
  {{:logger_config, {:"$handler_config$", :default}}, :undefined},
  {{:logger_config, :application_controller}, 7}
]

iex(3)> :persistent_term.put(:secret_configuration, [%{key: "value"}, %{key: "another value"}])
:ok

iex(4)> :persistent_term.get(:secret_configuration)                                           
[%{key: "value"}, %{key: "another value"}]

iex(5)> :persistent_term.get()                     
[
  {:logger_proxy, {:logger_proxy, #PID<0.73.0>, {:logger_olp, :logger_proxy}}},
  {{:logger_config, {:"$handler_config$", Logger}}, 10},
  {{:logger_olp, :logger_std_h_default}, :async},
  {:secret_configuration, [%{key: "value"}, %{key: "another value"}]},
  {{:logger_config, :supervisor_bridge}, 7},
  {:rex_nodes_observer, #Reference<0.4121486589.1675493377.224648>},
  {{:logger_olp, :logger_proxy}, :async},
  {{:logger_config, :supervisor}, 7},
  {{:logger_config, :"$primary_config$"}, 7},
  {{:logger_config, {:"$handler_config$", :simple}}, :undefined},
  {{:logger_config, {:"$handler_config$", :default}}, :undefined},
  {{:logger_config, :application_controller}, 7}
]
```

## Pros

- VM-wide storage, and accessible from any module.
- Optimized for read performance.
- Part of OTP no additional dependecies need

## Cons

- Updates and inserts can be expensive
- No protection for naming collitions