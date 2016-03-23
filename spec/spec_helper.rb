$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'rspec'
require 'kungfuig'

RSpec.configure do |config|
  config.before(:each) do
    Object.send(:remove_const, 'Test') if Kernel.const_defined?('Test')
    Test = Class.new do
      include Kungfuig

      def yo(param, *rest, **splat)
        block_result = yield if block_given?
        [param, rest, splat, block_result]
      end
    end
  end
end
