defmodule HackerNewsTest do
  use ExUnit.Case
  doctest HackerNews
  alias HackerNews, as: HN

  defmodule FakeSupervisor do
    use Supervisor

    def start_link do
      Supervisor.start_link(__MODULE__, {})
    end
    def init({}) do
      supervise([], strategy: :one_for_one)
    end
  end
  test "basic request" do
    {:ok, sup_pid} = FakeSupervisor.start_link()
    Supervisor.start_child(sup_pid, HackerNews.client_spec())
    results = HN.get_newest_page()
    assert length(results) > 0
  end
end
