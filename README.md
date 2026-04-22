# MiniSymphony

A pretty bare-bones implementation of a coding harness, inspired in part by openai's [symphony](https://github.com/openai/symphony) harness. 

The system leverages the OTP framework with Elixir to manage the orchestration of coding agents to accomplish "issues" with a pretty minimal combo of a `GenServer` and monitored elixir `Task` processes.

It is designed to work with ollama and open source models

Issues could be pulled from anywhere, but are currently being fed from a fixed yaml file that will need manual intervention to move to "done" and thus no longer be polled for by the service.

This was built out of a general interest in what it would take to build a small scale elixir harness system, to which the answer is generally, not heaps.


## Installation

1. Ensure you have Elixir + Erlang installed
2. Ensure you have ollama installed
3. Run `ollama pull qwen2.5-coder:7b` or your model of choice if you configure it in `config.ex`
4. Clone the repo
5. Run `mix deps.get`
6. Run `mix run --no-halt`


## The system

There are 3 main components:

1. The IssueSource module
2. The Orchestrator - a GenServer responsible for managing the harness lifecycle and workflow
3. The AgentRunner module - responsible for actually doing the agentic work


Issues are served from a static yaml file and must be manually updated to "done" to no longer include them, but the behaviour could accomodate other issue sources eg JIRA

The system fetches all issues in an actionable state, then dispatches tasks equivalent to the concurrent agents limit to work as independent agents.

These agents operate in their own isolated workspaces. Each agent "should" only be able to write files within their own isolated workspace (Isolation not backed by a money back guarantee).

There are a limited # of tools available to the agent, the `Shell` tool, the `FileRead` tool, and the `FileWrite` tool. These can be extended and added to, provided each tool specifies its own `tool_definition` and are added to the tool registry in the agent runner. These could probably be made to be more dynamic so adding them is a bit easier

Generally speaking - rather than erroring out, I want to enable the LLM to determine the next best step, and as such I tend to prefer returning `{:ok, error_content}` and save the error scenarios for places where I want the system to actually blow up.

### AgentRunner

When dispatched, the AgentRunner will attempt to resolve an issue up to a configured maximum number of turns in a loop.

With an admittedly pretty bare bones system prompt, it will take the following steps towards resolution assuming max turns hasnt been exceeded:

1. Issue the request with the prompt + tools to the LLM
2. If there are tool calls in the response - either implicitly (thanks LLMs, lol) or explicitly - go ahead and execute the tool call
3. Otherwise determine current issue state
4. If not done - append a continuation message for context and run again
5. If done - report agent as done


### Orchestrator

Whilst agents are independent and share no state, we need an orchestration process to hold state over the entire workflows and enable things like:

- polling
- reconiliation (is this issue done - can we drop the agent?)
- retrying
- fetching and dispatching work

We keep track of configuration, which issues are currently running, which have been claimed, and the count of retries for a given issue id as state. 

When polling we generate a token and use this to control calls to dispatch/reconcile on a timer. In the case of stale tokens (owing to crashing processes or the fire and forget nature of `Process.send_after/3`) we simply no-op.

On each tick though - we see if we need to:

- reconcile our state with the issues state
- fetch any candidates for processing 
- if they're not already claimed or running -> spawn a new agent to process them


If an agent crashes out - and its deemed to be abnormal, we run a retry with an exponential backoff

The orchestrator gives us a single point of authority for what work should happen and when.





