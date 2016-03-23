require 'spec_helper'

describe Kungfuig do
  let(:test) { Test.new }

  it 'has a version number' do
    expect(Kungfuig::VERSION).not_to be nil
  end

  it 'attaches plugins properly' do
    before_plugin_1 = ->(*args) { puts "Before1 | Args: #{args.inspect}" }
    after_plugin_1 = ->(result, *args) { puts "Plugin1 | Result: #{result}, Args: #{args.inspect}" }
    after_plugin_2 = ->(result, *args) { puts "Plugin2 | Result: #{result}, Args: #{args.inspect}" }
    expect(test.class.plugin(:yo, false, &before_plugin_1)).to eq :yo
    expect(test.class.plugin(:yo, true, &after_plugin_1)).to eq :yo
    expect(test.class.plugin(:yo, true, &after_plugin_2)).to eq :yo

    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
    expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
  end
end
