-module(rabbit_redis_subscribe).

-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(gen_server2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {redis_connection, rabbit_connection, rabbit_channel, 
                publish_fields, publish_properties, config}).

start_link(Config) ->
    gen_server2:start_link({local, ?MODULE}, ?MODULE, Config, []).

init(Config) ->
    gen_server2:cast(self(), init),
    {ok, #state{config = Config}}.

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(init, State = #state{config = Config}) ->
    process_flag(trap_exit, true),

    RedisConfig = proplists:get_value(redis, Config),
    % TODO select DB
    {ok, RedisConnection} = erldis_client:start_link(
                              proplists:get_value(host, RedisConfig),
                              proplists:get_value(port, RedisConfig)),
    [erldis:subscribe(RedisConnection, C, self()) 
     || C <- proplists:get_value(channels, RedisConfig)],

    RabbitConfig = proplists:get_value(rabbit, Config),
    {ok, RabbitConnection} = amqp_connection:start(direct),
    link(RabbitConnection),

    {ok, RabbitChannel} = amqp_connection:open_channel(RabbitConnection),
    [amqp_channel:call(RabbitChannel, Method) ||
        Method <- resource_declarations(
                    proplists:get_value(declarations, RabbitConfig))],

    PublishFields = set_fields(
                proplists:get_value(publish_fields, RabbitConfig),
                record_info(fields, 'basic.publish'),
                #'basic.publish'{}),
    PublishProperties = set_fields(
                proplists:get_value(publish_properties, RabbitConfig),
                record_info(fields, 'P_basic'),
                #'P_basic'{}),
    {noreply, State#state{redis_connection = RedisConnection, 
                          rabbit_connection = RabbitConnection,
                          rabbit_channel = RabbitChannel,
                          publish_fields = PublishFields,
                          publish_properties = PublishProperties}}.

handle_info({message, Channel, Payload}, State) ->
    Method = #'basic.publish'{routing_key = Channel},
    Method1 = (State#state.publish_fields)(Method),
    Message = #amqp_msg{payload = Payload,
                        props = State#state.publish_properties},
    amqp_channel:call(State#state.rabbit_channel, Method1, Message),
    {noreply, State};

handle_info({'EXIT', RabbitConnection, Reason}, 
            State = #state{rabbit_connection = RabbitConnection}) ->
    {stop, {rabbit_connection_died, Reason}, State};

handle_info({'EXIT', RedisConnection, Reason},
            State = #state{redis_connection = RedisConnection}) ->
    {stop, {redis_connection_died, Reason}, State}.

terminate(_Reason, State) ->
    catch erldis:quit(State#state.redis_connection),
    catch amqp_channel:close(State#state.rabbit_channel),
    catch amqp_connection:close(State#state.rabbit_connection),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% internals

resource_declarations(Declarations) ->
    resource_declarations(Declarations, []).

resource_declarations([{Method, Props} | Rest], Acc) ->
    Names = rabbit_framing_amqp_0_9_1:method_fieldnames(Method),
    Record = rabbit_framing_amqp_0_9_1:method_record(Method),
    resource_declarations(Rest, [set_fields(Props, Names, Record) | Acc]);

resource_declarations([], Acc) ->
    Acc.

set_fields(Props, Names, Record) ->
    {IndexedNames, _Idx} = lists:foldl(
                             fun(Name, {Dict, Idx}) ->
                                     {dict:store(Name, Idx, Dict),
                                      Idx + 1}
                             end,
                             {dict:new(), 2},
                             Names),
    lists:foldl(fun({K, V}, R) ->
                        setelement(dict:fetch(K, IndexedNames), R, V)
                end,
                Record,
                proplists:unfold(Props)).
