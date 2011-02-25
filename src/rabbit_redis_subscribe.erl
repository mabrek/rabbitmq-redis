-module(rabbit_redis_subscribe).

-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(gen_server2).

%% API
-export([start_link/1]).

%% callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {redis_connection, rabbit_connection, rabbit_channel, config}).

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
    [amqp_channel:call(Method, RabbitChannel) ||
        Method <- resource_declarations(
                    proplists:get_value(declarations, RabbitConfig))],

    {noreply, State#state{redis_connection = RedisConnection, 
                          rabbit_connection = RabbitConnection,
                          rabbit_channel = RabbitChannel}}.

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
    {IndexedNames, _Idx} = lists:foldl(
                             fun(Name, {Dict, Idx}) ->
                                     {dict:store(Name, Idx, Dict),
                                      Idx + 1}
                                     end,
                             {dict:new(), 2},
                             Names),
    Declaration = lists:foldl(
                    fun({K, V}, R) ->
                            setelement(dict:fetch(K, IndexedNames), R, V)
                            end,
                    rabbit_framing_amqp_0_9_1:method_record(Method),
                    Props),
    resource_declarations(Rest, [Declaration | Acc]);

resource_declarations([], Acc) ->
    Acc.
