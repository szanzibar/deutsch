defmodule DeutschWeb.MainLive do
  @moduledoc false
  use DeutschWeb, :live_view

  @headers [
    user_agent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
  ]

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
      <div><%= @results[:verb_case] %></div>
      <div><%= @results[:extra] %></div>
      <div><%= @results[:translation] %></div>
      <div><%= @results[:d_sentence] %></div>
      <div><%= @results[:e_sentence] %></div>
    </div>

    <.button :if={@results[:word]} phx-click="make_anki_card">Make anki card</.button>
    """
  end

  @impl true
  def handle_event("make_anki_card", _, socket) do
    deck_name = "every day German"
    model_name = "Basic (and reversed card)"
    results = socket.assigns.results

    line2 =
      if results[:verb_case] == "",
        do: results[:extra],
        else: "#{results[:verb_case]}</p><p>#{results[:extra]}"

    front = "<p>#{results[:word]}</p><p>#{line2}</p><p>#{results[:d_sentence]}</p>"
    back = "<p>#{results[:translation]}</p><p>#{results[:e_sentence]}</p>"

    request = %{
      "action" => "addNote",
      "version" => 6,
      "params" => %{
        "note" => %{
          "deckName" => deck_name,
          "modelName" => model_name,
          "fields" => %{
            "Front" => front,
            "Back" => back
          },
          "options" => %{
            "allowDuplicate" => false,
            "duplicateScope" => "deck",
            "duplicateScopeOptions" => %{
              "deckName" => deck_name,
              "checkChildren" => false,
              "checkAllModels" => false
            }
          },
          "tags" => [
            "auto-added"
          ]
        }
      }
    }

    socket =
      Req.post!("http://localhost:8765", json: request)
      |> case do
        %{body: %{"error" => error}} when not is_nil(error) -> socket |> put_flash(:error, error)
        _ -> socket |> put_flash(:info, "Card added")
      end

    Req.post!("http://localhost:8765", json: %{"action" => "sync", "version" => 6})

    {:noreply, socket}
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
    body = Req.get!("https://www.verben.de/?w=#{URI.encode(word)}", headers: @headers).body
    {:noreply, socket |> assign(search: "", options: [], results: parse_verben(body))}
  end

  defp autocomplete(search) do
    Req.get!("https://www.verben.de/suche/eingabe/?w=#{URI.encode(search)}", headers: @headers).body
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
      |> Floki.find("#wStckKrz > p > span[lang='en']")
      |> Floki.text()
      |> trim
      |> IO.inspect()

    extra =
      document
      |> Floki.find("#wStckKrz > p")
      |> Enum.find(fn element -> Floki.find(element, "q") != [] end)
      |> Floki.traverse_and_update(fn
        {"i", [], [word]} -> {"i", [], ["#{word} "]}
        result -> IO.inspect(result)
      end)
      |> Floki.text()
      |> trim
      |> IO.inspect()

    verb_case =
      document
      |> Floki.find("#wStckKrz > p")
      |> Enum.find(fn element -> Floki.find(element, "span[title]") != [] end)
      |> Floki.text()
      |> trim
      |> IO.inspect()

    sentences =
      document
      |> Floki.find("section:nth-last-child(1) > div > ul > li")

    {d_sentence, e_sentence} =
      sentences
      |> Enum.filter(fn element -> Floki.find(element, "li >  span ") != [] end)
      |> case do
        [] when sentences == [] ->
          # No sentence found at all
          {"", ""}

        [] ->
          # No english sentence
          {sentences |> Enum.random() |> Floki.text() |> trim, ""}

        filtered_sentences ->
          sentence = filtered_sentences |> Enum.random()

          deutsch_sentence =
            Floki.filter_out(sentence, "li > span") |> Floki.text() |> trim

          english_sentence =
            Floki.find(sentence, "li > span") |> Floki.text() |> trim

          {deutsch_sentence, english_sentence}
      end

    results = %{
      word: word,
      extra: extra,
      verb_case: verb_case,
      translation: translation,
      d_sentence: d_sentence,
      e_sentence: e_sentence
    }

    if d_sentence == "" || e_sentence == "" do
      {d_sentence, e_sentence} = find_sentence(results)

      if d_sentence != "" && e_sentence != "" do
        %{results | d_sentence: d_sentence, e_sentence: e_sentence}
      else
        results
      end
    else
      results
    end
  end

  defp trim(string) do
    string |> String.trim()
  end

  defp find_sentence(results) do
    word = results[:word] |> String.split(",") |> List.first()
    extra_forms = results[:extra] |> String.split("·", trim: true)

    all_forms =
      [word | extra_forms]
      |> Enum.map(fn word ->
        word
        |> String.replace(["(", ")"], "")
        |> String.trim()
      end)
      |> Enum.join("\\W|")
      |> IO.inspect()

    {:ok, sentences} = File.read("sentence_pairs_german_english.tsv")

    sentences
    |> String.split("\n")
    |> Enum.map(fn line -> String.split(line, "\t") end)
    |> Enum.filter(fn [d, _e] ->
      String.match?(d, ~r/#{all_forms}/)
    end)
    |> case do
      [] ->
        {"", ""}

      list ->
        [d, e] = Enum.random(list)
        {d, e}
    end
  end
end
