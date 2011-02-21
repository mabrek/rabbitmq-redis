-module(rabbit_redis_sup).

-behaviour(supervisor2).

%% API
-export([start_link/0]).

%% callbacks
-export([init/1]).

start_link() ->
    supervisor2:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Worker = {rabbit_redis_worker,
              {rabbit_redis_worker, start_link, []},
              transient,
              16#ffffffff,
              worker,
              [rabbit_redis_worker]
             },
    {ok, {{one_for_one, 1, 10}, [Worker]}}.
