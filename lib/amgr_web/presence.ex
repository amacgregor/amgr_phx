defmodule AmgrWeb.Presence do
  @moduledoc false

  use Phoenix.Presence,
    otp_app: :amgr,
    pubsub_server: Amgr.PubSub
end
