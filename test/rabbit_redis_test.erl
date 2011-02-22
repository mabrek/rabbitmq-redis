-module(rabbit_redis_test).
-export([test/0]).

-define(REDIS_HOST, "localhost").
-define(REDIS_PORT, 6379).

test() ->
    start_stop(),
    redis_only_pubsub().

start_stop() ->
    ok = application:start(rabbit_redis),
    ok = application:stop(rabbit_redis).

redis_only_pubsub() ->
    {ok, Publisher} = erldis_client:start_link(?REDIS_HOST, ?REDIS_PORT),
    {ok, Subscriber} = erldis_client:start_link(?REDIS_HOST, ?REDIS_PORT),
    Channel = <<"channel">>,
    Payload = <<"payload">>,
    erldis:subscribe(Subscriber, Channel, self()),
    1 = erldis:publish(Publisher, Channel, Payload),
    receive
        {message, Channel, Payload} -> 
            ok;
        BadResult ->
            throw({bad_result, BadResult})
    after
        100 ->
            throw(timeout)
    end.
