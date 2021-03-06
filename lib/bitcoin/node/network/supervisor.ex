defmodule Bitcoin.Node.Network.Supervisor do
  use Supervisor

  require Lager

  def start_link do
    Supervisor.start_link(__MODULE__, name: __MODULE__)
  end

  def init(_) do
    Lager.info "Starting Node subsystems"
    modules = Bitcoin.Node.Network.modules()

    dynamic_modules =  [:addr, :discovery, :connection_manager] |> Enum.map(fn name -> modules[name] end)
    static_modules = [
      Bitcoin.Node.Storage,
      Bitcoin.Node.Inventory
    ]

    (static_modules ++ dynamic_modules)
    |> Enum.map(fn m -> worker(m, [%{modules: modules}]) end)
    |> supervise(strategy: :one_for_one)
  end

end
