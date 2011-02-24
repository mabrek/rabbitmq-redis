-module(rabbit_redis_subscribe).

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
    [erldis:subscribe(RedisConnection, C, self()) || C <- proplists:get_value(channels, RedisConfig)],
    {noreply, State#state{redis_connection = RedisConnection}}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State = #state{redis_connection = RedisConnection}) ->
    catch erldis:quit(RedisConnection),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
