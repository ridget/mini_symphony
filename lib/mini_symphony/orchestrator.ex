defmodule MiniSymphony.Orchestrator do
  use GenServer
  require Logger

  alias MiniSymphony.AgentRunner

  defstruct config: nil,
            # issue_id => %{pid: pid, ref: ref, issue: issue}
            running: %{},
            # issue_ids we own (running + retrying)
            claimed: MapSet.new(),
            tick_token: nil

  def start_link(opts) do
    config = Keyword.fetch!(opts, :config)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    config = %{config | fetch_issue_fn: config.fetch_issue_fn || default_fetch_fn(config)}
    Logger.info("Orchestrator starting, polling #{config.issues_file}")

    {:ok, %__MODULE__{config: config}, {:continue, :first_tick}}
  end

  @impl true
  def handle_continue(:first_tick, state) do
    {:noreply, do_tick(state)}
  end

  @impl true
  def handle_info({:tick, token}, %{tick_token: token} = state) do
    Logger.info(state)
    Logger.info("Tick: #{map_size(state.running)} running")
    {:noreply, do_tick(state)}
  end

  def handle_info({:tick, _old_token}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    entry = Enum.find(state.running, fn {_id, e} -> e.ref == ref end)

    case entry do
      {issue_id, _data} ->
        Logger.info("Agent #{issue_id} terminated with reason: #{inspect(reason)}")

        {:noreply,
         %{
           state
           | running: Map.delete(state.running, issue_id),
             claimed: MapSet.delete(state.claimed, issue_id)
         }}

      nil ->
        {:noreply, state}
    end
  end

  defp do_tick(state) do
    state = dispatch(state)

    token = make_ref()
    Process.send_after(self(), {:tick, token}, state.config.poll_interval_ms)

    %{state | tick_token: token}
  end

  defp dispatch(state) do
    case MiniSymphony.IssueSource.Yaml.fetch_candidates(state.config.issues_file) do
      {:error, reason} ->
        Logger.warning("Failed to fetch issues: #{inspect(reason)}")
        state

      candidates ->
        state =
          candidates
          |> Enum.sort_by(& &1.priority)
          |> Enum.reduce(state, fn issue, acc -> maybe_dispatch_issue(acc, issue) end)

        state
    end
  end

  defp maybe_dispatch_issue(state, issue) do
    cond do
      MapSet.member?(state.claimed, issue.id) -> state
      map_size(state.running) >= state.config.max_concurrent_agents -> state
      true -> spawn_agent(state, issue)
    end
  end

  defp spawn_agent(state, issue) do
    case Task.Supervisor.start_child(MiniSymphony.TaskSupervisor, fn ->
           AgentRunner.run(issue, state.config)
         end) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        new_entry = %{id: issue.id, pid: pid, ref: ref, issue: issue}

        %{
          state
          | running: Map.put(state.running, issue.id, new_entry),
            claimed: MapSet.put(state.claimed, issue.id)
        }

      {:error, reason} ->
        Logger.error("Failed to start agent for #{issue.id}: #{inspect(reason)}")
        state
    end
  end

  defp default_fetch_fn(config) do
    fn id ->
      MiniSymphony.IssueSource.Yaml.fetch_by_id(config.issues_file, id)
    end
  end
end
