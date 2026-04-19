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

  @impl true
  def handle_info({:tick, _old_token}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {issue_id, %{issue: issue}} =
      Enum.find(state.running, fn {_id, entry} -> entry.ref == ref end)

    new_running = Map.delete(state.running, issue_id)
    new_state = %{state | running: new_running}

    case reason do
      :normal ->
        Logger.info("Agent #{issue_id} finished normally. Releasing claim.")
        {:noreply, %{new_state | claimed: MapSet.delete(state.claimed, issue_id)}}

      abnormal_reason ->
        Logger.error(
          "Agent #{issue_id} exited abnormally: #{inspect(abnormal_reason)}. Scheduling retry."
        )

        current_attempt = get_in(state.retry_attempts, [issue_id, :attempt_number]) || 0

        {:noreply, schedule_retry(new_state, issue_id, issue, current_attempt + 1)}
    end
  end

  @impl true
  def handle_info({:retry, issue_id, token}, state) do
    case Map.get(state.retry_attempts, issue_id) do
      %{token: ^token} ->
        handle_validated_retry(issue_id, state)

      _ ->
        Logger.debug("Stale retry detected for #{issue_id}, ignoring.")
        {:noreply, state}
    end
  end

  defp schedule_retry(state, issue_id, issue, attempt_number) do
    # 5 -> 10 -> 20 -> 40 -> 60s (capped) exponential backoff
    delay = min(5_000 * Integer.pow(2, attempt_number - 1), 60_000)

    token = make_ref()

    timer = Process.send_after(self(), {:retry, issue_id, token}, delay)

    Logger.info("Retrying #{issue_id} - attempt: #{attempt_number} in #{delay}")

    %{
      state
      | retry_attempts: %{
          issue_id => %{
            attempt_number: attempt_number,
            timer: timer,
            token: token,
            issue: issue
          }
        }
    }
  end

  defp handle_validated_retry(issue_id, state) do
    case MiniSymphony.IssueSource.Yaml.fetch_by_id(state.config.issues_file, issue_id) do
      {:ok, %{state: current_state} = fresh_issue} ->
        if MiniSymphony.Issue.active?(current_state) do
          Logger.info("Retry validated for #{issue_id}. Dispatching agent.")

          new_state = %{state | retry_attempts: Map.delete(state.retry_attempts, issue_id)}
          maybe_dispatch_issue(new_state, fresh_issue)
        else
          Logger.info(
            "Task #{issue_id} moved to terminal state (#{current_state}) during backoff. Releasing."
          )

          {:noreply,
           %{
             state
             | retry_attempts: Map.delete(state.retry_attempts, issue_id),
               claimed: MapSet.delete(state.claimed, issue_id)
           }}
        end

      {:error, _reason} ->
        {:noreply,
         %{
           state
           | retry_attempts: Map.delete(state.retry_attempts, issue_id),
             claimed: MapSet.delete(state.claimed, issue_id)
         }}
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
