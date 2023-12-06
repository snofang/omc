defmodule Omc.Telegram.TelegramUtils do
  @callback_separator "-"
  @callback_params_separator "_"

  @spec markup_item(text :: binary(), callback_data :: binary()) :: map()
  def markup_item(text, callback_data) do
    %{text: text, callback_data: callback_data}
  end

  @spec encode_callback_data(callback :: binary(), params :: [binary()]) :: binary()
  def encode_callback_data(callback, params) do
    callback <>
      @callback_separator <>
      (params |> Enum.map(&encode_callback_data_param/1) |> Enum.join(@callback_params_separator))
  end

  @spec decode_callback_data(binary()) :: {callback :: binary(), args :: [binary()]}
  def decode_callback_data(callback_data) do
    case String.split(callback_data, Regex.compile!("(?<!\\\\)#{@callback_separator}")) do
      [callback | [params_encoded]] ->
        {callback,
         params_encoded
         |> String.split(Regex.compile!("(?<!\\\\)#{@callback_params_separator}"))
         |> Enum.map(&decode_callback_data_param/1)}

      [callback | []] ->
        {callback, []}
    end
  end

  def encode_callback_data_param(param) do
    param
    |> String.replace(
      Regex.compile!("(?<!\\\\)(#{@callback_params_separator}|#{@callback_separator})"),
      &("\\" <> &1)
    )
  end

  def decode_callback_data_param(encoded_param) do
    encoded_param
    |> String.replace(
      Regex.compile!("\\\\(#{@callback_params_separator}|#{@callback_separator})"),
      "\\1"
    )
  end

  @spec entities_markup(
          callback :: binary(),
          entities :: [any()],
          text_provider :: (any() -> binary()),
          params_provider :: (any() -> [binary()])
        ) :: [[binary()]]
  def entities_markup(callback, entities, text_provider, params_provider) do
    entities
    |> Enum.reduce([[]], fn entity, result ->
      case result |> List.first() do
        [] ->
          [
            [
              markup_item(
                text_provider.(entity),
                encode_callback_data(callback, params_provider.(entity))
              )
            ]
          ]

        [item | []] ->
          result
          |> List.replace_at(0, [
            markup_item(
              text_provider.(entity),
              encode_callback_data(callback, params_provider.(entity))
            )
            | [item]
          ])

        _ ->
          [
            [
              markup_item(
                text_provider.(entity),
                encode_callback_data(callback, params_provider.(entity))
              )
            ]
            | result
          ]
      end
    end)
  end

  def handle_callback(callback, args) do
    apply(
      String.to_existing_atom("Elixir.Omc.Telegram.Callback#{callback |> String.capitalize()}"),
      :handle,
      [args]
    )
  end
end
