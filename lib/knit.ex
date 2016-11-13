defmodule Knit do
  @moduledoc """
  Handles populating models.
  """

  def populate(module, params) do
    if !function_exported?(module, :schema, 0) do
      raise "#{module} does not implement Knit.Model!"
    end

    schema = module.schema

    populated_map =
      module
      |> struct
      |> ExConstructor.populate_struct(params)
      # Can't enumerate otherwise
      |> Map.from_struct
      |> Enum.map(&(convert(schema, &1)))
      |> Enum.into(%{})

    # Re-convert to struct
    struct(module, populated_map)
  end

  defp convert(schema, {field, value}) do
    # Get the data about the field from the schema.
    type = schema[field]

    new_value =
      case type do
        [type] ->
          convert_list_collection(type, value)
        {type} ->
          convert_list_collection(type, value)
          |> Enum.into({})
        %{map: type} ->
          convert_map_collection(type, value)
        type ->
          convert_field(type, value)
      end

    {field, new_value}
  end

  # Convert a list-type collection (list or tuple)
  defp convert_list_collection(type, values) do
    # Handle the collection being in a map.
    # TODO: Make sure this is ordered by key.
    values_list = if is_map(values), do: Map.values(values), else: values
    Enum.map(values_list, &(convert_field(type, &1)))
  end

  # If the collection is a map with string keys and model values.
  defp convert_map_collection(type, values) do
    Enum.map(values, fn {key, value} ->
      {key, convert_field(type, value)}
    end)
    |> Enum.into(%{})
  end

  defp convert_field(type, value) do
    if function_exported?(type, :schema, 0) do
      # If the type is a model, populate the child struct.
      populate(type, value)
    else
      convert_value(type, value)
    end
  end

  defp convert_value(_, nil), do: nil
  defp convert_value(:string, value), do: convert_string(value)
  defp convert_value(:integer, value), do: convert_integer(value)
  defp convert_value(:float, value), do: convert_float(value)
  defp convert_value(:any, value), do: value

  defp convert_string(value) when is_binary(value), do: value
  defp convert_string(value), do: inspect(value)

  defp convert_integer(value) when is_integer(value), do: value
  defp convert_integer(value) when is_float(value), do: round(value)
  defp convert_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp convert_float(value) when is_float(value), do: value
  defp convert_float(value) when is_integer(value), do: value / 1
  defp convert_float(value) when is_binary(value) do
    case Float.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end
end
