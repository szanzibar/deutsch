defmodule DeutschWeb.MainLive do
  @moduledoc false
  use DeutschWeb, :live_view

  @impl true
  def mount(_, _session, socket) do
    {:ok, socket |> assign(search: "", autocomplete: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="autocomplete" phx-submit="submit">
      <.input name="search" label="Search" value={@search} />
    </form>
    """
  end

  @impl true
  def handle_event("autocomplete", %{"search" => search}, socket) do
    autocomplete(search)
    {:noreply, socket}
  end

  defp autocomplete(search) do
    Req.get!("https://www.verben.de/suche/eingabe/?w=#{search}").body |> dbg
  end
end
