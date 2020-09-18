%%%------------------------------------------------------------------------
%% Copyright 2019, OpenTelemetry Authors
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% @doc
%% @end
%%%-------------------------------------------------------------------------
-module(ot_ctx).

-export([set_value/2,
         get_value/1,
         get_value/2,
         remove/1,
         clear/0,

         attach/1,
         detach/1,
         get_current/0,

         http_extractor/1,
         http_extractor/2,
         http_injector/1,
         http_injector/2,
         http_extractor_fun/2,
         http_extractor_fun/3,
         http_injector_fun/2,
         http_injector_fun/3]).

-type ctx() :: map().
-type key() :: term().
-type value() :: term().
-type token() :: reference().

-export_type([ctx/0,
              key/0,
              value/0]).

-define(CURRENT_CTX, '$__current_otel_ctx').

-spec set_value(term(), term()) -> ok.
set_value(Key, Value) ->
    case erlang:get(?CURRENT_CTX) of
        Map when is_map(Map) ->
            erlang:put(?CURRENT_CTX, Map#{Key => Value}),
            ok;
        _ ->
            erlang:put(?CURRENT_CTX, #{Key => Value}),
            ok
    end.

-spec get_value(term()) -> term().
get_value(Key) ->
    get_value(Key, undefined).

-spec get_value(term(), term()) -> term().
get_value(Key, Default) ->
    case erlang:get(?CURRENT_CTX) of
        undefined ->
            Default;
        Map when is_map(Map) ->
            maps:get(Key, Map, Default);
        _ ->
            Default
    end.

-spec clear() -> ok.
clear() ->
    erlang:erase(?CURRENT_CTX).

-spec remove(term()) -> ok.
remove(Key) ->
    case erlang:get(?CURRENT_CTX) of
        Map when is_map(Map) ->
            erlang:put(?CURRENT_CTX, maps:remove(Key, Map)),
            ok;
        _ ->
            ok
    end.

-spec get_current() -> map().
get_current() ->
    case erlang:get(?CURRENT_CTX) of
        Map when is_map(Map) ->
            Map;
        _ ->
            #{}
    end.

-spec attach(map()) -> token().
attach(Ctx) ->
    erlang:put(?CURRENT_CTX, Ctx).

-spec detach(token()) -> ok.
detach(Token) ->
    erlang:put(?CURRENT_CTX, Token).


%% Extractor and Injector setup functions

http_extractor(FromText) ->
    {fun ?MODULE:http_extractor_fun/2, FromText}.

http_extractor_fun(Headers, FromText) ->
    New = FromText(Headers, ?MODULE:get_current()),
    ?MODULE:set_current(New).

http_extractor(Key, FromText) ->
    {fun ?MODULE:http_extractor_fun/3, {Key, FromText}}.

http_extractor_fun(Headers, Key, FromText) ->
    New = FromText(Headers, ?MODULE:get_value(Key, #{})),
    ?MODULE:set_value(Key, New).

http_injector(ToText) ->
    {fun ?MODULE:http_injector_fun/2, ToText}.

http_injector_fun(Headers, ToText) ->
    Headers ++ ToText(Headers, ?MODULE:get_current()).

http_injector(Key, ToText) ->
    {fun ?MODULE:http_injector_fun/3, {Key, ToText}}.

http_injector_fun(Headers, Key, ToText) ->
    Headers ++ ToText(Headers, ?MODULE:get_value(Key, #{})).
