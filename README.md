

<img align="right" width="30%" alt="Image of jigsaw puzzle pieces" src="assets/logo-large.png"/>

# Component

The _Component Library_ makes it easy to create simple servers. It is an
attempt to make it so easy to write trivial standalone servers that
people will just naturally split their applications up that way.

A component is a simple module, containing what look like function
definitions. This library generates from it an API module, a GenServer
module, and an implementation module.

<!--
The component library is part of the
[Toyland](https://github.com/pragdave/toyland) suite.  You can use it
standalone, but if you assembly components together using
[Noddy](https://github.com/pragdave/noddy) you'll automatically get
deployment support, statsd/telegraf compatible data collection on every
request, shared logging, and world peace.
-->

> #### ⚠ Developer Health Warning ⚠
>
> The component library is a work in progress. It seems to work, but it
> is not yet battle tested. As people play with it, we'll end up making
> changes to fix problems and add cool facilities. Please experiment
> with it. But don't bet your business on it.

## 🗺 README Roadmap

Sometimes you want your palate to be tempted. Sometimes you just
want to eat.

The first part of this README is the motivation for this library. It's a
quick read, but feel free to [skip it](#the-details) if you're looking
for the main course.

Still here? Cool. Here's a story…

# Let's Grow a Service

Monday starts with a new user story. The UI folks want to keep a list of
which users get "page not found" responses from our app. Someone else is
modifying the controller chain: our job is to record the data.

You decide to implement a simple map where the keys are the user IDs and
the values are a list of the URLs that 404'd for that user.

~~~ elixir
defmodule FourOhFour do
  def create() do
    %{}
  end

  def record_404(history, user, url) do
    Map.update(history, user, [ url ], &[ url | &1 ])
  end

  def for_user(history, user) do
    Map.get(history, user, [])
  end
end
~~~

You're a thoughtful developer: you decided that the users of your
module shouldn't have to know about its internal state, so you provided
a `create` function that returns the initial empty map.

You submit the PR, and the reviewers come back with "where's the
GenServer?". You refrain from the obvious "you never mentioned it should
be a server" and instead modify your module:

~~~ elixir
defmodule FourOhFour do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def record_404(pid, user, url) do
    GenServer.cast(pid, { :record_404, user, url })
  end

  def for_user(pid, user) do
    GenServer.call(pid, { :for_user, user })
  end

  def init(empty_history) do
    { :ok, empty_history }
  end

  def handle_cast({ :record_404, user, url }, history) do
    new_history = Map.update(history, user, [ url ], &[ url | &1 ])
    { :noreply, new_history }
  end

  def handle_call({ :for_user, user }, _from, history) do
    result = Map.get(history, user, [])
    { :reply, result, history }
  end
end
~~~

This is the canonical Elixir GenServer, drawn straight from the original
Erlang. You've always felt uncomfortable with the way it intermixes the
API, the implementation, and all the housekeeping, but everyone does it
that way....

Another day, another code review. Someone just realized that there's
only one instance of this 404 store, so we can make it a named process
and stop having to pass the pid around. You sigh and fire up the editor:

~~~ elixir
defmodule FourOhFour do

  use GenServer

  @me __MODULE__

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: @me)
  end

  def record_404(user, url) do
    GenServer.cast(@me, { :record_404, user, url })
  end

  def for_user(user) do
    GenServer.call(@me, { :for_user, user })
  end

  def init(empty_history) do
    { :ok, empty_history }
  end

  def handle_cast({ :record_404, user, url }, history) do
    new_history = Map.update(history, user, [ url ], &[ url | &1 ])
    { :noreply, new_history }
  end

  def handle_call({ :for_user, user }, _from, history) do
    result = Map.get(history, user, [])
    { :reply, result, history }
  end
end
~~~

That's something else that's always bugged you: the way the API code has
to change even though we just changed the implementation. Oh well....

A month later the project lead for a different application comes over.
"We really like the results that folks are seeing with your 404
logging." she says. Can you turn it into a standalone Elixir application
so we can include it as a dependency?

You start to work on your resumé.

## The Start of a Moral

That's a lot of code churn. And none of it involved the actually logic
of the module; it was all the boilerplate surrounding code that changed.

Clearly, this is the kind of stuff we do all the time, and the changes
are so minor that we just shrug them off as a cost of doing business.

But I think the real cost is nothing to do with writing all those
`handle_xxx` functions. Instead the cost is in the way we think about
our code.

When we come to write something in Elixir, we're forced to answer two
questions at the same time: how does it work, and how does it run?
What's the logic, and what's the lifecycle? And we have to know both
before we start. Switching lifecycle models has a (small) cost, and that
means we try to guess it right up front. Changing from a library module
to a server is fairly mechanical, but it still doubles the size of the
code. And changing from a server to a free-standing
component is a fairly big deal.

> #### An aside: Application/Project/Component/Service/...?
>
>Elixir has unfortunately adopted some of the bad naming history from
>Erlang. As a result, we have words such as _project_ and _application_
>that can mean many different things, even within the same codebase.
>
>I'm proposing we clarify things. Let's call the thing created when we
>run `mix new` a _component_. A component is an entity that can be
>shared and deployed. It has its own set of dependencies and
>configuration. It can be stored in its own source control repository or
>hex project (although it needn't be)
>
>When we create something that delivers business value, we package
>together a number of components. One of these is nominated to be the
>code's entry point (using `mod:` in `mix.exs`). Let's call this thing
>that we built an _assembly_.

Back to the story...

We all know that highly coupled code is hard to change, and that the
need to accommodate change is why we spend time thinking about good
design. If we came from a Rails background, we've heard stories of (or
participated in) _Monorail_ projects: single Rails applications with
hundreds of classes, tens or hundreds of thousands of lines of code, and
a dependency map that looks like the wad of hair you pull out of the
shower drain.

Rails apps get that way because it's easier to add new code into the
existing code base than to split it out as a separate entity.

It's _convenience over conscience_.

I see a lot of evidence that we're falling into the same habits in the
Elixir world. I've seen many multi-thousand line modules. I've rarely
seen a Phoenix app where the developers have implemented the business
logic in other, free-standing apps (and I don't count the things in
umbrella apps as being free standing, firstly because the individual
components are not sharable, and secondly because that fact that all the
code is in one place tempts developers to just call randomly between the
child apps.)

So the _Component_ library is an attempt to start an exploration of
alternatives. It's a first try at a framework that guides us to
think of our code as self-contained components. It does this by making
components as easy to write and use as any other code.

### Components ands the 404 Logger

Let's go back to the original 404 component. The initial implementation
stays the same:

~~~ elixir
defmodule FourOhFour do
  def create() do
    %{}
  end

  def record_404(history, user, url) do
    Map.update(history, user, [ url ], &[ url | &1 ])
  end

  def for_user(history, user) do
    Map.get(history, user, [])
  end
end
~~~

Now someone says they want it to be a server. We use the component
framework to add all the boilerplate for us:

~~~ elixir
defmodule FourOhFour do

  use Component.Strategy.Dynamic,
      state_name:    :history,
      initial_state: %{}

  one_way record_404(history, user, url) do
    Map.update(history, user, [ url ], &[ url | &1 ])
  end

  two_way for_user(history, user) do
    Map.get(history, user, [])
  end
end
~~~

The `use Component...` stuff says that this module is a GenServer (by
default named the same as the module). The variable `history` is used
to pass around the state, and the initial value of the state for each
server we create is the empty map. We start its supervisor running with

~~~ elixir
FourOhFour.initialize()
~~~

and create new server processes with

~~~ elixir
FourOhFour.create()
~~~

The only other change to the original is that we changed the `def` of
the `record_404` function to be `one_way`, and the `def` of `for_user`
to be `two_way`.

A one-way function's prime job is to update state. Its return value
becomes the new state of our server. It is implemented under the covers
using a GenServer _cast_.

A two-way function returns a value (and so is a GenServer _call_). Its
return value is what is given back to the called of the API. If you
don't need to update state, that's all you have to do. If you _do_ need
to change the state as well as return a value, you can do it as well.

Now the second code review asks for this to become a singleton named server. We
sigh at the magnitude of the request and change the code:

~~~ elixir
defmodule FourOhFour do

  use Component.Strategy.Global,
      state_name:    :history,
      initial_state: %{}

  one_way record_404(history, user, url) do
    Map.update(history, user, [ url ], &[ url | &1 ])
  end

  two_way for_user(history, user) do
    Map.get(history, user, [])
  end
end
~~~

Yup: the only change is to use the `Global` strategy.

Finally, we're asked to make this into an independent component. That's
also a simple change:

~~~ elixir
defmodule FourOhFour do

  use Component.Strategy.Global,
      state_name:    :history,
      initial_state: %{},
      top_level:     true

  one_way record_404(history, user, url) do
    Map.update(history, user, [ url ], &[ url | &1 ])
  end

  two_way for_user(history, user) do
    Map.get(history, user, [])
  end
end
~~~

The `top_level: true` parameter adds `Application` behaviour to this
module and adds a top-level supervisor. Just add `mod: FourOhFour` to
your `mix.exs` and your 404 logger will be started automatically when it
is included in any other assembly.

## So...

Using the Component library has changed the way I write Elixir. I now
break my code into lots of small components, each an Elixir/Erlang
application). I then assemble these together using regular dependencies.
(During development, when things are fluid, I use path dependencies.
Later I may change these to git dependencies. I could also use hex.)

I'd like to encourage you to think about your code the same way, as
assemblies of simple components.

I'd also like to hear your feedback. This is just an experiment: it's
the starting point of an ongoing discussion. For now, let's use [the
issues list](https://github.com/pragdave/component/issues) for this.

I'll consider all this as time well spent if we manage to get people
thinking about how they structure applications.

And they all lived happily ever after.

----

# The Details

### Component Types

We support a number of component types:

* [global](#global-components): a singleton process
* [dynamic](#dynamic-components): on-demand processes
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

#### Dynamic Components

A _dynamic_ component is a factory that creates worker processes on
demand. The workers run the code declared in the component's module.
Each worker maintains its own state. When you're done with a worker, you
destroy it. You could create dynamic components when someone first
connects to your web app, and use it to maintain that person's state for
the lifetime of their session.

Here's a dynamic component that implements a set of counters:

  ~~~ elixir
  defmodule Counter do

    use Component.Strategy.Dynamic,
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

Because the dynamic component has multiple workers, you must first
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

A hungry component defines a way to process a collection, where the
processing of items in the collection is automatically parallelized.

  ~~~ elixir
  defmodule FaceRecognizer do

    use Component.Strategy.Hungry

    def process(%JPeg{ image: image }) do
      image |> jpeg_to_bitmap |> Vision.recognize_face()
    end

    def process(%PNG{ image: image }) do
      image |> png_to_bitmap |> Vision.recognize_face()
    end

  end
  ~~~

  Unlike the other components, you define the action to be taken on a
  member of the collection by writing a function called `process`. This
  can use pattern matching and guard clauses to vary the behaviour
  depending on the vale passed in.

  You invoke the hungry component using

  ~~~ elixir
  people = FaceRecognizer.consume(collection_of_images)
  ~~~

  By default, the results are returned as a list, where each entry is
  the value of appling the processing to the corresponding value in the
  input collection. You can override this by providing an `into:` parameter.

  ~~~ elixir
  contacts = ContactCollection.new
  people = FaceRecognizer.consume(collection_of_images, into: contacts)
  ~~~

  A hungry consumer will normally run a worker process for each of the
  process schedulers available on the current node (which is normally
  the number of available CPUs). You can override this globally for a
  particular consumer with the `default_concurrency` option:


  ~~~ elixir
  defmodule FaceRecognizer do

    use Component.Strategy.Hungry,
        default_concurrency: 10

    . . .
  ~~~

  You can also override it on a particular call to `consume` using the
  `concurrency:` option.

  ~~~ elixir
  people = FaceRecognizer.consume(collection_of_images, concurrency: 5)
  ~~~




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

With the exception of hungry consumers, all component types run one or
more worker processes, and those workers maintain state.

The Component library makes you use the same name for this state in all
your `one_way` and `two_way` functions. This name is `state` by default,
but can be changed using the `state_name:` option.

~~~ elixir
defmodule Dictionary do

   use Component.Strategy.Global,
      state_name:    :word_list,           # <- our state is called `word_list`
      initial_state: read_word_list()

   two_way random_word(word_list) do
    word_list |> Enum.random()             # <- and we can refer to it by name
  end

   defp read_word_list(word_list) do
    "../assets/words.txt"
    |> Path.expand(__DIR__)
    |> File.read!
    |> String.split("\n", trim: true)
  end
end
~~~

> #### Controversy Trigger Alert!
>
> People with a strong abhorrence of magic should skip the next section.

Because you declare the name to be used as the state variable, you can
omit it as a parameter to `one_way` and `two_way` and the component
library will add it in for you:

~~~ elixir
defmodule Dictionary do

   use Component.Strategy.Global,
      state_name:    :word_list,           # <- our state is called `word_list`
      initial_state: read_word_list()

   two_way random_word() do                # <- no explicit parameter
    word_list |> Enum.random()             #    but we can refer to it by name
  end

  # ...
end
~~~

Why would I even countenance such an evil use of the dark arts? It's
because I wanted to be able to write the one- and two-way functions to
reflect the way they are called and not the way they're implemented. In
a global component you'd call `Dictionary.random_word()` with no
parameter, and I wanted the code in the module to look like this.

The library doesn't mind if you include the state variable or not: it's
up to you


#### Initial State

The initial state of a component is set by a combination of things.

First, when you write a component, you can specify an initial state as
an option. For example, the following code sets the initial state of the
component to the result of reading the word list:

~~~ elixir
use Component.Strategy.Global,
   state_name:    :word_list,
   initial_state: read_word_list()     # <- run this each time a worker is created
~~~

You can override this initial state when you create a component by
passing a value to `create()`.

Second, you can specify the default initial state using a function of
arity one.

When you call `create` for such a component, the override value you give
will be passed to this function, and the function's value becomes the
initial state. If you don't pass an override to create, the function
will receive `nil`.

The following component has a two element map as a state. The
`initial_state` function allows these elements to be individually
overwritten by create:

~~~ elixir
use Component.Strategy.Dynamic,
    initial_state: fn overrides ->
      Map.merge(
        %{ one: :default_one, two: :default_two },
        overrides || %{})
      end
~~~

The code associated with the `initial_state` option is invoked to set
the state each time a new worker process is created. This evaluation is
lazy. In this example the `read_word_list` function is not called when
the module is defined. Instead, the code is saved and run when each
worker gets started.

The second way to set the state is when you create a worker.

~~~ elixir
defmodule Counter do
  use Component.Strategy.Dynamic,
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

### Name Scope

You can inspect the code created by component by adding the `show_code:
true` option. Here's the code for the Counter module:

~~~ elixir
defmodule FourOhFour do
  @name Counter
  def initialize() do
    Component.Strategy.Dynamic.Supervisor.run(worker_module: __MODULE__.Worker, name: @name)
  end

  def create(override_state \\ CA.no_overrides()) do
    spec = {__MODULE__.Worker, Common.derive_state(override_state, 0)}
    Component.Strategy.Dynamic.Supervisor.create(@name, spec)
  end

  def destroy(worker) do
    Component.Strategy.Dynamic.Supervisor.destroy(@name, worker)
  end

  nil

  def increment(worker_pid, by) do
    GenServer.cast(worker_pid, {:increment, by})
  end

  def value(worker_pid) do
    GenServer.call(worker_pid, {:value}, 5000)
  end

  def wrapped_create() do
    initialize()
  end

  defmodule(Worker) do
    use(GenServer)

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(state) do
      {:ok, state}
    end

    def handle_cast({:increment, by}, șțąțɇ) do
      count = șțąțɇ
      new_state = __MODULE__.Implementation.increment(count, by)
      {:noreply, new_state}
    end

    def handle_call({:value}, _, șțąțɇ) do
      count = șțąțɇ
      __MODULE__.Implementation.value(count) |> Common.create_genserver_response(șțąțɇ)
    end

    defmodule(Implementation) do
      def increment(count, by) do
        _ = var!(count)
        count + by
      end

      def value(count) do
        _ = var!(count)
        count
      end
    end
  end
end
~~~

Notice that we have three modules here. The top-level `FourOhFour`
contains the external API. The nested `Worked` module is the Genserver
code, and the `Implementation` module contains the code that you wrote
inside the one-way and two-way functions.

This structure reflects the way I've been writing GenServers by hand
(although I put `Worker` and `Implementation` into their own files).

However, it has a side-effect. The code inside your one- and two-way
functions actually executes inside its own module. As a result this code
won't work:

~~~ elixir
defmodule SalesTax do
  use Component.Strategy.Dynamic,
      state_name:    :count,
      initial_state: 0

  two_way calculate_tax(item, quantity) do
    sales_tax_calculation(item.price, item.tax_type, quantity)
  end

  def sales_tax_calculation(item.price, item.tax_type, quantity) do
    # ...
  end
end
~~~

The problem is that the call to `sales_tax_calculation` happens inside
the `SalesTax.Implementation` module and the function itself is defined
in `SalesTax`.

Originally I solved this issue by automatically moving all functions
defined at the top-level into the `Implementation` module. But I took
that out after I'd used it for a while. The reason is that I found it
tempted me into writing large modules containing the entire
implementation. I'd add just one more `wafer-thin function` because it
was easy.

Now I simply write all the support code in one or more separate modules.
If there are only one or two of these support functions, I might just
put them into a `Helpers` module inside the top-level:

~~~ elixir
defmodule SalesTax do
  use Component.Strategy.Dynamic,
      state_name:    :count,
      initial_state: 0

  two_way calculate_tax(item, quantity) do
    Helpers.sales_tax_calculation(item.price, item.tax_type, quantity)
  end

  defmodule Helpers do
    def sales_tax_calculation(item.price, item.tax_type, quantity) do
      # ...
    end
  end
end
~~~

However, as soon as this module threatens to become larger than a
handful of lines I'll split it out into its own file.

### Component Lifecycle

A global component must be created before use. Once created, it may be
accessed by simply calling the functions it contains. There is no need
to identify a particular worker, as there is only one per component. A
global component may be destroyed, in which case it must be recreated
before being used again.

Dynamic and pooled components must be initialized. This process does not
necessarily create any worker processes; it simply prepares the
component for use.

With dynamic components you gain access to a worker by telling the
component to create it. This returns an identifier for that worker
process, which you must pass to subsequent calls to functions in the
component. You should eventually destroy workers that you create.

Pooled components are automatically created when needed, so there's no
need to call their `create` function.

| Type    | Initialize | Create/destroy |      Call      |
|---------|:----------:|:--------------:|:--------------:|
| Global  |     —      |       ✔        |       ✔       |
| Dynamic |     ✔      |       ✔        |       ✔       |
| Pooled  |     ✔      |       —        |       ✔       |
| Hungry  |     ✔      |       —        |  `consume()`  |

Hungry components have no state, and do not need to be created or
destroyed—this is handled automatically.

## Components as Top-Level Applications

Part of the impetus for creating this was to encourage folks to write
single-responsibility components, one per mix project. To make this even
easier, if you have a single component in a mix project, you no longer
need an `application.ex`. Instead

1. Add the option `top_level: true` to your component definition, and

2. Point the `mod` option in your `mix.exs` directly at your component's
   module.

Here's a runnable example that implements a simple event counter:

### MISSING: event counter