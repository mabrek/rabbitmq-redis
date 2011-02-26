-module(rabbit_redis_worker).

-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(gen_server2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%TODO extract to hrl
-record(worker_state, {redis_connection, rabbit_connection, rabbit_channel, 
                set_publish_fields, publish_properties, config}).

start_link(Config) ->
    gen_server2:start_link({local, ?MODULE}, ?MODULE, Config, []).

init(Config) ->
    gen_server2:cast(self(), init),
    {ok, #worker_state{config = Config}}.

handle_call(ping, _From, State) ->
    {reply, pong, State}.

handle_cast(init, State = #worker_state{config = Config}) ->
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

    PublishFields = proplists:get_value(publish_fields, RabbitConfig),
    SetPublishFields = fun(Method) ->
                            set_fields(PublishFields,
                                       record_info(fields, 'basic.publish'),
                                       Method)
                       end,
    PublishProperties = set_fields(
                proplists:get_value(publish_properties, RabbitConfig),
                record_info(fields, 'P_basic'),
                #'P_basic'{}),
    {noreply, State#worker_state{redis_connection = RedisConnection, 
                          rabbit_connection = RabbitConnection,
                          rabbit_channel = RabbitChannel,
                          set_publish_fields = SetPublishFields,
                          publish_properties = PublishProperties}}.

handle_info({message, Channel, Payload}, State) ->
    Method = #'basic.publish'{routing_key = Channel},
    Method1 = (State#worker_state.set_publish_fields)(Method),
    Message = #amqp_msg{payload = Payload,
                        props = State#worker_state.publish_properties},
    amqp_channel:call(State#worker_state.rabbit_channel, Method1, Message),
    {noreply, State};

handle_info({'EXIT', RabbitConnection, Reason}, 
            State = #worker_state{rabbit_connection = RabbitConnection}) ->
    {stop, {rabbit_connection_died, Reason}, State};

handle_info({'EXIT', RedisConnection, Reason},
            State = #worker_state{redis_connection = RedisConnection}) ->
    {stop, {redis_connection_died, Reason}, State}.

terminate(_Reason, State) ->
    catch erldis:quit(State#worker_state.redis_connection),
    catch amqp_channel:close(State#worker_state.rabbit_channel),
    catch amqp_connection:close(State#worker_state.rabbit_connection),
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

set_fields(undefined, _, Record) ->
    Record;

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
