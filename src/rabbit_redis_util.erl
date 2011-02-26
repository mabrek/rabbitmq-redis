-module(rabbit_redis_util).

-export([set_fields/3]).

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
