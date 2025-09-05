defmodule TradingSwarm.Pagination do
  @moduledoc """
  Simple pagination utilities for query results.
  """

  import Ecto.Query
  alias TradingSwarm.Repo

  @default_page_size 20
  @max_page_size 200

  defstruct entries: [],
            page_number: 1,
            page_size: 20,
            total_entries: 0,
            total_pages: 1

  @doc """
  Paginates a query and returns a pagination struct with results.
  """
  def paginate(query, opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> ensure_positive_integer()
    page_size = Keyword.get(opts, :page_size, @default_page_size) |> ensure_valid_page_size()

    # Get total count
    total_entries =
      query |> exclude(:order_by) |> exclude(:preload) |> Repo.aggregate(:count, :id)

    # Calculate pagination values
    total_pages = calculate_total_pages(total_entries, page_size)
    offset = (page - 1) * page_size

    # Get entries for current page
    entries =
      query
      |> limit(^page_size)
      |> offset(^offset)
      |> Repo.all()

    %__MODULE__{
      entries: entries,
      page_number: page,
      page_size: page_size,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  @doc """
  Returns true if there is a next page.
  """
  def has_next_page?(%__MODULE__{page_number: page, total_pages: total}) do
    page < total
  end

  @doc """
  Returns true if there is a previous page.
  """
  def has_previous_page?(%__MODULE__{page_number: page}) do
    page > 1
  end

  @doc """
  Returns the next page number if available.
  """
  def next_page(%__MODULE__{page_number: page, total_pages: total}) do
    if page < total, do: page + 1, else: nil
  end

  @doc """
  Returns the previous page number if available.
  """
  def previous_page(%__MODULE__{page_number: page}) do
    if page > 1, do: page - 1, else: nil
  end

  # Private functions

  defp ensure_positive_integer(value) when is_integer(value) and value > 0, do: value
  defp ensure_positive_integer(_), do: 1

  defp ensure_valid_page_size(size) when is_integer(size) and size > 0 do
    min(size, @max_page_size)
  end

  defp ensure_valid_page_size(_), do: @default_page_size

  defp calculate_total_pages(total_entries, page_size) when total_entries > 0 do
    (total_entries / page_size) |> Float.ceil() |> round()
  end

  defp calculate_total_pages(_, _), do: 1
end
