-module(rabbit_redis_test).
-export([test/0]).

test() ->
    ok = application:start(rabbit_redis),
    ok = application:stop(rabbit_redis),
    
    {ok, RedisPublisher} = erldis:connect(),
    Redis = erldis_sup:client(),
    RedisChannel = <<"channel">>,
    Payload = <<"payload">>,
    erldis:subscribe(Redis, RedisChannel, self()),
    1 = erldis:publish(RedisPublisher, RedisChannel, Payload),
    receive
        {message, Channel, Payload} -> 
            ok
    after
        100 ->
             throw(timeout)
    end.
