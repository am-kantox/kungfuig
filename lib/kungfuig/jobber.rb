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

      def bottleneck(receiver, method, result, *args)
        respond_to = ->(m, r) { r.respond_to? m.to_sym }
        r = case receiver
            when respond_to.curry[:to_hash] then receiver.to_hash
            when respond_to.curry[:to_h] then receiver.to_h
            else receiver
            end

        Kernel.const_get(@hash[receiver.class.name][method])
              .perform_async(r, method, result, *args)
      rescue => e
        Kungfuig.✍("Fail [#{e.message}] while #{receiver}", method, result, *args)
      end
    end
  end
end