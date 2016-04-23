$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'rspec'
require 'kungfuig'

RSpec.configure do |config|
  config.before(:each) do
    Sidekiq::Worker.clear_all if Kernel.const_defined?('Sidekiq::Worker')
    Object.send(:remove_const, 'TestChild') if Kernel.const_defined?('TestChild')
    Object.send(:remove_const, 'Test') if Kernel.const_defined?('Test')
    Test = Class.new do
      def yo_no_params
        block_result = yield if block_given?
        [@result = block_result]
      end

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
    TestChild = Class.new(Test) do
      def yo(param, *rest, **splat)
        puts "Inside TestChild\#yo"
        super
      end
    end
  end
end
