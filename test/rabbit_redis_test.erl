-module(rabbit_redis_test).
-export([test/0]).

test() ->
    ok = application:start(rabbit_redis),
    ok = application:stop(rabbit_redis),
    
    Redis = erldis_sup:client(),
    RedisChannel = <<"channel">>,
    Payload = <<"payload">>,
    erldis:subscribe(Redis, RedisChannel, self()),
    erldis:publish(Redis, RedisChannel, Payload),
    receive
        {message, Payload, Channel} -> 
            ok
    after
        100 ->
             throw(timeout)
    end.
