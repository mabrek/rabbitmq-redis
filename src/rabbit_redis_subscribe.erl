-module(rabbit_redis_subscribe).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("rabbit_redis.hrl").

-record(subscribe_state, {set_publish_fields, publish_properties}).

-export([init/1, handle_info/2]).

init(State = #worker_state{bridge_module = ?MODULE,
                                 redis_connection = RedisConnection,
                                 config = Config}) ->
    % TODO navigate subproperties via rabbit_redis_util
    [erldis:subscribe(RedisConnection, C, self())
     || C <- proplists:get_value(channels,
                                 proplists:get_value(redis, Config))],

    RabbitConfig = proplists:get_value(rabbit, Config),
    PublishFields = proplists:get_value(publish_fields, RabbitConfig),
    SetPublishFields = fun(Method) ->
                               rabbit_redis_util:set_fields(
                                 PublishFields,
                                 record_info(fields, 'basic.publish'),
                                 Method)
                       end,
    PublishProperties = rabbit_redis_util:set_fields(
                          proplists:get_value(publish_properties, RabbitConfig),
                          record_info(fields, 'P_basic'),
                          #'P_basic'{}),
    State#worker_state{
      bridge_state = #subscribe_state{set_publish_fields = SetPublishFields,
                                      publish_properties = PublishProperties}}.

handle_info({message, Channel, Payload}, 
            State = #worker_state{bridge_state = #subscribe_state{ 
                                    set_publish_fields = SetPublishFields,
                                    publish_properties = PublishProperties}}) ->
    Method = (SetPublishFields)(#'basic.publish'{routing_key = Channel}),
    Message = #amqp_msg{payload = Payload, props = PublishProperties},
    amqp_channel:call(State#worker_state.rabbit_channel, Method, Message),
    {noreply, State}.
