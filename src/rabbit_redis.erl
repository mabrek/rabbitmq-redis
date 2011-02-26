-module(rabbit_redis).

-behaviour(application).
-export([start/2, stop/1]).

start(normal, []) ->
    rabbit_redis_sup:start_link(case application:get_env(bridges) of
                                    {ok, Bridges} -> Bridges;
                                    undefined -> []
                                end).

stop(_) ->
    ok.
