defmodule TradingSwarm.System.SystemConfiguration do
  @moduledoc """
  Schema for system configuration key-value storage.

  Stores configurable system parameters that can be modified at runtime
  without code deployments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "system_configurations" do
    field :key, :string
    field :value, :string
    field :description, :string
    field :category, :string, default: "general"
    field :encrypted, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @category_values ~w(general trading risk_management api market_data notifications)
  @required_fields ~w(key value)a
  @optional_fields ~w(description category encrypted)a

  @doc false
  def changeset(system_configuration, attrs) do
    system_configuration
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:key, min: 1, max: 255)
    |> validate_length(:value, min: 1)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:category, @category_values)
    |> unique_constraint(:key)
  end

  @doc """
  Gets a configuration value by key, with optional default.
  """
  def get_value(%__MODULE__{value: value, encrypted: false}), do: value

  def get_value(%__MODULE__{value: encrypted_value, encrypted: true}) do
    # Decrypt encrypted configuration values
    # For now, returning raw value - implement proper encryption/decryption in production
    encrypted_value
  end

  @doc """
  Returns true if the configuration is encrypted.
  """
  def encrypted?(%__MODULE__{encrypted: encrypted}), do: encrypted

  @doc """
  Returns configurations grouped by category.
  """
  def by_category(configs) when is_list(configs) do
    Enum.group_by(configs, & &1.category)
  end
end
