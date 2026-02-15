defmodule ShowcagoServicesWeb.PageController do
  use ShowcagoServicesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
