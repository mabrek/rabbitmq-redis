-module(rabbit_redis_subscribe).

-behaviour(gen_server2).

%% API
-export([start_link/2]).

%% callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {redis_connection, redis_channels, rabbit_connection, rabbit_channel, rabbit_exchange}).

start_link(Channels, Exchange) ->
    gen_server2:start_link({local, ?MODULE}, ?MODULE, [Channels, Exchange], []).

init([Channels, Exchange]) ->
    gen_server2:cast(self(), init),
    {ok, #state{redis_channels = Channels, rabbit_exchange = Exchange}}.

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(init, State = #state{redis_channels = Channels, rabbit_exchange = Exchange}) ->
    process_flag(trap_exit, true),
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
