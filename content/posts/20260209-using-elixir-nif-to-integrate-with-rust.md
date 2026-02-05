%{
title: "Using Elixir Nif To Integrate With Rust",
category: "Programming",
tags: ["elixir","functional programming","rust","programming"],
description: "Using native implemented functions in elixir to integrate with rust",
published: true
}
---

<!--Using Native Implemented Functions in Elixir to integrate with Rust-->

The BEAM virtual machine is one of the best pieces of runtime engineering ever built. It handles concurrency, fault tolerance, and distribution with an elegance that most platforms cannot touch. But ask it to hash a million passwords, parse a 500MB binary file, or run a tight numerical computation, and you will feel the cost of its design tradeoffs.

This is not a flaw. It is a deliberate choice. The BEAM optimizes for latency, fairness, and resilience — not raw throughput on a single operation. The engineers who built Erlang understood that most of the work in a telecom switch is coordination, not computation. They were right.

But sometimes you need both. And for those moments, the BEAM provides an escape hatch: **Native Implemented Functions**, or NIFs.

## What NIFs Are and Why They Exist

A NIF is a function implemented in a compiled language (historically C) that the BEAM calls directly, in-process, with no serialization overhead and no inter-process communication. From Elixir's perspective, calling a NIF looks identical to calling a regular function. Under the hood, execution drops into native machine code, does its work, and returns a result as an Erlang term.

The performance difference can be dramatic. Operations that take milliseconds in pure Elixir can drop to microseconds when implemented as NIFs. For CPU-bound work — cryptographic hashing, image transformation, data compression, numerical computation — the speedup is often 10x to 100x.

Traditionally, NIFs were written in C using the `erl_nif` API. This worked, but it also meant writing C. Manual memory management, pointer arithmetic, buffer overflows, segfaults — the full menu of problems that make C dangerous in production systems.

This is where Rust enters the picture.

## Why Rust, Specifically

Rust gives you the performance of C with compile-time memory safety guarantees. No garbage collector, no runtime overhead, but also no null pointer dereferences, no use-after-free bugs, no data races. The ownership model catches these errors before your code ever runs.

For NIFs, this matters enormously. A bug in a NIF does not crash a single Elixir process. It crashes the entire BEAM VM — every process, every connection, every supervised child. Gone. The isolation guarantees that make OTP supervision trees so powerful simply do not apply to native code running inside the VM.

Rust does not make NIF crashes impossible. But it eliminates the largest category of bugs that cause them.

## Rustler: The Bridge Between Two Worlds

[Rustler](https://github.com/rusterlium/rustler) is the standard library for writing Elixir NIFs in Rust. It wraps the raw `erl_nif` C API in safe Rust abstractions, handles term encoding and decoding, integrates with Mix as a build tool, and catches Rust panics before they can take down the VM.

You do not need to understand the `erl_nif` API to use Rustler. You do not need to write any C. You write Rust functions, annotate them with a macro, and Rustler handles the rest.

Let's build something concrete.

## Setting Up a Project with Rustler

Start with a new Elixir project:

```bash
mix new hasher
cd hasher
```

Add Rustler to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:rustler, "~> 0.35.0"}
  ]
end
```

Fetch the dependency and generate the native module:

```bash
mix deps.get
mix rustler.new
```

The generator will ask you for a module name. Enter `Hasher.Native`. It will also ask for the library name — `hasher_native` works fine. This creates the following structure:

```
native/hasher_native/
  src/
    lib.rs
  Cargo.toml
  .cargo/
    config.toml
```

You now have a Rust crate living inside your Elixir project, fully wired into the Mix build system. When you run `mix compile`, Rustler compiles the Rust code and loads the resulting shared library into the BEAM automatically.

## A Practical Example: Fast Hashing

Let's implement something useful. We will build a NIF that performs Blake3 hashing — a cryptographic hash function that is significantly faster than SHA-256 while maintaining strong security properties.

First, add the `blake3` crate to your Rust dependencies. Edit `native/hasher_native/Cargo.toml`:

```toml
[package]
name = "hasher_native"
version = "0.1.0"
edition = "2021"

[lib]
name = "hasher_native"
path = "src/lib.rs"
crate-type = ["cdylib"]

[dependencies]
rustler = "0.35"
blake3 = "1.5"
```

Now write the NIF. Replace the contents of `native/hasher_native/src/lib.rs`:

```rust
use rustler::{Binary, Env, NewBinary};

#[rustler::nif]
fn blake3_hash(data: Binary) -> String {
    let hash = blake3::hash(data.as_slice());
    hash.to_hex().to_string()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn blake3_hash_file(path: String) -> Result<String, String> {
    let contents = std::fs::read(&path)
        .map_err(|e| format!("Failed to read file: {}", e))?;
    let hash = blake3::hash(&contents);
    Ok(hash.to_hex().to_string())
}

#[rustler::nif]
fn blake3_hash_raw(data: Binary) -> Binary {
    let hash = blake3::hash(data.as_slice());
    let bytes = hash.as_bytes();
    let mut output = NewBinary::new(data.get_env(), bytes.len());
    output.as_mut_slice().copy_from_slice(bytes);
    output.into()
}

rustler::init!("Elixir.Hasher.Native");
```

Three functions, each illustrating a different pattern:

- `blake3_hash` takes binary data, returns a hex string. Simple and direct.
- `blake3_hash_file` reads a file from disk and hashes it. Because file I/O can be slow, it is scheduled on a dirty CPU scheduler (more on this shortly).
- `blake3_hash_raw` returns the raw 32-byte hash as a binary rather than a hex string. This demonstrates returning Erlang binaries from Rust.

Now create the Elixir module that exposes these NIFs. Create or edit `lib/hasher/native.ex`:

```elixir
defmodule Hasher.Native do
  use Rustler,
    otp_app: :hasher,
    crate: "hasher_native"

  # NIF stubs — these are replaced at load time
  def blake3_hash(_data), do: :erlang.nif_error(:nif_not_loaded)
  def blake3_hash_file(_path), do: :erlang.nif_error(:nif_not_loaded)
  def blake3_hash_raw(_data), do: :erlang.nif_error(:nif_not_loaded)
end
```

The `def` clauses are stubs. They exist only as fallbacks — if the NIF shared library fails to load, calling these functions raises an error instead of silently doing nothing. When the library loads successfully, Rustler replaces these function heads with the native implementations.

Compile and test:

```elixir
iex(1)> Mix.install([])
iex(2)> Hasher.Native.blake3_hash("hello world")
"d74981efa70a0c880b8d8c1985d075dbcbf679b99a5f9914e5aaf96b831a9e24"

iex(3)> Hasher.Native.blake3_hash_raw("hello world")
<<215, 73, 129, 239, 167, 10, 12, 136, ...>>
```

That is a working Rust NIF called from Elixir. The entire round trip — Elixir term to Rust bytes, through the Blake3 algorithm, back to an Elixir term — happens without any serialization protocol, without any process boundary, without any IPC overhead.

## The Danger Zone

NIFs are powerful. They are also dangerous. Understanding the risks is not optional.

### Risk 1: Crashes Kill the VM

I said it before, but it bears repeating. If your NIF segfaults, the BEAM VM dies. Not your process. Not your application. The entire VM. Every connected client. Every running GenServer. Everything.

In a language built around "let it crash" fault tolerance, this is the one thing that cannot crash safely.

Rust mitigates this significantly — you will not get segfaults from safe Rust code. But `unsafe` blocks, FFI calls to C libraries, or logic errors that cause panics are still possible. Rustler catches Rust panics and converts them to Erlang exceptions rather than letting them unwind through the BEAM's C stack. This is a critical safety net, but it is not absolute.

### Risk 2: Scheduler Blocking

The BEAM runs a fixed number of scheduler threads — typically one per CPU core. These schedulers cooperatively multiplex thousands of lightweight processes. The contract is simple: every function should return quickly, ideally within one millisecond. The BEAM enforces this for Erlang and Elixir code through reduction counting and preemption.

NIFs break this contract. A NIF that runs for 50 milliseconds blocks a scheduler thread for that entire duration. No other process can run on that thread. If all your schedulers are blocked by NIFs, the entire system freezes — no message passing, no supervision, no heartbeats, nothing.

### Dirty Schedulers: The Mitigation

The BEAM provides **dirty schedulers** specifically for this problem. Dirty schedulers are additional threads that run outside the normal scheduling discipline. Work scheduled on a dirty scheduler does not block the regular schedulers.

There are two types:

- **Dirty CPU schedulers**: For CPU-intensive work that will take a long time but will not block on I/O.
- **Dirty I/O schedulers**: For operations that might block on I/O (file reads, network calls from native code).

In Rustler, you annotate your NIF with the appropriate scheduler:

```rust
#[rustler::nif(schedule = "DirtyCpu")]
fn expensive_computation(data: Binary) -> String {
    // Long-running CPU work goes here
}

#[rustler::nif(schedule = "DirtyIo")]
fn read_and_process(path: String) -> Result<String, String> {
    // File I/O and processing goes here
}
```

Any NIF that might exceed a millisecond of execution time should use a dirty scheduler. This is not a suggestion. It is a requirement for production systems.

## What Rustler Gives You

Beyond the basic NIF machinery, Rustler provides several features that make Rust NIFs safer and more ergonomic than their C counterparts.

### Type-Safe Term Encoding

Rustler automatically converts between Erlang terms and Rust types. Elixir integers become Rust `i64` values. Binaries become `Binary` references. Lists become `Vec<T>`. Atoms become Rust enums. If the types do not match at runtime, Rustler returns an error rather than reading garbage memory.

```rust
#[rustler::nif]
fn sum_list(numbers: Vec<f64>) -> f64 {
    numbers.iter().sum()
}

#[rustler::nif]
fn process_pairs(pairs: Vec<(String, i64)>) -> Vec<String> {
    pairs
        .into_iter()
        .map(|(name, count)| format!("{}: {}", name, count))
        .collect()
}
```

### Struct Encoding with Derive Macros

You can map Elixir structs directly to Rust structs:

```rust
#[derive(rustler::NifStruct)]
#[module = "Hasher.Config"]
struct Config {
    algorithm: String,
    iterations: u32,
    output_format: String,
}

#[rustler::nif]
fn hash_with_config(data: Binary, config: Config) -> String {
    // Use config.algorithm, config.iterations, etc.
    format!("Hashing with {} ({} iterations)", config.algorithm, config.iterations)
}
```

On the Elixir side, you define a matching struct:

```elixir
defmodule Hasher.Config do
  defstruct [:algorithm, :iterations, :output_format]
end
```

Rustler handles the serialization transparently. Pass an Elixir struct, receive a Rust struct. No manual field extraction, no positional arguments, no map traversal.

### Panic Catching

When Rust code panics (via `panic!`, `unwrap()` on `None`, or an out-of-bounds array access), Rustler catches the panic and converts it to an Erlang exception. The VM stays alive. The calling Elixir process crashes, which supervisors can restart.

This turns a catastrophic failure into an ordinary, recoverable one. It does not make panics acceptable — your Rust code should still handle errors properly — but it provides a safety net that C NIFs simply do not have.

## NIFs vs Ports vs External Processes

NIFs are not the only way to call native code from Elixir. Understanding the alternatives helps you choose the right tool.

### Ports

A Port starts an external OS process and communicates with it over stdin/stdout using a binary protocol. The external process runs in complete isolation — if it crashes, the BEAM is unaffected. The Elixir side receives a message that the port closed and can restart it.

The cost is serialization. Every call requires encoding data to a binary format, writing it to a pipe, reading the response, and decoding it. For high-frequency, low-latency operations, this overhead dominates.

**Use Ports when**: safety matters more than speed, the operations are infrequent, or you are calling into a library with known stability issues.

### Port Drivers

Port drivers are similar to NIFs — they run inside the BEAM process — but they communicate through a message-passing interface rather than direct function calls. They are more complex to write and offer fewer advantages over NIFs for most use cases. They are largely a historical artifact.

**Use Port Drivers when**: you need async native callbacks into the BEAM (though NIFs with dirty schedulers often cover this now).

### External Processes via System.cmd

The simplest approach: shell out to a command-line tool and parse the output.

```elixir
{output, 0} = System.cmd("blake3sum", [file_path])
```

Zero integration complexity. Zero risk to the VM. But also zero performance for hot-path operations — process startup overhead alone can dwarf the actual computation time.

**Use System.cmd when**: you need to call an existing CLI tool occasionally and do not care about milliseconds.

### The Decision Framework

Ask these questions in order:

1. **Is this on a hot path?** If no, use a Port or System.cmd. Do not introduce NIF complexity for operations that run once a minute.
2. **Is the native library well-tested and stable?** If no, use a Port. Isolate the risk.
3. **Do you need microsecond latency?** If yes, use a NIF. Ports add at least tens of microseconds per call.
4. **Can you write it in safe Rust?** If yes, use Rustler. If you need extensive `unsafe` blocks or C FFI, consider whether a Port might be the wiser choice.

## Testing NIFs

Testing NIFs follows the same patterns as testing any other Elixir code. The functions are just functions — call them and assert on the results:

```elixir
defmodule Hasher.NativeTest do
  use ExUnit.Case

  test "blake3_hash returns correct hex digest" do
    # Known test vector
    assert Hasher.Native.blake3_hash("") ==
      "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
  end

  test "blake3_hash_raw returns 32-byte binary" do
    result = Hasher.Native.blake3_hash_raw("test input")
    assert byte_size(result) == 32
  end

  test "blake3_hash handles large inputs" do
    large_input = :crypto.strong_rand_bytes(10_000_000)
    result = Hasher.Native.blake3_hash(large_input)
    assert is_binary(result)
    assert String.length(result) == 64
  end

  test "blake3_hash_file returns error for missing file" do
    assert {:error, _reason} = Hasher.Native.blake3_hash_file("/nonexistent/path")
  end
end
```

### CI Considerations

Building Rust NIFs in CI requires Rust toolchain installation. Your CI pipeline needs both Elixir/OTP and Rust available. For GitHub Actions, this means adding a Rust setup step:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: erlef/setup-beam@v1
    with:
      elixir-version: '1.17'
      otp-version: '27'
  - uses: dtolnay/rust-toolchain@stable
  - run: mix deps.get
  - run: mix test
```

For projects that want to avoid requiring Rust in CI or on deployment machines, Rustler supports **precompiled NIFs**. The `rustler_precompiled` package lets you compile the native code for multiple targets ahead of time and distribute the resulting binaries via GitHub releases. End users get the performance of a NIF without needing the Rust toolchain installed.

```elixir
# In mix.exs, for library authors distributing precompiled NIFs
defp deps do
  [
    {:rustler, ">= 0.0.0", optional: true},
    {:rustler_precompiled, "~> 0.8"}
  ]
end
```

This is how major Elixir libraries like `explorer` (backed by Polars) and `tokenizers` (backed by Hugging Face's Rust tokenizer) ship their NIFs. The end user runs `mix deps.get` and gets a precompiled binary for their platform. No Rust required.

## When Not to Use NIFs

I want to be direct about this: most Elixir applications do not need NIFs.

If your bottleneck is I/O — database queries, HTTP calls, file reads — NIFs will not help you. The BEAM is already excellent at I/O-bound concurrency. If your bottleneck is pure computation but it only runs a few times per hour, the complexity of maintaining a Rust crate inside your Elixir project is not worth the speedup.

NIFs are a surgical instrument. They solve a specific problem — CPU-bound hot paths where milliseconds matter — and they solve it well. For everything else, the regular tools are better.

The Elixir ecosystem has matured to the point where the question is not "can I use a NIF here?" but "should I?" The answer is usually no. But when the answer is yes, Rustler makes the experience remarkably clean. You get Rust's performance and safety guarantees wired directly into the BEAM's scheduling and term system, with a build process that integrates into Mix as if it were always there.

That is a genuinely powerful combination. Use it wisely.

### Further Reading

- [Rustler GitHub Repository](https://github.com/rusterlium/rustler)
- [Rustler Precompiled](https://github.com/philss/rustler_precompiled)
- [Erlang Documentation: NIFs](https://www.erlang.org/doc/tutorial/nif)
- [Adopting Erlang - NIFs](https://adoptingerlang.org/docs/production/nifs/)
- [The BEAM Book - Scheduling](https://blog.stenmans.org/theBeamBook/)