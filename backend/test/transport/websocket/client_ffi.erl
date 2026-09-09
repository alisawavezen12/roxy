-module(client_ffi).

-export([
    connect/2,
    send_text/2,
    send_binary/2,
    send_ping/2,
    receive_frame/2,
    close/1
]).

connect(Url, Origin) ->
    try
        {Host, Port, Path} = parse_url(Url),
        {ok, Socket} = gen_tcp:connect(
            binary_to_list(Host),
            Port,
            [binary, {active, false}, {packet, raw}],
            2000
        ),
        Key = base64:encode(crypto:strong_rand_bytes(16)),
        Request = [
            <<"GET ">>, Path, <<" HTTP/1.1\r\nHost: ">>, Host, <<":">>,
            integer_to_binary(Port),
            <<"\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n">>,
            <<"Sec-WebSocket-Key: ">>, Key,
            <<"\r\nSec-WebSocket-Version: 13\r\nOrigin: ">>, Origin,
            <<"\r\n\r\n">>
        ],
        ok = gen_tcp:send(Socket, Request),
        case recv_headers(Socket, <<>>, 2000) of
            {ok, <<"HTTP/1.1 101", _/binary>>, Rest} ->
                {ok, {ws_client, Socket, Rest}};
            {ok, Response, _Rest} ->
                gen_tcp:close(Socket),
                {error, Response};
            {error, Reason} ->
                gen_tcp:close(Socket),
                {error, inspect_reason(Reason)}
        end
    catch
        Class:CaughtReason -> {error, inspect_reason({Class, CaughtReason})}
    end.

send_text(Connection, Message) ->
    send_frame(Connection, 1, Message).

send_binary(Connection, Message) ->
    send_frame(Connection, 2, Message).

send_ping(Connection, Payload) ->
    send_frame(Connection, 9, Payload).

receive_frame({ws_client, Socket, Buffer}, Timeout) ->
    case recv_frame(Socket, Buffer, Timeout) of
        {ok, Opcode, Payload, Rest} ->
            put({websocket_client_buffer, Socket}, Rest),
            case Opcode of
                1 -> {ok, {text, Payload}};
                2 -> {ok, {binary, Payload}};
                9 -> {ok, {ping, Payload}};
                10 -> {ok, {pong, Payload}};
                8 -> {error, close_reason(Payload)};
                _ -> {error, <<"unsupported frame">>}
            end;
        {error, Reason} -> {error, inspect_reason(Reason)}
    end.

close({ws_client, Socket, _Buffer} = Connection) ->
    _ = send_frame(Connection, 8, <<1000:16>>),
    gen_tcp:close(Socket),
    nil.

parse_url(Url) ->
    Prefix = <<"ws://">>,
    <<Prefix:(byte_size(Prefix))/binary, Rest/binary>> = Url,
    [Authority, PathRest] = binary:split(Rest, <<"/">>),
    [Host, PortBinary] = binary:split(Authority, <<":">>),
    {Host, binary_to_integer(PortBinary), <<"/", PathRest/binary>>}.

recv_headers(Socket, Buffer, Timeout) ->
    case binary:match(Buffer, <<"\r\n\r\n">>) of
        {Position, 4} ->
            HeaderSize = Position + 4,
            <<Headers:HeaderSize/binary, Rest/binary>> = Buffer,
            {ok, Headers, Rest};
        nomatch ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} -> recv_headers(Socket, <<Buffer/binary, Data/binary>>, Timeout);
                Error -> Error
            end
    end.

send_frame({ws_client, Socket, _}, Opcode, Payload) ->
    Mask = crypto:strong_rand_bytes(4),
    Masked = mask(Payload, Mask),
    Length = byte_size(Payload),
    Header = case Length of
        N when N =< 125 -> <<1:1, 0:3, Opcode:4, 1:1, N:7>>;
        N when N =< 65535 -> <<1:1, 0:3, Opcode:4, 1:1, 126:7, N:16>>;
        N -> <<1:1, 0:3, Opcode:4, 1:1, 127:7, N:64>>
    end,
    normalize(gen_tcp:send(Socket, <<Header/binary, Mask/binary, Masked/binary>>)).

recv_frame(Socket, InitialBuffer, Timeout) ->
    Stored = case get({websocket_client_buffer, Socket}) of
        undefined -> InitialBuffer;
        Value -> erase({websocket_client_buffer, Socket}), Value
    end,
    case ensure_bytes(Socket, Stored, 2, Timeout) of
        {ok, <<_Fin:1, _Rsv:3, Opcode:4, Masked:1, LengthCode:7, Rest/binary>>} ->
            {Length, AfterLength} = read_length(Socket, LengthCode, Rest, Timeout),
            MaskSize = case Masked of 1 -> 4; 0 -> 0 end,
            {ok, Full} = ensure_bytes(Socket, AfterLength, MaskSize + Length, Timeout),
            <<Mask:MaskSize/binary, Payload:Length/binary, Tail/binary>> = Full,
            Decoded = case Masked of 1 -> mask(Payload, Mask); 0 -> Payload end,
            {ok, Opcode, Decoded, Tail};
        Error -> Error
    end.

read_length(_Socket, Length, Rest, _Timeout) when Length < 126 ->
    {Length, Rest};
read_length(Socket, 126, Rest, Timeout) ->
    {ok, Full} = ensure_bytes(Socket, Rest, 2, Timeout),
    <<Length:16, Tail/binary>> = Full,
    {Length, Tail};
read_length(Socket, 127, Rest, Timeout) ->
    {ok, Full} = ensure_bytes(Socket, Rest, 8, Timeout),
    <<Length:64, Tail/binary>> = Full,
    {Length, Tail}.

ensure_bytes(_Socket, Buffer, Count, _Timeout) when byte_size(Buffer) >= Count ->
    {ok, Buffer};
ensure_bytes(Socket, Buffer, Count, Timeout) ->
    case gen_tcp:recv(Socket, 0, Timeout) of
        {ok, Data} -> ensure_bytes(Socket, <<Buffer/binary, Data/binary>>, Count, Timeout);
        Error -> Error
    end.

mask(Payload, <<A, B, C, D>>) ->
    mask(Payload, <<A, B, C, D>>, 0, <<>>).

mask(<<>>, _Mask, _Index, Acc) -> Acc;
mask(<<Byte, Rest/binary>>, Mask, Index, Acc) ->
    MaskByte = binary:at(Mask, Index rem 4),
    mask(Rest, Mask, Index + 1, <<Acc/binary, (Byte bxor MaskByte)>>).

close_reason(<<_Code:16, Reason/binary>>) -> Reason;
close_reason(_) -> <<"closed">>.

normalize(ok) -> {ok, nil};
normalize({error, Reason}) -> {error, inspect_reason(Reason)}.

inspect_reason(Reason) ->
    unicode:characters_to_binary(io_lib:format("~tp", [Reason])).
