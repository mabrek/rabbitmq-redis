-module(rabbit_redis_sup).

-behaviour(supervisor2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1]).

start_link(Bridges) ->
    % TODO empty bridges
    supervisor2:start_link({local, ?MODULE}, ?MODULE, child_specs(Bridges)).

init(Childs) ->
    % TODO delayed restart
    {ok, {{one_for_one, 10, 10}, Childs}}.

child_specs(Bridges) ->
    lists:map(fun child_spec/1, Bridges).

child_spec(Config) ->
    % TODO use type from config to determine module
    {rabbit_redis_subscribe,
     {rabbit_redis_subscribe, start_link, [Config]},
     transient,
     16#ffffffff,
     worker,
     [rabbit_redis_subscribe]
    }.
