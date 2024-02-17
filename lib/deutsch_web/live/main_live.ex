defmodule DeutschWeb.MainLive do
  @moduledoc false
  use DeutschWeb, :live_view

  @impl true
  def mount(_, _session, socket) do
    {:ok, socket |> assign(search: "", options: [], results: %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="autocomplete" phx-submit="submit_form">
      <.input name="search" label="Search" value={@search} phx-debounce="500" />
    </form>

    <.list>
      <:item :for={option <- @options} title={option.title}>
        <.button phx-click="submit" phx-value-word={option.option}>
          <%= option.option %>
        </.button>
      </:item>
    </.list>

    <div>
      <div><%= @results[:word] %></div>
      <div><%= @results[:translation] %></div>
      <div><%= @results[:extra] %></div>
      <div><%= @results[:d_sentence] %></div>
      <div><%= @results[:e_sentence] %></div>
    </div>
    """
  end

  @impl true
  def handle_event("autocomplete", %{"search" => search}, socket) do
    {:noreply, socket |> assign(options: autocomplete(search))}
  end

  @impl true
  def handle_event("submit_form", _, socket) do
    option = socket.assigns.options |> Enum.at(0) |> Map.get(:option, socket.assigns.search)
    handle_event("submit", %{"word" => option}, socket)
  end

  @impl true
  def handle_event("submit", %{"word" => word}, socket) do
    dbg(word)
    body = Req.get!("https://www.verben.de/?w=#{URI.encode(word)}").body
    {:noreply, socket |> assign(search: "", options: [], results: parse_verben(body))}
  end

  defp autocomplete(search) do
    Req.get!("https://www.verben.de/suche/eingabe/?w=#{URI.encode(search)}",
      headers: [
        user_agent:
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
      ]
    ).body
    |> Enum.reject(&Enum.empty?/1)
    |> dbg
    |> Enum.map(fn [option, html] ->
      {:ok, document} = Floki.parse_document(html)
      title = document |> Floki.find("span") |> Floki.text()
      %{title: title, option: option}
    end)
  end

  def parse_verben(html) do
    {:ok, document} = Floki.parse_document(html)

    word =
      document
      |> Floki.find("p.rClear")
      |> List.first()
      |> Floki.text()
      |> trim
      |> IO.inspect()

    translation =
      document
      |> Floki.find("#wStckKrz > p:nth-last-child(2)")
      |> Floki.text()
      |> trim
      |> IO.inspect()

    extra =
      document
      |> Floki.find("#wStckKrz > p:nth-last-child(3)")
      |> Floki.traverse_and_update(fn
        {"i", [], [word]} -> {"i", [], ["#{word} "]}
        result -> IO.inspect(result)
      end)
      |> Floki.text()
      |> trim
      |> IO.inspect()

    sentence =
      document
      |> Floki.find("section:nth-last-child(1) > div > ul > li")
      |> Enum.filter(fn element -> Floki.find(element, "li >  span ") != [] end)
      |> IO.inspect()
      |> List.last()

    deutsch_sentence =
      Floki.filter_out(sentence, "li > span") |> Floki.text() |> trim |> IO.inspect()

    english_sentence =
      Floki.find(sentence, "li > span") |> Floki.text() |> trim |> IO.inspect()

    %{
      word: word,
      translation: translation,
      extra: extra,
      e_sentence: english_sentence,
      d_sentence: deutsch_sentence
    }
  end

  defp trim(string) do
    string |> String.trim()
  end
end
