require 'vidibus/recording/worker'
require 'vidibus/recording/backend'
require 'vidibus/recording/helpers'
require 'vidibus/recording/part'
require 'vidibus/recording/mongoid'
require 'vidibus/recording/railtie' if defined?(Rails::Railtie)

module Vidibus
  module Recording
    extend self

    class Error < StandardError; end

    INTERVAL = 1

    attr_accessor :logger, :autoload_paths, :classes, :monitoring_interval
    @logger = Logger.new(STDOUT)
    @autoload_paths = []
    @classes = []
    @monitoring_interval = 1

    # Monitor all started recordings
    def monitor
      autoload
      unless classes.any?
        logger.error("[#{Time.now.utc}] - No recording classes given")
      else
        logger.info("[#{Time.now.utc}] - Watching recordings")
        run
      end
    end

    # Obtain all classes that include the Mongoid module
    def autoload
      return [] unless autoload_paths.any?
      regexp = /class ([^<\n]+).+include Vidibus::Recording::Mongoid/m
      names = Dir[*autoload_paths].map do |f|
        File.read(f)[regexp, 1]
      end.compact
      self.classes = names.map { |k| k.constantize }
    end

    private

    def run
      loop do
        classes.each do |klass|
          klass.started.each do |recording|
            begin
              if recording.worker_running?
                recording.track_progress
              else
                logger.info("[#{Time.now.utc}] - Resuming #{recording.class.name} #{recording.uuid}")
                recording.resume
              end
            rescue => e
              logger.error("[#{Time.now.utc}] - ERROR:\n#{e.inspect}\n---\n#{e.backtrace.join("\n")}")
            end
          end
        end
        sleep(monitoring_interval)
      end
    end
  end
end
