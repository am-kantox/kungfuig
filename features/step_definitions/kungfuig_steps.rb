Given(/^I include a Kungfuig module into class$/) do
  Object.send(:remove_const, 'Test') if Kernel.const_defined?('Test')
  Test = Class.new do
    include Kungfuig

    def yo param, *others
      [param, *others]
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
      plugin meth.to_sym do |*args|
        puts "Hi! I am called with parameters: #{args}!"
      end
    end
  ).to eq(meth.to_sym)
end

################################################################################

Then(/^I get new option "(.*?)" with value "(.*?)"$/) do |key, value|
  c = @test.config
  expect(c[key]).to eq(value)
end

Then(/^the plugin is called on "(.*?)" method execution$/) do |meth|
  @test.new.yo 'Parameter'
end
