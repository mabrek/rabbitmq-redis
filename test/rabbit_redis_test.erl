-module(rabbit_redis_test).

-include_lib("amqp_client/include/amqp_client.hrl").

-compile(export_all).

-define(REDIS_HOST, "localhost").
-define(REDIS_PORT, 6379).
-define(CHANNEL, <<"channel">>).
-define(EXCHANGE, <<"test_exchange">>).
-define(QUEUE, <<"test_queue">>).
-define(TIMEOUT, 1000).

test() ->
    redis_only_pubsub(),
    empty_config(),
    subscribe(),
    publish(),
    ok.

redis_only_pubsub() ->
    {ok, Publisher} = erldis:connect(?REDIS_HOST, ?REDIS_PORT),
    {ok, Subscriber} = erldis:connect(?REDIS_HOST, ?REDIS_PORT),

    erldis:subscribe(Subscriber, ?CHANNEL, self()),
    1 = erldis:publish(Publisher, ?CHANNEL, <<"Payload">>),

    receive {message, ?CHANNEL, <<"Payload">>} -> ok
    after ?TIMEOUT -> throw(timeout)
    end,

    erldis:quit(Publisher),
    erldis:quit(Subscriber),
    ok.

empty_config() ->
    with_configuration([], fun() -> ok end).

subscribe() ->
    with_configuration([[{type, subscribe},
                         {redis, [{host, ?REDIS_HOST},
                                  {port, ?REDIS_PORT},
                                  {channels, [?CHANNEL]}]},
                         {rabbit, [{declarations, [{'exchange.declare',
                                                    [{exchange, ?EXCHANGE},
                                                     auto_delete
                                                    ]}]},
                                   {publish_fields, [{exchange, ?EXCHANGE}]}]}]],
                       fun() -> with_rabbit_redis(fun subscribe_fun/2) end).

subscribe_fun(Channel, Redis) ->
    pong = gen_server2:call(rabbit_redis_worker, ping), % ensure started

    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
    #'queue.bind_ok'{} = 
        amqp_channel:call(Channel,
                          #'queue.bind'{queue = Q, exchange = ?EXCHANGE,
                                         routing_key = ?CHANNEL}),
    #'basic.consume_ok'{consumer_tag = CTag} = 
        amqp_channel:subscribe(Channel, 
                               #'basic.consume'{queue = Q, no_ack = true}, 
                               self()),
    receive #'basic.consume_ok'{consumer_tag = CTag} -> ok
    after ?TIMEOUT -> throw(timeout)
    end,

    1 = erldis:publish(Redis, ?CHANNEL, <<"payload">>),

    receive {#'basic.deliver'{consumer_tag = CTag, exchange = ?EXCHANGE,
                               routing_key = ?CHANNEL}, 
             #amqp_msg{payload = <<"payload">> }} -> ok
    after ?TIMEOUT -> throw(timeout)
    end,
    ok.

publish() ->
    with_configuration([[{type, publish},
                         {redis, [{host, ?REDIS_HOST},
                                  {port, ?REDIS_PORT}]},
                         {rabbit, [{declarations, [{'queue.declare', 
                                                    [{queue, ?QUEUE},
                                                     auto_delete]}]},
                                   {queue, ?QUEUE}]}]],
                       fun() -> with_rabbit_redis(fun publish_fun/2) end).

publish_fun(Channel, Redis) ->
    erldis:subscribe(Redis, ?QUEUE, self()),
    #'queue.declare_ok'{queue = ?QUEUE} = 
        amqp_channel:call(Channel, #'queue.declare'{queue = ?QUEUE, 
                                                    auto_delete = true}),
    Message = #amqp_msg{payload = <<"foo">>},
    ok = amqp_channel:call(Channel,
                           #'basic.publish'{routing_key = ?QUEUE},
                           Message),
    receive {message, ?QUEUE, <<"foo">>} -> ok
    after ?TIMEOUT -> throw(timeout)
    end.

with_configuration(Config, Fun) ->
    application:set_env(rabbit_redis, bridges, Config),
    ok = application:start(rabbit_redis),
    Fun(),
    ok = application:stop(rabbit_redis).

with_rabbit_redis(Fun) ->
    {ok, Rabbit} = amqp_connection:start(direct),
    {ok, Channel} = amqp_connection:open_channel(Rabbit),
    {ok, Redis} = erldis:connect(?REDIS_HOST, ?REDIS_PORT),
    Fun(Channel, Redis),
    erldis:quit(Redis),
    amqp_channel:close(Channel),
    amqp_connection:close(Rabbit),
    ok.
