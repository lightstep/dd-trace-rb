# LS Trace Client

[![CircleCI](https://circleci.com/gh/lightstep/ls-trace-rb/tree/master.svg?style=svg)](https://circleci.com/gh/lightstep/ls-trace-rb/tree/master)

Datadog has generously announced the [donation](https://www.datadoghq.com/blog/opentelemetry-instrumentation) of their tracer libraries to the [OpenTelemety](https://opentelemetry.io/), project. Auto-instrumentation is a core feature of these libraries, making it possible to create and collect telemetry data without needing to change your code. LightStep wants you to be able to use these libraries now! `ls-trace` is LightStep's fork of Datadog’s tracing client for Ruby. You can install and use it to take advantage of auto-instrumentation without waiting for OpenTelemetry. Each LightStep agent is [“pinned” to a Datadog release](#versioning) and is fully supported by LightStep’s Customer Success team.

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

If your on-premise satellites accept data over plain HTTP, follow the instructions below. If they require HTTPS you will have to use the [LightStep reverse proxy][ls-reverse-proxy]. See the instructions for [public satellites](#public-satellites) for more details.

Set the following environment variables to the host and port of your satellite:

```
DD_AGENT_HOST=<Satellite host>
DD_TRACE_AGENT_PORT=<Satellite port>
```

##### Public satellites

LightStep's public satellites require data to be transmitted using HTTPS. Since Datadog's Ruby client transmits data over plain HTTP, you will have use the [LightStep reverse proxy][ls-reverse-proxy]. The reverse proxy will accept data over plain HTTP and forward it to the public satellites using HTTPS. By default the reverse proxy will forward requests to `ingest.lightstep.com`, but can be configured by passing additional options. See below for details.

To start the reverse proxy with defaults run:

```
docker run -p 8126:8126 lightstep/reverse-proxy:latest
```

You can see the complete list of options using the --help flag

```
docker run lightstep/reverse-proxy:latest --help
```

If you run the reverse proxy on `localhost` and port 8126 no additional configuration is needed. If you are running on a different host or port you'll need to set the following enviroment variables:

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
