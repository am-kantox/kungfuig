$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'rspec'
require 'kungfuig'
# require 'mock_redis'

require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

module TestModule
  def yo *args, **params
    Kungfuig.✍(receiver: "TestModule :: got args «#{args.inspect}» and params «#{params.inspect}»")
    true
  end
end

RSpec.configure do |config|
  config.mock_with :flexmock

  config.before(:each) do
    # Sidekiq.redis = MockRedis.new
    # Sidekiq.redis(&:flushdb)
    Sidekiq::Worker.clear_all if Kernel.const_defined?('Sidekiq::Worker')
    Object.send(:remove_const, 'TestChild') if Kernel.const_defined?('TestChild')
    Object.send(:remove_const, 'Test') if Kernel.const_defined?('Test')
    Object.send(:remove_const, 'TestModuleTest') if Kernel.const_defined?('TestModuleTest')
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
    TestModuleTest = Class.new do
      include TestModule
    end
  end
end

class TestWorker
  def perform *args, **params
    Kungfuig.✍(receiver: "TestWorker :: got args «#{args.inspect}» and params «#{params.inspect}»")
  end
end

class TestWorkerString
  def perform param
    Kungfuig.✍(receiver: param)
  end
end
