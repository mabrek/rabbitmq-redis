-module(rabbit_redis).

-behaviour(application).
-export([start/2, stop/1]).

start(_, _) ->
    rabbit_redis_sup:start_link().

stop(_) ->
    ok.
