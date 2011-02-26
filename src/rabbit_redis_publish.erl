-module(rabbit_redis_publish).

-include("rabbit_redis.hrl").

-export([init/1, handle_info/2]).

init(State = #worker_state{bridge_module = ?MODULE,
                           rabbit_channel = RabbitChannel,
                           config = Config}) ->
    State.

handle_info(_, State) ->
    {noreply, State}.
