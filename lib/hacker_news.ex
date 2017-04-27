defmodule HackerNews do
  @moduledoc """
  Documentation for HackerNews.
  """

  def get_newest_page() do
    SlowScraper.request_page(:hn, "https://news.ycombinator.com/newest", 10_000)
      |> parse_news_page()
  end
  def get_front_page() do
    SlowScraper.request_page(:hn, "https://news.ycombinator.com/news", 10_000)
      |> parse_news_page()
  end

  defp parse_news_page(hn_page) do
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

  def client_spec do
    headers_from_config = ["Referer": "https://news.ycombinator.com/"]
    SlowScraper.client_spec(:hn, headers_from_config, HackerNews.HTTP)
  end
end

defmodule HackerNews.HTTP do
  def scrape(headers, url) do
    {:ok, response} = HTTPoison.get(url, headers, [])
    body = Map.get(response, :body)
    Floki.find(body, "#hnmain")
  end
end
