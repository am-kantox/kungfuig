require 'spec_helper'
require 'rspec-sidekiq'

describe Kungfuig::Prepender do
  let(:test) { Test } # def yo(param, *rest, **splat)

  it 'is executed instead of original method' do
    Kungfuig::Prepender.anteponer :test, :yo do |**params|
      puts "I’d been called. Params: #{params.inspect}"
    end
    expect(test.new.yo(42)).to eq [42, [], {}, nil]
  end
end
