%{
title: "Atoms and Ecto custom types",
category: "Programming",
tags: ['elixir','functional programming','ecto'],
description: "Ecto doesn't handle atom by default and you can easily define custom ecto types"
}
---

<!--Ecto doesn&#x27;t handle atom by default and you can easily define custom ecto types-->

Working on [siteguardian.dev](https://siteguardian.dev) I ran into an issue trying to save an embedded schema like:

```elixir
defmodule Result do
  embedded_schema do
    field :status, CheckStatusEnum
    field :code, :string
    field :message, :string
    field :payload, :map
  end
end
```

Which was failing with the following error:

```elixir
{:error,
 #Ecto.Changeset<
   action: :insert,
   changes: %{
...
         errors: [code: {"is invalid", [type: :string, validation: :cast]}],
         data: #Result<>,
         valid?: false
       >
     ],
   },
...
 }
```

So `Ecto` will by default not handle the `atom` passed as the attributes for the result. The solution happened to be pretty straightforward, define a custom Ecto type to handle atoms:

```elixir
defmodule Siteguardian.Util.AtomType do
  @moduledoc false
  use Ecto.Type
  def type, do: :string
  def cast(value), do: {:ok, value}
  def load(value), do: {:ok, String.to_atom(value)}
  def dump(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def dump(_), do: :error
end
```

The magic here happens on the `dump/1` and `load/1` functions; convert atom to string on the way in and convert string to atom on the way out.

## References:

- [A quick dip into ecto types](https://www.glydergun.com/a-quick-dip-into-ecto-types/)
