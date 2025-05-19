# Dynamic Instrumentation

## Supported Functionality

- Capturing of values at method entry

## Unsupported Functionality

- Capturing of values at method exit

## Troubleshooting

Live Debugger and Dynamic Instrumentation UI uses data from several systems
and generally having any of them not functioning correctly (not emitting data
at all or not emitting exactly expected data) will produce either
confusing or outright broken UI.

LD/DI require:

1. The application to run in production environment (RAILS_ENV, RACK_ENV,
etc.). It is technically possible to utilize DI in development and test
environments but this is not officially supported.
1. Remote configuration to be turned on on the agent and on the tracer.
It's on by default. You also need a Datadog API key with the remote configuration
enabled, which recent keys all have.
1. Telemetry to be enabled. It's on by default.
1. Source Code Integration (SCI) environment variables to be set -
`DD_GIT_REPOSITORY_URL`, `DD_GIT_COMMIT_SHA`, `DD_VERSION`.
Without SCI the product still works but the UI becomes much less helpful
due to loss of autocomplete.
