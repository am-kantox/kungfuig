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
  module Jobber
  end
end
