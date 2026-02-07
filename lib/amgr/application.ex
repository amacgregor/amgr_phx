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
        year: 2025,
        list: [
          %{
            title: "Top Test Automation Frameworks in 2025",
            domain: "saucelabs.com",
            url: "https://saucelabs.com/resources/blog/top-test-automation-frameworks-in-2023"
          },
          %{
            title: "Risk in Fintech: The Hidden Engineering Challenge",
            domain: "linkedin.com",
            url:
              "https://www.linkedin.com/pulse/risk-fintech-hidden-engineering-challenge-allan-macgregor-b2ahc"
          }
        ]
      },
      %{
        year: 2024,
        list: [
          %{
            title: "Elixir for Fintech: Why It's the Best Choice for Modern Financial Apps",
            domain: "allanmacgregor.com",
            url:
              "https://allanmacgregor.com/posts/from_transactions_to_trust_why_elixir_is_the_future_of_fintech"
          },
          %{
            title: "Powerful Caching in Elixir with Cachex",
            domain: "appsignal.com",
            url:
              "https://blog.appsignal.com/2024/03/05/powerful-caching-in-elixir-with-cachex.html"
          },
          %{
            title: "Using Dependency Injection in Elixir",
            domain: "appsignal.com",
            url: "https://blog.appsignal.com/2024/05/21/using-dependency-injection-in-elixir.html"
          },
          %{
            title: "Advanced Dependency Injection in Elixir with Rewire",
            domain: "appsignal.com",
            url:
              "https://blog.appsignal.com/2024/06/11/advanced-dependency-injection-in-elixir-with-rewire.html"
          }
        ]
      },
      %{
        year: 2023,
        list: [
          %{
            title: "How to Build an In-house On-call Training Program",
            domain: "fiberplane.com",
            url: "https://fiberplane.com/blog/how-to-build-an-in-house-on-call-training-program"
          },
          %{
            title: "The Top Test Automation Frameworks in 2023",
            domain: "saucelabs.com",
            url: "https://saucelabs.com/resources/blog/top-test-automation-frameworks-in-2023"
          },
          %{
            title: "Real-Time Alerts: The Killer Use Case for Event-Driven Architecture",
            domain: "iexcloud.io",
            url:
              "https://iexcloud.io/blog/unlocking-real-time-alerts-in-distributed-systems-the-killer-use-case-for-event-driven-architecture"
          },
          %{
            title: "Guide to Scraping E-commerce Websites",
            domain: "brightdata.com",
            url: "https://brightdata.com/blog/how-tos/ecommerce-web-scraping-guide"
          }
        ]
      },
      %{
        year: 2022,
        list: [
          %{
            title: "Scheduling Your GitHub Actions Cron Style",
            domain: "airplane.dev",
            url: "https://www.airplane.dev/blog/scheduling-your-github-actions-cron-style"
          },
          %{
            title: "Measuring Typescript Code Coverage with Jest and GitHub Actions",
            domain: "codecov.io",
            url:
              "https://about.codecov.io/blog/measuring-typescript-code-coverage-with-jest-and-github-actions/"
          },
          %{
            title: "How to Build a Hosted Checkout Page/Checkout Toolkit (Embedded) Combo",
            domain: "rapyd.net",
            url:
              "https://community.rapyd.net/t/how-to-build-a-hosted-checkout-page-and-embed-a-checkout-toolkit/1699"
          },
          %{
            title: "What Is PCI Compliance?",
            domain: "goteleport.com",
            url: "https://goteleport.com/blog/what-is-pci/"
          },
          %{
            title: "Web Scraping with Elixir",
            domain: "scrapingbee.com",
            url: "https://www.scrapingbee.com/blog/web-scraping-elixir/"
          },
          %{
            title: "How to Take Website Screenshots With Elixir",
            domain: "urlbox.io",
            url: "https://www.urlbox.io/how-to-take-website-screenshots-elixir"
          },
          %{
            title: "Test Credit and Debit Card Numbers for Every Payment API",
            domain: "rapyd.net",
            url:
              "https://community.rapyd.net/t/test-credit-and-debit-card-numbers-for-every-payment-api/10458"
          },
          %{
            title: "How to Handle Rapyd Payouts with FX",
            domain: "rapyd.net",
            url: "https://community.rapyd.net/t/how-to-handle-rapyd-payouts-with-fx/52601"
          },
          %{
            title: "Benchmark Your Elixir App's Performance with Benchee",
            domain: "appsignal.com",
            url:
              "https://blog.appsignal.com/2022/09/06/benchmark-your-elixir-apps-performance-with-benchee"
          },
          %{
            title: "Running Background Jobs with the Laravel Scheduler",
            domain: "airplane.dev",
            url: "https://www.airplane.dev/blog/how-to-schedule-jobs-with-laravel-scheduler"
          }
        ]
      },
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
            title: "How to Use FingerprintJS to Prevent Bot Attacks",
            domain: "fingerprintjs.com",
            url: "https://fingerprintjs.com/blog/fingerprintjs-prevent-bot-attacks/"
          },
          %{
            title: "The Complete Guide to Docker Secrete",
            domain: "earthly.dev",
            url: "https://earthly.dev/blog/docker-secrets/"
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
