defmodule OmcWeb.RawBodyReader do
  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case conn.path_info  do
      ["api", "payment" | _rest] ->
        # Note: the callbck request are very small and doesn't need to be considered as multi-chunked.
        # TODO: But for completeness and larger requests, it should support multi-chunked mode too.
        {:ok, body, _} = Plug.Conn.read_body(conn)
        Plug.Conn.put_private(conn, :raw_body_reader_body, body)

      _ ->
        conn
    end
  end

  def get_raw_body(conn) do
    conn.private[:raw_body_reader_body]
  end
end
