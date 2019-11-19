# LightStep Datadog Trace Client

[![CircleCI](https://circleci.com/gh/lightstep/dd-trace-rb/tree/master.svg?style=svg)](https://circleci.com/gh/lightstep/dd-trace-rb/tree/master)

`lightstep-ddtrace-rb` is LightStep's fork of Datadog’s tracing client for Ruby. It is used to trace requests as they flow across web servers,
databases and microservices so that developers have great visiblity into bottlenecks and troublesome requests.

## Configure the tracing client to send data to LightStep

To send data from your system to LightStep, you need to configure the agent to: 

* Point to your satellites
* Send global tags required by LightStep to ingest and display your data

### Send data to your satellites

#### On-Premise satellites

If your on-premise satellites accept data over plain HTTP, follow the instructions below. If they require HTTPS you will have to use the [LightStep reverse proxy](https://github.com/lightstep/reverse-proxy). See the instructions for [public satellites](#public-satellites).

Set the following environment variables to the host and port of your satellite

```
DD_AGENT_HOST=<Satellite host>
DD_TRACE_AGENT_PORT=<Satellite port>
```

#### Public satellites

LightStep's public satellites require data to be transmitted using HTTPS. Since Datadog's Ruby client transmits data over plain HTTP you will have use the [LightStep reverse proxy](https://github.com/lightstep/reverse-proxy), which will accept data over plain HTTP and forward it the public satellites using HTTPS. By default the reverse proxy will forward requests to `ingest.lightstep.com`, but can be configured by passing additional options. See below for details.

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
| lightstep.service_name | The name of the service from which spans originate. Set this as a global tag so all spans emitted from the service have the same name. This tag allows LightStep to accurately report on your services, with features such as the [Service diagram](https://docs.lightstep.com/docs/view-service-hierarchy-and-performance) and the [Service Directory](https://docs.lightstep.com/docs/view-individual-service-performance).
| lightstep.access_token | The [access token](https://docs.lightstep.com/docs/create-and-use-access-tokens) for the project to report to. LightStep Satellites need this token to accept and store span data from the tracer. Reports from clients with invalid or deactivated access tokens will be rejected on ingress.

You can configure global tags when configuring the Datadog tracer. See the example below:

```
Datadog.configure do |c|
  # setup integrations, etc...
  c.tracer tags: {
    'lightstep.service_name' => 'my-service-name',
    'lightstep.access_token' => 'my-token'
  }
end

## Getting started

For a basic product overview, check out our [setup documentation][setup docs].

For installation, configuration, and details about using the API, check out our [API documentation][api docs] and [gem documentation][gem docs].

For descriptions of terminology used in APM, take a look at the [official documentation][visualization docs].

For contributing, checkout the [contribution guidelines][contribution docs] and [development guide][development docs].

[setup docs]: https://docs.datadoghq.com/tracing/setup/ruby/
[api docs]: https://github.com/DataDog/dd-trace-rb/blob/master/docs/GettingStarted.md
[gem docs]: http://gems.datadoghq.com/trace/docs/
[visualization docs]: https://docs.datadoghq.com/tracing/visualization/
[contribution docs]: https://github.com/DataDog/dd-trace-rb/blob/master/CONTRIBUTING.md
[development docs]: https://github.com/DataDog/dd-trace-rb/blob/master/docs/DevelopmentGuide.md
