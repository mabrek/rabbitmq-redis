-module(rabbit_redis_test).

-include("amqp_client.hrl").

-export([test/0]).

-define(REDIS_HOST, "localhost").
-define(REDIS_PORT, 6379).
-define(CHANNEL, <<"channel">>).
-define(EXCHANGE, <<"test_exchange">>).

test() ->
    redis_only_pubsub(),
    % TODO start/stop without config
    application:set_env(rabbit_redis, bridges,
                        [
                         [{type, subscribe},
                          {redis, [{host, ?REDIS_HOST},
                                   {port, ?REDIS_PORT},
                                   {channels, [?CHANNEL]}
                                  ]},
                          {rabbit, [{declarations, ['exchange.declare',
                                                    [{exchange, ?EXCHANGE},
                                                     {type, <<"direct">>},
                                                     durable
                                                    ]]},
                                    {publish_fields, [{exchange, ?EXCHANGE}]}
                                   ]}
                        ]
                       ),
    ok = application:start(rabbit_redis),
    receive after 1000 -> ok end,
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
