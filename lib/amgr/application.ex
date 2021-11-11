defmodule Amgr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      AmgrWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Amgr.PubSub},
      # Start the Endpoint (http/https)
      AmgrWeb.Presence,
      AmgrWeb.Endpoint
      # Start a worker by calling: Amgr.Worker.start_link(arg)
      # {Amgr.Worker, arg}
    ]

    load_publications_into_memory()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Amgr.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AmgrWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp load_publications_into_memory() do
    :persistent_term.put(:publications, [
      %{
        year: 2021,
        list: [
          %{
            title: "Microservices vs APIs",
            domain: "lightrun.com",
            url: "https://lightrun.com/best-practices/microservices-vs-apis/"
          },
          %{
            title: "Building a Real-Time Application in the Phoenix Framework with Elixir",
            domain: "earthly.dev",
            url: "https://earthly.dev/blog/real-time-phoenix-elixir/"
          },
          %{
            title: "Podcast: Circuit Breaker and Elixir Patterns with Allan MacGregor",
            domain: "ThinkingElixir.com",
            url:
              "https://thinkingelixir.com/podcast-episodes/032-circuit-breaker-and-elixir-patterns-with-allan-macgregor"
          },
          %{
            title: "Dynamic Filters and Facets for Your Shopify Store",
            domain: "Sajari.com",
            url: "https://www.sajari.com/blog/shopify-filters-and-facets"
          },
          %{
            title: "Achieving Repeatability in Continuous Integration",
            domain: "earthly.dev",
            url: "https://earthly.dev/blog/achieving-repeatability/"
          },
          %{
            title: "How to Add a Dynamic Search Box and Filters for Your Shopify Store",
            domain: "Sajari.com",
            url: "https://www.sajari.com/blog/dynamic-search-and-filters"
          },
          %{
            title: "Building Custom Resolvers with Strapi",
            domain: "Strapi.io",
            url: "https://strapi.io/blog/building-custom-resolvers-with-strapi"
          },
          %{
            title: "How to Improve Shopify Conversion Rates with Better Search and Discovery",
            domain: "Sajari.com",
            url: "https://www.sajari.com/blog/improve-shopify-conversion"
          },
          %{
            title: "https://fingerprintjs.com/blog/fingerprintjs-prevent-bot-attacks/",
            domain: "fingerprintjs.com",
            url: "https://fingerprintjs.com/blog/fingerprintjs-prevent-bot-attacks/"
          }
        ]
      },
      %{
        year: 2020,
        list: [
          %{
            title: "Interview: My Journey With Elixir and Flow-Based Programming",
            domain: "Preslav.dev",
            url: "https://preslav.me/2020/12/10/elixir-community-voices-allan-macgregor/"
          },
          %{
            title: "Podcast: Is Vim Worth Your Time?",
            domain: "DevDiscuss",
            url: "https://dev.to/devdiscuss/s3-e3-is-vim-worth-your-time"
          }
        ]
      },
      %{
        year: 2019,
        list: [
          %{
            title: "Podcast: Interview with Allan MacGregor",
            domain: "Voices of the ElePHPant",
            url: "https://voicesoftheelephpant.com/2019/06/18/interview-with-allan-macgregor/"
          }
        ]
      },
      %{
        year: 2018,
        list: [
          %{
            title: "The Three Seats Of Engineering Leadership",
            domain: "Forbes.com",
            url:
              "https://www.forbes.com/sites/forbestechcouncil/2018/01/16/the-three-seats-of-engineering-leadership/"
          },
          %{
            title:
              "Podcast: Agency Hiring Strategy, Move from Demac to Browze, Cannabis Legalization",
            domain: "Commerce Hero",
            url: "https://www.youtube.com/watch?v=95MTAwGs0uI"
          }
        ]
      },
      %{
        year: 2017,
        list: [
          %{
            title: "How to Analyze Tweet Sentiments with PHP Machine Learning",
            domain: "Sitepoint.com",
            url:
              "https://www.sitepoint.com/how-to-analyze-tweet-sentiments-with-php-machine-learning/"
          },
          %{
            title: "The Future of Magento",
            domain: "Magenticians.com",
            url: "https://magenticians.com/allan-macgregor-interview/"
          }
        ]
      }
    ])
  end
end
