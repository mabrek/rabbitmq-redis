-module(rabbit_redis).

-behaviour(application).
-export([start/0, stop/0, start/2, stop/1]).

start() ->
    ok.

stop() ->
    ok.

start(_, _) ->
    ok.

stop(_) ->
    ok.
