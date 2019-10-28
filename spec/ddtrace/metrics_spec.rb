require 'spec_helper'

require 'ddtrace'
require 'ddtrace/metrics'
require 'benchmark'

RSpec.describe Datadog::Metrics do
  include_context 'metrics'

  subject(:metrics) { described_class.new(options) }
  let(:options) { { statsd: statsd, env: env } }
  let(:env) { 'test_env' }

  it { is_expected.to have_attributes(statsd: statsd) }

  describe '#supported?' do
    subject(:supported?) { metrics.supported? }

    context 'when the dogstatsd gem' do
      before do
        allow(Gem.loaded_specs).to receive(:[])
          .with('dogstatsd-ruby')
          .and_return(spec)
      end

      context 'is not loaded' do
        let(:spec) { nil }
        it { is_expected.to be false }
      end

      context 'is loaded' do
        let(:spec) { instance_double(Gem::Specification, version: version) }

        context 'with version < 3.3.0' do
          let(:version) { Gem::Version.new('3.2.9') }
          it { is_expected.to be false }
        end

        context 'with version 3.3.0' do
          let(:version) { Gem::Version.new('3.3.0') }
          it { is_expected.to be true }
        end
      end
    end
  end

  describe '#enabled?' do
    subject(:enabled) { metrics.enabled? }

    context 'by default' do
      it { is_expected.to be true }
    end

    context 'when initialized as enabled' do
      let(:options) { super().merge(enabled: true) }
      it { is_expected.to be true }
    end

    context 'when initialized as disabled' do
      let(:options) { super().merge(enabled: false) }
      it { is_expected.to be false }
    end
  end

  describe '#enabled=' do
    subject(:enabled) { metrics.enabled? }
    before { metrics.enabled = status }

    context 'is given true' do
      let(:status) { true }
      it { is_expected.to be true }
    end

    context 'is given false' do
      let(:status) { false }
      it { is_expected.to be false }
    end

    context 'is given nil' do
      let(:status) { nil }
      it { is_expected.to be false }
    end
  end

  describe '#default_hostname' do
    subject(:default_hostname) { metrics.default_hostname }

    context 'when environment variable is' do
      context 'set' do
        let(:value) { 'my-hostname' }

        around do |example|
          ClimateControl.modify(Datadog::Ext::Metrics::ENV_DEFAULT_HOST => value) do
            example.run
          end
        end

        it { is_expected.to eq(value) }
      end

      context 'not set' do
        around do |example|
          ClimateControl.modify(Datadog::Ext::Metrics::ENV_DEFAULT_HOST => nil) do
            example.run
          end
        end

        it { is_expected.to eq(Datadog::Ext::Metrics::DEFAULT_HOST) }
      end
    end
  end

  describe '#default_port' do
    subject(:default_port) { metrics.default_port }

    context 'when environment variable is' do
      context 'set' do
        let(:value) { '1234' }

        around do |example|
          ClimateControl.modify(Datadog::Ext::Metrics::ENV_DEFAULT_PORT => value) do
            example.run
          end
        end

        it { is_expected.to eq(value.to_i) }
      end

      context 'not set' do
        around do |example|
          ClimateControl.modify(Datadog::Ext::Metrics::ENV_DEFAULT_PORT => nil) do
            example.run
          end
        end

        it { is_expected.to eq(Datadog::Ext::Metrics::DEFAULT_PORT) }
      end
    end
  end

  describe '#default_statsd_client' do
    subject(:default_statsd_client) { metrics.default_statsd_client }
    let(:statsd_client) { instance_double(Datadog::Statsd) }

    before do
      expect(Datadog::Statsd).to receive(:new)
        .with(metrics.default_hostname, metrics.default_port)
        .and_return(statsd_client)
    end

    it { is_expected.to be(statsd_client) }
  end

  describe '#configure' do
    subject(:configure) { metrics.configure(configure_options) }

    context 'given options including' do
      context ':statsd' do
        let(:configure_options) { { statsd: custom_statsd } }
        let(:custom_statsd) { instance_double(Datadog::Statsd) }
        it { expect { configure }.to change { metrics.statsd }.from(statsd).to(custom_statsd) }
      end

      context ':enabled' do
        let(:configure_options) { { enabled: enabled } }

        context 'as true' do
          let(:enabled) { true }
          before { configure }
          it { expect(metrics.enabled?).to be(true) }
        end

        context 'as false' do
          let(:enabled) { false }
          before { configure }
          it { expect(metrics.enabled?).to be(false) }
        end
      end

      context ':env' do
        let(:configure_options) { { env: custom_env } }
        let(:custom_env) { 'custom_env' }
        it { expect { configure }.to change { metrics.env }.from(env).to(custom_env) }
      end
    end
  end

  describe '#send_stats?' do
    subject(:send_stats?) { metrics.send_stats? }

    context 'when disabled' do
      before { metrics.enabled = false }
      it { is_expected.to be(false) }
    end

    context 'when enabled' do
      context 'and Statsd' do
        context 'is initialized' do
          let(:custom_statsd) { instance_double(Datadog::Statsd) }
          before { metrics.configure(statsd: custom_statsd) }
          it { is_expected.to be(true) }
        end

        context 'is nil' do
          before { metrics.configure(statsd: nil) }
          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe '#distribution' do
    subject(:distribution) { metrics.distribution(stat, value, stat_options) }
    let(:stat) { :foo }
    let(:value) { 100 }
    let(:stat_options) { {} }

    context 'when #statsd is nil' do
      before(:each) do
        allow(metrics).to receive(:statsd).and_return(nil)
        expect { distribution }.to_not raise_error
      end

      it { expect(statsd).to_not have_received_distribution_metric(stat) }
    end

    context 'when #statsd is a Datadog::Statsd' do
      context 'and given no options' do
        before(:each) { expect { distribution }.to_not raise_error }
        it { expect(statsd).to have_received_distribution_metric(stat) }
      end

      context 'and given options' do
        before(:each) { expect { distribution }.to_not raise_error }

        context 'that are empty' do
          let(:stat_options) { {} }
          it { expect(statsd).to have_received_distribution_metric(stat) }
        end

        context 'that are frozen' do
          let(:stat_options) { {}.freeze }
          it { expect(statsd).to have_received_distribution_metric(stat) }
        end

        context 'that contain :tags' do
          let(:stat_options) { { tags: tags } }
          let(:tags) { %w[foo bar] }
          it { expect(statsd).to have_received_distribution_metric(stat, kind_of(Numeric), stat_options) }

          context 'which are frozen' do
            let(:tags) { super().freeze }
            it { expect(statsd).to have_received_distribution_metric(stat, kind_of(Numeric), stat_options) }
          end
        end
      end

      context 'which raises an error' do
        before(:each) do
          expect(statsd).to receive(:distribution).and_raise(StandardError)
          expect(Datadog::Tracer.log).to receive(:error)
        end

        it { expect { distribution }.to_not raise_error }
      end
    end
  end

  describe '#gauge' do
    subject(:gauge) { metrics.gauge(stat, value, stat_options) }
    let(:stat) { :foo }
    let(:value) { 100 }
    let(:stat_options) { {} }

    context 'when #statsd is nil' do
      before(:each) do
        allow(metrics).to receive(:statsd).and_return(nil)
        expect { gauge }.to_not raise_error
      end

      it { expect(statsd).to_not have_received_gauge_metric(stat) }
    end

    context 'when #statsd is a Datadog::Statsd' do
      context 'and given no options' do
        before(:each) { expect { gauge }.to_not raise_error }
        it { expect(statsd).to have_received_gauge_metric(stat) }
      end

      context 'and given options' do
        before(:each) { expect { gauge }.to_not raise_error }

        context 'that are empty' do
          let(:stat_options) { {} }
          it { expect(statsd).to have_received_gauge_metric(stat) }
        end

        context 'that are frozen' do
          let(:stat_options) { {}.freeze }
          it { expect(statsd).to have_received_gauge_metric(stat) }
        end

        context 'that contain :tags' do
          let(:stat_options) { { tags: tags } }
          let(:tags) { %w[foo bar] }
          it { expect(statsd).to have_received_gauge_metric(stat, kind_of(Numeric), stat_options) }

          context 'which are frozen' do
            let(:tags) { super().freeze }
            it { expect(statsd).to have_received_gauge_metric(stat, kind_of(Numeric), stat_options) }
          end
        end
      end

      context 'which raises an error' do
        before(:each) do
          expect(statsd).to receive(:gauge).and_raise(StandardError)
          expect(Datadog::Tracer.log).to receive(:error)
        end

        it { expect { gauge }.to_not raise_error }
      end
    end
  end

  describe '#increment' do
    subject(:increment) { metrics.increment(stat, stat_options) }
    let(:stat) { :foo }
    let(:stat_options) { {} }

    context 'when #statsd is nil' do
      before(:each) do
        allow(metrics).to receive(:statsd).and_return(nil)
        expect { increment }.to_not raise_error
      end

      it { expect(statsd).to_not have_received_increment_metric(stat) }
    end

    context 'when #statsd is a Datadog::Statsd' do
      context 'and given no options' do
        before(:each) { expect { increment }.to_not raise_error }
        it { expect(statsd).to have_received_increment_metric(stat) }
      end

      context 'and given options' do
        before(:each) { expect { increment }.to_not raise_error }

        context 'that are empty' do
          let(:stat_options) { {} }
          it { expect(statsd).to have_received_increment_metric(stat) }
        end

        context 'that are frozen' do
          let(:stat_options) { {}.freeze }
          it { expect(statsd).to have_received_increment_metric(stat) }
        end

        context 'that contain :by' do
          let(:stat_options) { { by: count } }
          let(:count) { 1 }
          it { expect(statsd).to have_received_increment_metric(stat, stat_options) }
        end

        context 'that contain :tags' do
          let(:stat_options) { { tags: tags } }
          let(:tags) { %w[foo bar] }
          it { expect(statsd).to have_received_increment_metric(stat, stat_options) }

          context 'which are frozen' do
            let(:tags) { super().freeze }
            it { expect(statsd).to have_received_increment_metric(stat, stat_options) }
          end
        end
      end

      context 'which raises an error' do
        before(:each) do
          expect(statsd).to receive(:increment).and_raise(StandardError)
          expect(Datadog::Tracer.log).to receive(:error)
        end

        it { expect { increment }.to_not raise_error }
      end
    end
  end

  describe '#time' do
    subject(:time) { metrics.time(stat, stat_options, &block) }
    let(:stat) { :foo }
    let(:stat_options) { {} }
    let(:block) { proc {} }

    context 'when #statsd is nil' do
      before(:each) do
        allow(metrics).to receive(:statsd).and_return(nil)
        expect { time }.to_not raise_error
      end

      it { expect(statsd).to_not have_received_time_metric(stat) }
    end

    context 'when #statsd is a Datadog::Statsd' do
      context 'and given a block' do
        it { expect { |b| metrics.time(stat, &b) }.to yield_control }

        context 'which raises an error' do
          let(:block) { proc { raise error } }
          let(:error) { RuntimeError.new }
          # Expect the given block to raise its errors through
          it { expect { time }.to raise_error(error) }
        end
      end

      context 'and given no options' do
        before(:each) { expect { time }.to_not raise_error }
        it { expect(statsd).to have_received_time_metric(stat) }
      end

      context 'and given options' do
        before(:each) { expect { time }.to_not raise_error }

        context 'that are empty' do
          let(:stat_options) { {} }
          it { expect(statsd).to have_received_time_metric(stat) }
        end

        context 'that are frozen' do
          let(:stat_options) { {}.freeze }
          it { expect(statsd).to have_received_time_metric(stat) }
        end

        context 'that contain :tags' do
          let(:stat_options) { { tags: tags } }
          let(:tags) { %w[foo bar] }
          it { expect(statsd).to have_received_time_metric(stat, stat_options) }

          context 'which are frozen' do
            let(:tags) { super().freeze }
            it { expect(statsd).to have_received_time_metric(stat, stat_options) }
          end
        end
      end

      context 'which raises an error' do
        before(:each) do
          expect(statsd).to receive(:distribution).and_raise(StandardError)
          expect(Datadog::Tracer.log).to receive(:error)
        end

        it { expect { time }.to_not raise_error }
      end
    end
  end
end
