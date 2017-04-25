defmodule HackerNews.Application do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: KVServer.Worker.start_link(arg1, arg2, arg3)
      # worker(KVServer.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]

    headers_from_config = ["Referer": "https://news.ycombinator.com/"]
    Bacon.Scrape.add_client(:hn, headers_from_config, HackerNews.HTTP)
    Logger.info("Bacon scrape client added")
    Supervisor.start_link(children, opts)
  end
end

defmodule HackerNews do
  @moduledoc """
  Documentation for HackerNews.
  """

  def get_main_page() do
    hn_page = Bacon.Scrape.request_page(:hn, "https://news.ycombinator.com/newest")
    Floki.find(hn_page, ".athing")
      |> Enum.map(fn news_item ->
        link = Floki.find(news_item, ".storylink")
        title = Floki.text(link)
        href = Floki.attribute(link, "href") |> List.first()
        %{
          title: title,
          url: href,
          service: "hackernews",
          author: "hackernews",
        }
      end)
  end
end

defmodule HackerNews.Client do
  use GenServer
  defstruct [
    key: nil,
    bot: nil,
    repo_id: nil,
  ]

  def supervisor_spec(key, client_id, bot) do
    import Supervisor.Spec
    worker(__MODULE__, [key, bot, client_id], restart: :permanent)
  end

  defp name(key), do: {:n, :l, {__MODULE__, key}}

  def start_link(key, bot, client_id) do
    name = {:via, :gproc, name(key)}
    GenServer.start_link(__MODULE__, {key, bot, client_id}, name: name)
  end

  def init({key, bot, client_id}) do
    state = %__MODULE__{
      key: key,
      bot: bot,
      repo_id: client_id,
    }
    GenServer.cast(self(), {:request_news})
    {:ok, state}
  end

  def fully_load(pid, entry) do
    GenServer.call(pid, {:fully_load, entry})
  end

  def subscribed_to(_pid, _continuation) do
    # source.url, source.name, source.service
     {:ok, [
       %{
         url: "https://news.ycombinator.com/",
         name: "Hacker News",
         service: "hackernews"
       }
       ]}
  end

  def subscribe_to!(_pid, _url) do
    :already_subscribed
  end

  def handle_call({:fully_load, entry}, _from, state) do
    {:reply, entry, state}
  end

  def handle_cast({:request_news}, state) do
    entries = HackerNews.get_main_page()
    bpid = state.bot.whereis(state.key)
    Enum.each(entries, fn entry ->
      state.bot.review_entry!(bpid, __MODULE__, entry)
    end)
    Process.send_after(self(), {:request_news}, 5000)
    {:noreply, state}
  end

  def handle_info({:request_news}, state) do
    GenServer.cast(self(), {:request_news})
    {:noreply, state}
  end

end

defmodule HackerNews.HTTP do
  def scrape(headers, url) do
    {:ok, response} = HTTPoison.get(url, headers, [])
    body = Map.get(response, :body)
    Floki.find(body, "#hnmain")
  end
end
