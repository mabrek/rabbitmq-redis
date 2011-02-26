-module(rabbit_redis_publish).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("rabbit_redis.hrl").

-export([init/1, handle_info/2]).

init(State = #worker_state{bridge_module = ?MODULE,
                           rabbit_channel = Channel,
                           config = Config}) ->
    Queue = proplists:get_value(queue, proplists:get_value(rabbit, Config)),
    Method = #'basic.consume'{ queue = Queue, no_ack = true },
    #'basic.consume_ok'{} = amqp_channel:subscribe(Channel, Method, self()),
    State.

handle_info(#'basic.consume_ok'{}, State) ->
    {noreply, State};

handle_info({#'basic.deliver'{routing_key = RedisChannel},
             #amqp_msg{payload = Payload}},
            State = #worker_state{redis_connection = Redis, config = Config}) ->
    erldis:publish(Redis, RedisChannel, Payload),
    {noreply, State}.
