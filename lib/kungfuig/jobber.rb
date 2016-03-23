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

      def bottleneck(klazz, method, result, *args)
        puts "Bottleneck called for: #{@hash[klazz.class.name][method]} :: #{result} :: #{args}}}"
      end
    end
  end
end
