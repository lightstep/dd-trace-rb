# LS Trace Client

## ⛔️ Deprecation Warning ⛔️
Lightstep will be EOLing ls-trace tracers in the near future.
* All new users are recommended to use [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-ruby).
* For those currently using these tracers, we will be reaching out in Q3 2021 to ensure you have a smooth transition to OpenTelemetry. If for any reason you find a gap with OpenTelemetry for your use case, please reach out to your Customer Success representative to discuss and set up time with our Data Onboarding team.

[![CircleCI](https://circleci.com/gh/lightstep/ls-trace-rb/tree/master.svg?style=svg)](https://circleci.com/gh/lightstep/ls-trace-rb/tree/master)

Datadog has generously announced the [donation](https://www.datadoghq.com/blog/opentelemetry-instrumentation) of their tracer libraries to the [OpenTelemetry](https://opentelemetry.io/), project. Auto-instrumentation is a core feature of these libraries, making it possible to create and collect telemetry data without needing to change your code. LightStep wants you to be able to use these libraries now! `ls-trace` is LightStep's fork of Datadog’s tracing client for Ruby. You can install and use it to take advantage of auto-instrumentation without waiting for OpenTelemetry. Each LightStep agent is [“pinned” to a Datadog release](#versioning) and is fully supported by LightStep’s Customer Success team.

## Getting Started

### Install the Gem

```
gem install ls-trace
```

### Configure the tracing client to send data to LightStep

To send data from your system to LightStep, you need to configure the tracing client to:

* Point to your satellites
* Send global tags required by LightStep to ingest and display your data

#### Send data to your satellites

##### On-Premise satellites

Set the following environment variables to the host and port of your satellite:

```
DD_AGENT_HOST=<Satellite host>
DD_TRACE_AGENT_PORT=<Satellite port>
```

##### Public satellites

If you’re using Lightstep’s Public Satellites, you need to run a proxy that encrypts the trace payload before it reaches Lightstep. Point your tracer to the Proxy instead of the Satellites. The proxy can be run as a side-car to your application. Lightstep provides a docker image to make this simple.

To start the proxy with defaults, run:

```
docker run -p 8126:8126 lightstep/reverse-proxy:latest
```

You can see the complete list of options using the --help flag

```
docker run lightstep/reverse-proxy:latest --help
```

If you run the proxy on `localhost` and port 8126 no additional configuration is needed. If you are running on a different host or port you'll need to set the following enviroment variables:

```
DD_AGENT_HOST=<proxy host>
DD_TRACE_AGENT_PORT=<proxy port>
```

#### Configure global tags

LightStep requires two global tags, `lightstep.service_name` and `lightstep.access_token` to be set on spans for ingest.

| Tag | Description |
|-----|--------|
| lightstep.service_name | The name of the service from which spans originate. Set this as a global tag so all spans emitted from the service have the same name. This tag allows LightStep to accurately report on your services, with features such as the [Service diagram][ls-service-diagram] and the [Service Directory][ls-service-directory].
| lightstep.access_token | The [access token][ls-access-tokens] for the project to report to. LightStep Satellites need this token to accept and store span data from the tracer. Reports from clients with invalid or deactivated access tokens will be rejected on ingress.

You can configure global tags when configuring the Datadog tracer. See the example below:

```
Datadog.configure do |c|
  # setup integrations, etc...
  c.tracer tags: {
    'lightstep.service_name' => 'my-service-name',
    'lightstep.access_token' => 'my-token'
  }
end
```

## Additional Resources

For an overview of using the LightStep Datadog Ruby Tracing Client see the [ruby auto-instrumentation overview][auto-instrumentation overview].

For installation, configuration, and details about using the API, check out our [API documentation][api docs]

## Versioning

ls-trace follows its own versioning scheme. The table below shows the corresponding dd-trace-rb versions.

| ls-trace version | dd-trace-rb version |
|------------------|---------------------|
| v0.1.1           | v0.29.0             |
| v0.2.0           | v0.40.0             |

## Support

Contact `support@lightstep.com` for additional questions and resources, or to be added to our community slack channel.

## Licensing

This is a fork of [dd-trace-rb][dd-trace-rb repo] and retains the original Datadog license and copyright. See the [license][license file] for more details.

[ls-reverse-proxy]: https://github.com/lightstep/reverse-proxy
[ls-service-diagram]: https://docs.lightstep.com/docs/view-service-hierarchy-and-performance
[ls-service-directory]: https://docs.lightstep.com/docs/view-individual-service-performance
[ls-access-tokens]: https://docs.lightstep.com/docs/create-and-use-access-tokens
[auto-instrumentation overview]: https://docs.lightstep.com/docs/ruby-auto-instrumentation#section-configure-libraries
[api docs]: https://github.com/lightstep/dd-trace-rb/blob/master/docs/GettingStarted.md
[dd-trace-rb repo]: https://github.com/DataDog/dd-trace-rb
[license file]: https://github.com/lightstep/dd-trace-rb/blob/master/LICENSE
