-module(rabbit_redis_test).
-export([test/0]).

test() ->
    ok = application:start(rabbit_redis),
    ok = application:stop(rabbit_redis).
