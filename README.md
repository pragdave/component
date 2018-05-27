work in progress warning:

#  ☠☠ DON'T EVEN THINK OF USING THIS ☠☠

<img align="right" width="30%" alt="Image of jigsaw puzzle pieces" src="assets/g4547.png"/>

# Component

The _Component Library_ makes it easy to create simple servers. It is an
attempt to make it so easy to write trivial standalone servers that
people will just naturally split their applications up that way.

A component is a simple module, containing what look like function
definitions. This library generates from it an API module, a GenServer module,
and an implementation module.

The component library is part of the
[Toyland](https://github.com/pragdave/toyland) suite.  You can use it
standalone, but if you assembly components together using [Noddy](https://github.com/pragdave/noddy)
you'll automatically get deployment support, statsd/telegraf compatible
data collection on every request, shared logging, and world peace.

### Component Types

We support a number of component types:

* [global](#global-components): a singleton process
* [named](#named-components): on-demand processes
* [pooled](#pooled-components): a pool of processes that typically
  represent limited resources
* [hungry](#hungry-components): a pool of processes that process a
  collection in parallel

#### Global Components

A _global_ component runs as a singleton process, accessed by name. All
calls to it are resolved to this single process, and the state is
persisted across calls. A logging facility might be implemented as a
global component.

Here's a global component that stores a list of words in its state,
exporting a function that returns a random word.

  ~~~ elixir
  defmodule Dictionary do

    use Component.Strategy.Global,
        state_name:    :word_list,
        initial_state: read_word_list()

    two_way random_word() do      # <- this is the externally accessible interface
      word_list |> Enum.random()
    end

    # helper

    defp read_word_list() do
      "../assets/words.txt"
      |> Path.expand(__DIR__)
      |> File.read!
      |> String.split("\n", trim: true)
    end
  end
  ~~~

To get it running, you call

  ~~~ elixir
  Dictionary.create()
  ~~~

Then, anywhere in the application, you can get a random word using

  ~~~ elixir
  word = Dictionary.random_word()
  ~~~

#### Named Components

A _named_ component is a factory that creates worker processes on
demand. The workers run the code declared in the component's module.
Each worker maintains its own state. When you're done with a worker, you
destroy it. You could create named components when someone first
connects to your web app, and use it to maintain that person's state for
the lifetime of their session.

Here's a named component that implements a set of counters:

  ~~~ elixir
  defmodule Counter do

    use Component.Strategy.Named,
        state_name:    :count,
        initial_state: 0

    one_way increment(by \\ 1) do
      count + by
    end

    two_way value() do
      count
    end
  end
  ~~~

Because the named component has multiple workers, you must first
initialize the overall component. This is a one-time thing:

  ~~~ elixir
  Counter.initialize()
  ~~~

Whenever you need a new counter, you first create it. You then call
its functions:

  ~~~ elixir
  acc1 = Counter.create
  acc2 = Counter.create

  Counter.increment(acc1, 2)
  Counter.value(acc1)         #=> 2
  Counter.value(acc2)         #=> 0
  ~~~


#### Pooled Components

A _pooled_ component represents a pool of worker processes. When you
call a pooled worker, it handles your request using its existing state,
and any updates to that state are retained: the worker is a resource
that is shared on a call-by-call basis. Workers may be automatically
created and destroyed as demand dictates. You might use pooled workers
to manage access to limited resources (database connections are a common
example).

  ~~~ elixir
  defmodule StockQuoteConnection do

    use Component.Strategy.Pooled,
        state_name:    :quote_connection,
        initial_state: Quotes.connect_to_service()

    two_way get_quote(symnbol) do
      Quotes.get_quote(quote_connection, symbol)
    end
  end
  ~~~

Pooled resources are always called transactionally, so there's no need
to create a worker. You still have to initialize the component,
though.

  ~~~ elixir
  StockQuoteConnection.initialize()

  values = pmap(symbols, &StockQuoteConnection.get_quote(&1))
  ~~~

#### Hungry Components


### One and Two Way Functions

A component defines its external interface using the `one_way` and
`two_way` declarations. These look and behave precisely like functions
defined using `def`, except they do not support guard clauses.

As its name implies, a one way function does not send a response to
its caller. It is also asynchronous. (Internally, it is implemented
using `GenServer.cast`.  The return value of a `one_way` function is the
updated state.

A two way function returns a result to its caller, and so is synchronous
(yup, it uses `GenServer.call`).

By default, the value returned by a two way function is the value
returned to the caller. In this case, the state is not changed.

You update the state using one of the `set_state` functions. The first
form takes the new state and a block as parameters. It sets the state
from the first parameter, and the value returned by the block becomes
the value returned by the function. For example:

~~~ elixir
# return the current value, and increment the state
two_way return_current_and_update(n) do
  set_state(tally + n) do
    tally
  end
end
~~~

The second variant is `set_state_and_return`. This takes a single value
and sets both the state and return value from it:

~~~ elixir
# increment the current state and return the new value
two_way update_and_return(n) do
  set_state_and_return(tally + n)
end
~~~


### State

With the exception of libraries, all component types run one or more
worker processes, and those workers maintain state.

The Component library handles state a little differently (some would say
controversially). Rather than declare the state as a parameter in all
the component's functions, you give it a name at the top of your module
in the `using` clause. The state is then available inside your
component's functions using that name:


~~~ elixir
defmodule Dictionary do

   use Component.Strategy.Global,
      state_name:    :word_list,           # <- our state is called `word_list`
      initial_state: read_word_list()

   two_way random_word() do
    word_list |> Enum.random()             # <- and we can refer to it by name
  end

   defp read_word_list() do
    "../assets/words.txt"
    |> Path.expand(__DIR__)
    |> File.read!
    |> String.split("\n", trim: true)
  end
end
~~~

#### Initial State

There are two ways to set the initial state of a worker. The first is
shown in the previous example:

~~~ elixir
use Component.Strategy.Global,
   state_name:    :word_list,
   initial_state: read_word_list()     # <- run this each time a worker is created
~~~

The code associated with the `initial_state` option is invoked to set
the state each time a new worker process is created. This evaluation is
lazy. In this example the `read_word_list` function is not called when
the module is defined. Instead, the code is saved and run when each
worker gets started.

The second way to set the state is when you create a worker.

~~~ elixir
defmodule Counter do
  use Component.Strategy.Named,
      state_name:    :count,
      initial_state: 0

  one_way increment(by \\ 1) do
    count + by
  end

  two_way value() do
    count
  end
end
~~~

Here, it you call `Counter.create()`, the initial state will be set to
`0`, the value in the `using` clause. If instead you pass a value, such
as `Counter.create(99)`, that value will be used to set the state.


### Component Lifecycle

Library components have no lifecycle—you simply call the functions they
contain.

A global component must be created before use. Once created, it may be
accessed by simply calling the functions it contains. There is no need
to identify a particular worker, as there is only one per component. A
global component may be destroyed, in which case it must be recreated
before being used again.

Named and pooled components must be initialized. This process does not
necessarily create any worker processes; it simply prepares the
component for use.

With named components you gain access to a worker by telling the
component to create it. This returns an identifier for that worker
process, which you must pass to subsequen calls to functions in the
component. You should eventually destroy workers that you create.

Pooled components are automatically created when needed, so there's no
need to call their `create` function.

| Type    | Initialize | Create/destroy | Call |
|---------|:----------:|:--------------:|:----:|
| Library |     —      |      —         |  ✔  |
| Global  |     —      |       ✔        |  ✔  |
| Named   |     ✔      |       ✔        |  ✔  |
| Pooled  |     ✔      |       —        |  ✔  |
