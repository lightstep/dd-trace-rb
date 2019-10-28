require 'ddtrace/ext/metrics'

require 'set'
require 'ddtrace/utils/time'
require 'ddtrace/runtime/identity'

module Datadog
  # Acts as client for sending metrics (via Statsd)
  # Wraps a Statsd client with default tags and additional configuration.
  class Metrics
    attr_reader :statsd, :env

    def initialize(options = {})
      @statsd = options.fetch(:statsd) { default_statsd_client if supported? }
      @enabled = options.fetch(:enabled, true)
      @env = options.fetch(:env) { ENV[Ext::Metrics::DATADOG_ENV] }

      compile_instance_tags!
    end

    def supported?
      version = Gem.loaded_specs['dogstatsd-ruby'] \
                  && Gem.loaded_specs['dogstatsd-ruby'].version

      !version.nil? && (version >= Gem::Version.new('3.3.0'))
    end

    def enabled?
      @enabled
    end

    def enabled=(enabled)
      @enabled = (enabled == true)
    end

    def default_hostname
      ENV.fetch(Datadog::Ext::Metrics::ENV_DEFAULT_HOST, Datadog::Ext::Metrics::DEFAULT_HOST)
    end

    def default_port
      ENV.fetch(Datadog::Ext::Metrics::ENV_DEFAULT_PORT, Datadog::Ext::Metrics::DEFAULT_PORT).to_i
    end

    def default_statsd_client
      require 'datadog/statsd' unless defined?(::Datadog::Statsd)

      # Create a StatsD client that points to the agent.
      Datadog::Statsd.new(default_hostname, default_port)
    end

    def configure(options = {})
      @statsd = options[:statsd] if options.key?(:statsd)
      self.enabled = options[:enabled] if options.key?(:enabled)
      @env = options[:env] if options.key?(:env)

      compile_instance_tags!
    end

    def send_stats?
      enabled? && !statsd.nil?
    end

    def distribution(stat, value, options = {})
      return unless send_stats? && statsd.respond_to?(:distribution)
      statsd.distribution(stat, value, metric_options(options))
    rescue StandardError => e
      Datadog::Tracer.log.error("Failed to send distribution stat. Cause: #{e.message} Source: #{e.backtrace.first}")
    end

    def increment(stat, options = {})
      return unless send_stats? && statsd.respond_to?(:increment)
      statsd.increment(stat, metric_options(options))
    rescue StandardError => e
      Datadog::Tracer.log.error("Failed to send increment stat. Cause: #{e.message} Source: #{e.backtrace.first}")
    end

    def gauge(stat, value, options = {})
      return unless send_stats? && statsd.respond_to?(:gauge)
      statsd.gauge(stat, value, metric_options(options))
    rescue StandardError => e
      Datadog::Tracer.log.error("Failed to send gauge stat. Cause: #{e.message} Source: #{e.backtrace.first}")
    end

    def time(stat, options = {})
      return yield unless send_stats?

      # Calculate time, send it as a distribution.
      start = Utils::Time.get_time
      return yield
    ensure
      begin
        if send_stats? && !start.nil?
          finished = Utils::Time.get_time
          distribution(stat, ((finished - start) * 1000), options)
        end
      rescue StandardError => e
        Datadog::Tracer.log.error("Failed to send time stat. Cause: #{e.message} Source: #{e.backtrace.first}")
      end
    end

    def compile_instance_tags!
      @instance_tags = []
      @instance_tags << "#{Ext::Metrics::TAG_ENV}:#{@env}".freeze if @env
      @instance_tags.freeze
    end

    # Add instance tags to default metrics
    def default_metric_options
      super if @instance_tags.empty?

      # Return dupes, so that the constant isn't modified,
      # and defaults are unfrozen for mutation in Statsd.
      super.tap do |options|
        options[:tags] = options[:tags].dup

        # Add tags dynamically because they might change during runtime.
        options[:tags].concat(@instance_tags)
      end
    end

    # For defining and adding default options to metrics
    module Options
      DEFAULT = {
        tags: DEFAULT_TAGS = [
          "#{Ext::Metrics::TAG_LANG}:#{Runtime::Identity.lang}".freeze,
          # "#{Ext::Metrics::TAG_LANG_INTERPRETER}:#{Runtime::Identity.lang_interpreter}".freeze,
          # "#{Ext::Metrics::TAG_LANG_VERSION}:#{Runtime::Identity.lang_version}".freeze,
          # "#{Ext::Metrics::TAG_TRACER_VERSION}:#{Runtime::Identity.tracer_version}".freeze,
        ].freeze
      }.freeze

      def metric_options(*options)
        merge_with_tags(default_metric_options, *options)
      end

      def merge_with_tags(hash, *hashes)
        hash.merge(*hashes) do |key, old_value, new_value|
          case key
          when :tags
            old_value.dup.concat(new_value).uniq
          else
            new_value
          end
        end
      end

      def default_metric_options
        # Return dupes, so that the constant isn't modified,
        # and defaults are unfrozen for mutation in Statsd.
        DEFAULT.dup.tap do |options|
          options[:tags] = options[:tags].dup
        end
      end
    end

    # Make available on for both class and instance.
    include Options
    extend Options
  end
end
