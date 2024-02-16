import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :deutsch, DeutschWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "tuH1dchUSwQ9nfLBKBL08ShxH1f6MHFLObDo5x8p16o8X7T+ztPHvtPdxbOPUt9n",
  server: false

# In test we don't send emails.
config :deutsch, Deutsch.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
