Given(/^I include a Kungfuig module into class$/) do
  Object.send(:remove_const, 'Test') if Kernel.const_defined?('Test')
  Test = Class.new do
    include Kungfuig

    def yo(param, *rest, **splat)
      block_result = yield if block_given?
      [param, rest, splat, block_result]
    end
  end
  @test = Test
end

Given(/^I include a Kungfuig module into instance$/) do
  Object.send(:remove_const, 'Test') if Kernel.const_defined?('Test')
  Test = Class.new do
    include Kungfuig
  end
  @test = Test.new
end

################################################################################

When(/^I pass new option "(.*?)" with value "(.*?)" via block$/) do |key, value|
  @test.config do |c|
    c[key] = value
  end
end

When(/^I pass new option "(.*?)" with value "(.*?)" via block’s DSL$/) do |key, value|
  @test.kungfuig do
    set key, value
  end
end

When(/^I pass new option "(.*?)" with value "(.*?)" via hash$/) do |key, value|
  @test.config({key => value})
end

When(/^I pass new file "(.*?)" to config$/) do |f|
  @test.config f
end

When(/^I try to configure with DSL I yield an exception raised$/) do
  expect {
    step "I pass new option \"(.*?)\" with value \"(.*?)\" via block’s DSL"
  }.to raise_error(NoMethodError)
end

When(/^I specify a plugin to be attached to "(.*?)" method$/) do |meth|
  expect(
    @test.kungfuig do
      plugin(meth.to_sym) do |*args|
        puts "Hi! I am KUNGFUIG::PLUGIN called with parameters: #{args}!"
      end
    end
  ).to eq(meth.to_sym)

  expect(
    @test.plugin(meth.to_sym) do |*args|
      puts "Hi! I am PLUGIN called with parameters: #{args}!"
    end
  ).to eq(meth.to_sym)
end

When(/^I try to retrieve a value from a “branch” that has no such value$/) do
  @bar = @test.option 'production.foo.bar'
end

When(/^I try to retrieve a value from a “branch” that has that value$/) do
  @baz = @test.option 'production', 'foo', 'baz'
end

When(/^I try to set a value deeply inside options in inexisting section$/) do
  @test.option! 'one.two.three', 123
end

################################################################################

Then(/^I get new option "(.*?)" with value "(.*?)"$/) do |key, value|
  c = @test.config
  expect(c[key]).to eq(value)
end

Then(/^the plugin is called on "(.*?)" method execution$/) do |meth|
  expect(
    @test.new.yo('Parameter', 42, a: 1, b: 2, **{c: 3, d: 4}) { 'block-value' }
  ).to eq(["Parameter", [42], {a: 1, b: 2, c: 3, d: 4}, "block-value"])
end

Then(/^the value from a default branch is retrieven$/) do
  expect(@bar).to eq(42)
end

Then(/^the value from a specific branch is retrieven$/) do
  expect(@baz).to eq(2.71)
end

Then(/^the value from a specific branch is set$/) do
  expect(@test.option('one.two.three')).to eq(123)
  expect(@test.option('production.one.two.three')).to eq(123)
end
