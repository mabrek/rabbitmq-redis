-module(rabbit_redis_test).

-include_lib("amqp_client/include/amqp_client.hrl").

-compile(export_all).

-define(REDIS_HOST, "localhost").
-define(REDIS_PORT, 6379).
-define(CHANNEL, <<"channel">>).
-define(EXCHANGE, <<"test_exchange">>).
-define(TIMEOUT, 1000).

test() ->
    redis_only_pubsub(),
    % TODO start/stop without config
    subscribe(),
    ok.

redis_only_pubsub() ->
    {ok, Publisher} = erldis:connect(?REDIS_HOST, ?REDIS_PORT),
    {ok, Subscriber} = erldis:connect(?REDIS_HOST, ?REDIS_PORT),
    Payload = <<"payload">>,
    erldis:subscribe(Subscriber, ?CHANNEL, self()), % TODO 1 =
    1 = erldis:publish(Publisher, ?CHANNEL, Payload),
    receive
        {message, ?CHANNEL, Payload} -> 
            ok;
        BadResult ->
            throw({bad_result, BadResult})
    after
        ?TIMEOUT ->
            throw(timeout)
    end,
    erldis:quit(Publisher),
    erldis:quit(Subscriber),
    ok.

subscribe() ->
    application:set_env(rabbit_redis, bridges,
                        [[{type, subscribe},
                          {redis, [{host, ?REDIS_HOST},
                                   {port, ?REDIS_PORT},
                                   {channels, [?CHANNEL]}
                                  ]},
                          {rabbit, [{declarations, [{'exchange.declare',
                                                     [{exchange, ?EXCHANGE},
                                                      auto_delete
                                                     ]}]},
                                    {publish_fields, [{exchange, ?EXCHANGE}]}
                                   ]}]]),

    ok = application:start(rabbit_redis),
    pong = gen_server2:call(rabbit_redis_worker, ping), % ensure started

    {ok, Rabbit} = amqp_connection:start(direct),
    {ok, Channel} = amqp_connection:open_channel(Rabbit),
    #'queue.declare_ok'{ queue = Q } = 
        amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
    #'queue.bind_ok'{} = 
        amqp_channel:call(Channel,
                          #'queue.bind'{ queue = Q, exchange = ?EXCHANGE,
                                         routing_key = ?CHANNEL }),
    #'basic.consume_ok'{ consumer_tag = CTag } = 
        amqp_channel:subscribe(Channel, 
                               #'basic.consume'{ queue = Q, no_ack = true }, 
                               self()),
    receive
        #'basic.consume_ok'{ consumer_tag = CTag } -> ok
    after ?TIMEOUT -> throw(timeout)
    end,

    {ok, Redis} = erldis:connect(?REDIS_HOST, ?REDIS_PORT),
    1 = erldis:publish(Redis, ?CHANNEL, <<"payload">>),
    erldis:quit(Redis),

    receive
        {#'basic.deliver'{ consumer_tag = CTag, exchange = ?EXCHANGE,
                           routing_key = ?CHANNEL}, 
         #amqp_msg{ payload = <<"payload">> }} -> 
            ok
    after ?TIMEOUT -> throw(timeout)
    end,

    amqp_channel:close(Channel),
    amqp_connection:close(Rabbit),

    ok = application:stop(rabbit_redis).
