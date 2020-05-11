require 'spec_helper'

require 'ddtrace'
require 'ddtrace/context'
require 'ddtrace/ext/distributed'
require 'ddtrace/distributed_tracing/headers/b3_single'

RSpec.describe Datadog::DistributedTracing::Headers::B3Single do
  # Header format:
  #   b3: {TraceId}-{SpanId}-{SamplingState}-{ParentSpanId}
  # https://github.com/apache/incubator-zipkin-b3-propagation/tree/7c6e9f14d6627832bd80baa87ac7dabee7be23cf#single-header
  # DEV: `{SamplingState}` and `{ParentSpanId`}` are optional

  let(:context) { Datadog.Context.new }

  # Helper to format env header keys
  def env_header(name)
    "http-#{name}".upcase!.tr('-', '_')
  end

  def format_id(id)
    format(Datadog::Ext::DistributedTracing::ID_FORMAT_STR, id)
  end

  context '#inject!' do
    subject(:env) { {} }
    before(:each) { described_class.inject!(context, env) }

    context 'with nil context' do
      let(:context) { nil }
      it { is_expected.to eq({}) }
    end

    context 'with trace_id and span_id' do
      let(:context) do
        Datadog::Context.new(trace_id: 10000,
                             span_id: 20000)
      end

      it { is_expected.to eq(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE => "#{format_id(10000)}-#{format_id(20000)}") }

      [
        [-1, 0],
        [0, 0],
        [1, 1],
        [2, 1]
      ].each do |value, expected|
        context "with sampling priority #{value}" do
          let(:context) do
            Datadog::Context.new(trace_id: 50000,
                                 span_id: 60000,
                                 sampling_priority: value)
          end

          it { is_expected.to eq(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE => "#{format_id(50000)}-#{format_id(60000)}-#{expected}") }
        end
      end

      context 'with origin' do
        let(:context) do
          Datadog::Context.new(trace_id: 90000,
                               span_id: 100000,
                               origin: 'synthetics')
        end

        it { is_expected.to eq(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE => "#{format_id(90000)}-#{format_id(100000)}") }
      end
    end
  end

  context '#extract' do
    subject(:context) { described_class.extract(env) }
    let(:env) { {} }

    context 'with empty env' do
      it { is_expected.to be_nil }
    end

    context 'with trace_id and span_id' do
      let(:env) { { env_header(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE) => "#{format_id(90000)}-#{format_id(100000)}" } }

      it { expect(context.trace_id).to eq(90000) }
      it { expect(context.span_id).to eq(100000) }
      it { expect(context.sampling_priority).to be_nil }
      it { expect(context.origin).to be_nil }

      context 'with sampling priority' do
        let(:env) { { env_header(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE) => "#{format_id(90000)}-#{format_id(100000)}-1" } }
        it { expect(context.trace_id).to eq(90000) }
        it { expect(context.span_id).to eq(100000) }
        it { expect(context.sampling_priority).to eq(1) }
        it { expect(context.origin).to be_nil }

        context 'with parent_id' do
          let(:env) { { env_header(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE) => "#{format_id(90000)}-#{format_id(100000)}-1-#{format_id(20000)}" } }
          it { expect(context.trace_id).to eq(90000) }
          it { expect(context.span_id).to eq(100000) }
          it { expect(context.sampling_priority).to eq(1) }
          it { expect(context.origin).to be_nil }
        end
      end
    end

    context 'with trace_id' do
      let(:env) { { env_header(Datadog::Ext::DistributedTracing::B3_HEADER_SINGLE) => format_id(90000) } }
      it { is_expected.to be_nil }
    end
  end
end
