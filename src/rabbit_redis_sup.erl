-module(rabbit_redis_sup).

-behaviour(supervisor2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1]).

start_link(Bridges) ->
    supervisor2:start_link(
      {local, ?MODULE}, 
      ?MODULE, 
      [{rabbit_redis_worker,
        {rabbit_redis_worker, start_link, [Config]},
        transient,
        16#ffffffff,
        worker,
        [rabbit_redis_worker]} || Config <- Bridges]).

init(Childs) ->
    % TODO delayed restart
    {ok, {{one_for_one, 10, 10}, Childs}}.
