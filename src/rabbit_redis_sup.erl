-module(rabbit_redis_sup).

-behaviour(supervisor2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1]).

start_link(Bridges) ->
    supervisor2:start_link({local, ?MODULE}, ?MODULE, [child_specs(Bridges)]).

init([Childs]) ->
    {ok, {{one_for_one, 10, 10}, Childs}}.

child_specs(Bridges) ->
    lists:map(fun child_spec/1, Bridges).

child_spec({subscribe, Channels, Exchange}) ->
    {rabbit_redis_subscribe,
     {rabbit_redis_subscribe, start_link, [Channels, Exchange]},
     transient,
     16#ffffffff,
     worker,
     [rabbit_redis_subscribe]
    }.
