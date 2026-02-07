%{
title: "Property-Based Testing with StreamData",
category: "Programming",
tags: ["elixir", "testing", "streamdata", "property-testing"],
description: "Beyond example-based tests: generators, shrinking, and finding edge cases",
published: false
}
---

Your test suite is lying to you.

Not maliciously. It's doing exactly what you asked. You wrote tests for the cases you thought of, and those cases pass. The problem is the cases you didn't think of—the edge cases hiding in the combinatorial explosion of possible inputs that no human could enumerate by hand.

I've watched production systems fail on inputs that seemed obvious in hindsight. A Unicode character in a name field. A negative timestamp. An empty list where the code assumed at least one element. Each of these failures had a test suite that passed with flying colors. The tests verified what the developers imagined; they didn't verify what users would actually do.

Property-based testing flips the script. Instead of testing specific examples, you define properties that should hold for all inputs, then let the computer generate thousands of test cases to try to break them. It's the difference between checking a few points on a curve and verifying the mathematical equation that defines it.

---

## The Limits of Example-Based Testing

Traditional unit tests are example-based. You pick an input, call your function, and assert the output matches your expectation:

```elixir
test "adds two numbers" do
  assert Calculator.add(2, 3) == 5
  assert Calculator.add(0, 0) == 0
  assert Calculator.add(-1, 1) == 0
end
```

This test covers three cases. Your function handles integers from negative infinity to positive infinity. Three divided by infinity is not great coverage.

You could add more examples. Maybe ten. Maybe a hundred. But you're still guessing which inputs matter. And you're almost certainly missing the weird ones—the inputs that expose integer overflow, or rounding errors, or the assumption buried three functions deep that a list is never empty.

Property-based testing asks a different question: What should be true for *any* valid input? For addition, several properties come to mind:

- Commutativity: `add(a, b)` should equal `add(b, a)`
- Identity: `add(a, 0)` should equal `a`
- Associativity: `add(add(a, b), c)` should equal `add(a, add(b, c))`

These properties don't depend on specific values. They should hold whether you're adding 2 and 3 or 999,999 and -42. If you can generate random integers and verify these properties hold across thousands of combinations, you have far more confidence than three hand-picked examples provide.

---

## StreamData: Elixir's Property Testing Library

StreamData is the property-based testing library for Elixir, maintained by the core team. It provides two things: generators for creating random data, and the `check all` macro for running property tests.

Add it to your `mix.exs`:

```elixir
defp deps do
  [
    {:stream_data, "~> 1.0", only: [:dev, :test]}
  ]
end
```

Then import it in your test files:

```elixir
defmodule MyApp.CalculatorTest do
  use ExUnit.Case
  use ExUnitProperties

  property "addition is commutative" do
    check all a <- integer(),
              b <- integer() do
      assert Calculator.add(a, b) == Calculator.add(b, a)
    end
  end
end
```

The `check all` macro generates random integers for `a` and `b`, then runs the assertion. By default, it generates 100 test cases per property. If any case fails, StreamData reports the failing input and attempts to shrink it to the minimal failing case.

---

## Writing Properties That Actually Test Something

The hardest part of property-based testing isn't the syntax—it's figuring out what properties to test. Generic properties like commutativity work for math, but most business logic doesn't have such clean mathematical properties.

Here are patterns that work across different domains:

**Round-trip properties**: If you encode and decode, you should get the original value back.

```elixir
property "JSON encoding round-trips" do
  check all map <- map_of(string(:alphanumeric), integer()) do
    assert map == map |> Jason.encode!() |> Jason.decode!()
  end
end
```

**Invariant properties**: Certain conditions should always hold after an operation.

```elixir
property "sorting produces ordered output" do
  check all list <- list_of(integer()) do
    sorted = Enum.sort(list)
    pairs = Enum.zip(sorted, Enum.drop(sorted, 1))
    assert Enum.all?(pairs, fn {a, b} -> a <= b end)
  end
end
```

**Oracle properties**: Compare your implementation against a known-correct reference.

```elixir
property "my_sort matches Enum.sort" do
  check all list <- list_of(integer()) do
    assert MySorter.sort(list) == Enum.sort(list)
  end
end
```

**Idempotence**: Applying an operation twice should have the same effect as applying it once.

```elixir
property "normalizing email is idempotent" do
  check all email <- email_generator() do
    once = Email.normalize(email)
    twice = Email.normalize(once)
    assert once == twice
  end
end
```

---

## Generators: Built-In and Custom

StreamData ships with generators for common types. Here's a sampling:

```elixir
# Primitives
integer()                    # Any integer
positive_integer()           # 1, 2, 3, ...
float()                      # Any float
boolean()                    # true or false
binary()                     # Random binary data
string(:alphanumeric)        # Letters and numbers
atom(:alphanumeric)          # Atoms from alphanumeric strings

# Collections
list_of(integer())           # [1, -3, 42, ...]
map_of(atom(:alphanumeric), string(:alphanumeric))
tuple({integer(), string(:alphanumeric)})

# Choosing from options
member_of([:pending, :active, :cancelled])
one_of([integer(), float()])
```

Real applications need custom generators. You build them by composing primitives:

```elixir
def user_generator do
  gen all name <- string(:alphanumeric, min_length: 1, max_length: 100),
          email <- email_generator(),
          age <- integer(18..120) do
    %User{name: name, email: email, age: age}
  end
end

def email_generator do
  gen all local <- string(:alphanumeric, min_length: 1, max_length: 64),
          domain <- string(:alphanumeric, min_length: 1, max_length: 63) do
    "#{local}@#{domain}.com"
  end
end
```

The `gen all` macro works like `check all` but returns a generator instead of running assertions. You can then use this generator in your properties:

```elixir
property "users can be serialized" do
  check all user <- user_generator() do
    assert {:ok, _} = User.to_json(user)
  end
end
```

---

## Shrinking: Finding the Minimal Failure

When a property fails, the random input that triggered it is often large and complex. Shrinking automatically finds the smallest input that still fails, making debugging far easier.

Consider this buggy function:

```elixir
defmodule Buggy do
  def process(list) when length(list) > 5 do
    raise "Can't handle more than 5 elements"
  end
  def process(list), do: list
end
```

A property test might generate `[42, -7, 999, 0, 8, -3, 100]` as the failing input. Useful, but noisy. StreamData shrinks this to `[0, 0, 0, 0, 0, 0]`—six zeros. The minimal list that still triggers the bug.

Shrinking works by trying progressively simpler values. For integers, it moves toward zero. For lists, it removes elements and shrinks remaining values. For custom generators built with `gen all`, shrinking happens automatically based on the component generators.

The output looks like this:

```
1) property users can be serialized (MyApp.UserTest)
   test/my_app/user_test.exs:10
   Failed with generated values (after 3 successful runs):

       * Clause:    user <- user_generator()
         Generated: %User{name: "", email: "@.com", age: 18}
```

That shrunk result—an empty name, a malformed email—immediately tells you where to look. The original randomly generated user might have had a 50-character name obscuring the real issue.

---

## Testing Ecto Schemas and Changesets

Property testing shines when validating Ecto changesets. Instead of manually checking a few invalid inputs, generate thousands of them:

```elixir
defmodule MyApp.AccountTest do
  use ExUnit.Case
  use ExUnitProperties
  alias MyApp.Accounts.User

  property "valid users pass changeset validation" do
    check all attrs <- valid_user_attrs() do
      changeset = User.changeset(%User{}, attrs)
      assert changeset.valid?, "Expected valid changeset for: #{inspect(attrs)}"
    end
  end

  property "empty email fails validation" do
    check all attrs <- valid_user_attrs() do
      bad_attrs = Map.put(attrs, :email, "")
      changeset = User.changeset(%User{}, bad_attrs)
      refute changeset.valid?
      assert {:email, _} = hd(changeset.errors)
    end
  end

  property "age under 18 fails validation" do
    check all attrs <- valid_user_attrs(),
              bad_age <- integer(-1000..17) do
      bad_attrs = Map.put(attrs, :age, bad_age)
      changeset = User.changeset(%User{}, bad_attrs)
      refute changeset.valid?
    end
  end

  defp valid_user_attrs do
    gen all name <- string(:alphanumeric, min_length: 1, max_length: 100),
            email <- email_generator(),
            age <- integer(18..120) do
      %{name: name, email: email, age: age}
    end
  end

  defp email_generator do
    gen all local <- string(:alphanumeric, min_length: 1, max_length: 64),
            domain <- string(:alphanumeric, min_length: 1, max_length: 63) do
      "#{local}@#{domain}.com"
    end
  end
end
```

This approach finds edge cases in validation logic that manual tests miss. Maybe your email regex doesn't handle single-character local parts. Maybe your age validation allows `nil` when it shouldn't. Property tests surface these issues by throwing variety at your code.

---

## Testing Business Logic

Property-based testing really proves its worth with business logic. Financial calculations, state machines, pricing engines—anywhere the logic is complex enough that you can't enumerate all cases by hand.

Here's an example testing a shopping cart:

```elixir
defmodule MyApp.CartTest do
  use ExUnit.Case
  use ExUnitProperties
  alias MyApp.Commerce.Cart

  property "cart total equals sum of line items" do
    check all items <- list_of(cart_item_generator(), min_length: 1) do
      cart = Cart.new(items)
      expected_total = items |> Enum.map(&(&1.price * &1.quantity)) |> Enum.sum()
      assert Cart.total(cart) == expected_total
    end
  end

  property "removing an item decreases total" do
    check all items <- list_of(cart_item_generator(), min_length: 2),
              index <- integer(0..(length(items) - 1)) do
      cart = Cart.new(items)
      item_to_remove = Enum.at(items, index)

      original_total = Cart.total(cart)
      updated_cart = Cart.remove_item(cart, item_to_remove.sku)
      new_total = Cart.total(updated_cart)

      assert new_total < original_total or item_to_remove.quantity == 0
    end
  end

  property "applying discount never increases total" do
    check all items <- list_of(cart_item_generator(), min_length: 1),
              discount_percent <- integer(0..100) do
      cart = Cart.new(items)
      original_total = Cart.total(cart)

      discounted = Cart.apply_discount(cart, discount_percent)
      discounted_total = Cart.total(discounted)

      assert discounted_total <= original_total
    end
  end

  defp cart_item_generator do
    gen all sku <- string(:alphanumeric, length: 8),
            price <- positive_integer(),
            quantity <- integer(0..100) do
      %{sku: sku, price: price, quantity: quantity}
    end
  end
end
```

These properties capture business rules without enumerating specific prices or quantities. If someone later changes the discount calculation and accidentally makes it increase prices for certain inputs, the property test will catch it.

---

## Practical Considerations

Property-based tests run slower than example-based tests because they generate many cases. A few strategies help:

**Tune iteration counts**: The default is 100 iterations. For expensive operations, you might lower this. For critical paths, raise it.

```elixir
property "critical calculation is correct", max_runs: 1000 do
  # ...
end
```

**Use `initial_seed` for reproducibility**: When a property fails, StreamData prints the seed. You can fix it to reproduce failures:

```elixir
property "my property", initial_seed: 12345 do
  # ...
end
```

**Start with simple generators**: Complex generators that produce realistic data are nice, but they can mask bugs. A generator that produces empty strings and zeros often finds more issues than one producing "realistic" names and prices.

**Mix property and example tests**: Properties verify general behavior. Example tests document specific scenarios and edge cases you've already encountered. They complement each other.

---

## The Investment Pays Off

Adopting property-based testing requires upfront effort. You need to think harder about what properties your code should satisfy. You need to build generators for your domain types. The first few properties take longer to write than example tests.

But the return compounds. Once you have generators for your core types, writing new properties becomes fast. And those properties catch bugs that example tests would never find—the weird Unicode character, the boundary condition at integer limits, the empty collection that shouldn't have been empty.

I've seen property tests catch bugs that were in production for months, hiding behind edge cases no one had thought to test. That's the gap between testing what you imagine and testing what's actually possible.

The cases you think of are the easy ones. The hard ones are the ones you don't think of. Let the computer think of them for you.

---

**Claims to verify with current documentation:**
- StreamData version compatibility (article uses `~> 1.0`)
- Default iteration count for `check all` (stated as 100)
- Specific generator function names and signatures may have changed
