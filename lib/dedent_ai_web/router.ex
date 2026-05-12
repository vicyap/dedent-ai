defmodule DedentAiWeb.Router do
  use DedentAiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DedentAiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DedentAiWeb do
    pipe_through :browser

    live "/", DedentLive, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", DedentAiWeb do
  #   pipe_through :api
  # end
end
