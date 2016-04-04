require_relative './aspector'
require 'rubygems/exceptions'

begin
  require 'sidekiq'
  raise LoadError.new unless Kernel.const_defined?('Sidekiq')
rescue LoadError
  raise(Gem::DependencyError, "Sidekiq id required to use this functionality!")
end

module Kungfuig
  # Generic helper for massive attaching aspects
  class Jobber
    class << self
      # 'Test':
      #   '*': 'YoJob'
      def bulk(hos)
        @hash = Kungfuig.load_stuff hos
        Kungfuig::Aspector.bulk(
          @hash.map do |klazz, hash|
            [klazz, { after: hash.map { |k, _| [k, 'Kungfuig::Jobber#bottleneck'] }.to_h }]
          end.to_h
        )
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      # rubocop:disable Metrics/MethodLength
      def bottleneck(receiver, method, result, *args)
        respond_to = ->(m, r) { r.respond_to? m.to_sym }
        r = case receiver
            when Hash, Array, String then receiver
            when respond_to.curry[:to_hash] then receiver.to_hash
            when respond_to.curry[:to_h] then receiver.to_h
            else receiver
            end
        return unless (receiver_class = receiver.class.ancestors.detect do |c|
          @hash[c.name] && @hash[c.name][method]
        end)

        job = Kernel.const_get(@hash[receiver_class.name][method])
        if Kernel.const_defined?('Rails') && Rails.env.development?
          job.new.perform(r, method, result, *args)
        else
          job.perform_async(r, method, result, *args)
        end
      rescue => e
        Kungfuig.✍([
          "Fail [#{e.message}]",
          *e.backtrace.unshift("Backtrace:").join("#{$/}⮩  "),
          "while #{receiver}"
        ].join($/), method, result, *args)
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize
    end
  end
end
