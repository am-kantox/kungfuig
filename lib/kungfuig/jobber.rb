require 'digest'
require 'rubygems/exceptions'
require 'kungfuig/aspector'

begin
  require 'sidekiq'
  require 'sidekiq/api'
  fail LoadError.new unless Kernel.const_defined?('Sidekiq')
rescue LoadError
  raise(Gem::DependencyError, "Sidekiq id required to use this functionality!")
end

module Kungfuig
  class JobberError < StandardError
  end

  module Worker
    def self.prepended base
      fail JobberError.new("Must be prepended to class defining ‘perform’ method!") unless base.instance_methods.include?(:perform)
      base.send(:include, Sidekiq::Worker) unless base.ancestors.include? Sidekiq::Worker
    end

    def perform *args, **params
      args.select { |arg| arg.is_a?(Hash) }.each do |arg|
        params.merge! args.delete(arg).map { |k, v| [k.to_sym, v] }.to_h
      end
      super(*args, **params)
    end
  end

  # Generic helper for massive attaching aspects
  class Jobber
    class << self
      # 'Test':
      #   '*': 'YoJob'
      def bulk(hos)
        @delayed ||= {}
        @hash = Kungfuig.load_stuff hos
        Kungfuig::Aspector.bulk(
          @hash.map do |klazz, hash|
            [klazz, { after: hash.map { |k, _| [k, 'Kungfuig::Jobber#bottleneck'] }.to_h }]
          end.to_h
        )
      end

      def bottleneck(method: nil, receiver: nil, result: nil, **params)
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

        destination = Kernel.const_get(destination(receiver_class.name, method))
        destination.send(:prepend, Kungfuig::Worker) unless destination.ancestors.include? Kungfuig::Worker
        if (delay = delay(receiver_class.name, method))
          digest = digest(result, receiver_class.name, method)
          Sidekiq::Queue.new(destination.sidekiq_options_hash['queue'])
                        .find_job(@delayed.delete(digest)).tap { |j| j.delete if j }
          @delayed[digest] = destination.perform_in(delay, receiver: r, method: method, result: result, **params)
        else
          destination.perform_async(receiver: r, method: method, result: result, **params)
        end
      rescue => e
        Kungfuig.✍(receiver: [
          "Fail [#{e.message}]",
          *e.backtrace.unshift("Backtrace:").join("#{$/}⮩  "),
          "while #{receiver}"
        ].join($/), method: method, result: result, args: params)
      end

      def destination target, name
        case @hash[target][name]
        when NilClass then nil
        when String, Symbol then @hash[target][name]
        when Hash then @hash[target][name]['class']
        end
      end

      def delay target, name
        @hash[target][name].is_a?(Hash) && @hash[target][name]['delay'].to_i || nil
      end

      def digest result, target, name
        fields = @hash[target][name].is_a?(Hash) && @hash[target][name]['compare_by']
        Digest::SHA256.hexdigest(
          (fields.nil? ? result : fields.map { |f| result[f] }).inspect
        )
      end
    end
  end
end
