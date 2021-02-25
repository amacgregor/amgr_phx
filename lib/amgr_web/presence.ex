defmodule AmgrWeb.Presence do
  use Phoenix.Presence,
    otp_app: :amgr,
    pubsub_server: Amgr.PubSub
end
