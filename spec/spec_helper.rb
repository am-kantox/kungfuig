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
        [@param = param, @rest = rest, @splat = splat, @result = block_result]
      end

      def to_hash
        {
          param: @param,
          rest: @rest,
          splat: @splat,
          result: @result
        }
      end
    end
  end
end
