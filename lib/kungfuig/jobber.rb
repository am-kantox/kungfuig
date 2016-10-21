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
    RESPOND_TO = ->(m, r) { r.respond_to? m.to_sym }

    class Dummy
      prepend Kungfuig::Worker

      def perform digest: nil, delay: nil, worker: nil, worker_params: nil
        Sidekiq.redis { |redis| redis.set(digest, worker_params.to_json) }
        DummyExecutor.perform_in(delay, digest: digest, worker: worker)
      end
    end

    class DummyExecutor
      prepend Kungfuig::Worker

      def perform digest: nil, worker: nil
        params = Sidekiq.redis { |redis| redis.get(digest) }
        worker.perform_async(**params) if params
      end
    end

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

      def bottleneck(method: nil, receiver: nil, result: nil, **params)
        return unless (receiver_class = receiver.class.ancestors.detect do |c|
          @hash[c.name] && @hash[c.name][method]
        end)

        r, worker = patch_receiver(receiver_class.name, method)
        worker_params = { receiver: r, method: method, result: result, **params }
        if (delay = delay(receiver_class.name, method))
          Dummy.perform_async(
            digest: digest(result, receiver_class.name, method),
            delay: delay,
            worker: worker,
            worker_params: worker_params
          )
        else
          worker.perform_async(worker_params)
        end
      rescue => e
        Kungfuig.✍(receiver: [
          "Fail [#{e.message}]",
          *e.backtrace.unshift("Backtrace:").join("#{$/}⮩  "),
          "while #{receiver}"
        ].join($/), method: method, result: result, args: params)
      end

      ##########################################################################

      def primitivize(receiver)
        case receiver
        when Hash, Array, String then receiver
        when RESPOND_TO.curry[:to_hash] then receiver.to_hash
        when RESPOND_TO.curry[:to_h] then receiver.to_h
        else receiver
        end
      end

      def patch_receiver target, name
        klazz = case @hash[target][name]
                when String, Symbol then @hash[target][name]
                when Hash then @hash[target][name]['class']
                else return
                end
        [klazz, Kernel.const_get(klazz).tap do |c|
          c.send(:prepend, Kungfuig::Worker) unless c.ancestors.include? Kungfuig::Worker
        end]
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
