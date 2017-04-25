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
    hn_page = Bacon.Scrape.request_page(:hn, "https://news.ycombinator.com/newest", 10*1000)
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
          source: "https://news.ycombinator.com/",
        }
      end)
  end
end

defmodule HackerNews.HTTP do
  def scrape(headers, url) do
    {:ok, response} = HTTPoison.get(url, headers, [])
    body = Map.get(response, :body)
    Floki.find(body, "#hnmain")
  end
end
