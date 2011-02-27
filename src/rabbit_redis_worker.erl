-module(rabbit_redis_worker).
-behaviour(gen_server2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-include("rabbit_redis.hrl").

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

    RabbitConfig = proplists:get_value(rabbit, Config, []),
    {ok, RabbitConnection} = amqp_connection:start(direct),
    link(RabbitConnection),
    {ok, RabbitChannel} = amqp_connection:open_channel(RabbitConnection),
    [amqp_channel:call(RabbitChannel, Method) ||
        Method <- resource_declarations(
                    proplists:get_value(declarations, RabbitConfig, []))],

    BridgeModule = module_for_type(proplists:get_value(type, Config)),
    State1 = BridgeModule:init(
               State#worker_state{redis_connection = RedisConnection, 
                                  rabbit_connection = RabbitConnection,
                                  rabbit_channel = RabbitChannel,
                                  bridge_module = BridgeModule}),
    {noreply, State1}.

handle_info({'EXIT', RabbitConnection, Reason}, 
            State = #worker_state{rabbit_connection = RabbitConnection}) ->
    {stop, {rabbit_connection_died, Reason}, State};

handle_info({'EXIT', RedisConnection, Reason},
            State = #worker_state{redis_connection = RedisConnection}) ->
    {stop, {redis_connection_died, Reason}, State};

handle_info(Message, State = #worker_state{bridge_module = BridgeModule}) ->
    BridgeModule:handle_info(Message, State).

terminate(_Reason, State) ->
    catch erldis:quit(State#worker_state.redis_connection),
    catch amqp_channel:close(State#worker_state.rabbit_channel),
    catch amqp_connection:close(State#worker_state.rabbit_connection),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% internals

module_for_type(subscribe) -> rabbit_redis_subscribe;
module_for_type(publish)   -> rabbit_redis_publish.

resource_declarations(Declarations) ->
    resource_declarations(Declarations, []).

resource_declarations([{Method, Props} | Rest], Acc) ->
    Names = rabbit_framing_amqp_0_9_1:method_fieldnames(Method),
    Record = rabbit_framing_amqp_0_9_1:method_record(Method),
    resource_declarations(
      Rest, 
      [rabbit_redis_util:set_fields(Props, Names, Record) | Acc]);

resource_declarations([], Acc) ->
    Acc.
