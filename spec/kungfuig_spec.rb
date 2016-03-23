require 'spec_helper'

describe Kungfuig do
  let(:test) { Test.new }

  it 'has a version number' do
    expect(Kungfuig::VERSION).not_to be nil
  end

  it 'attaches aspects properly' do
    before_aspect_1 = ->(*args) { puts "Before1 | Args: #{args.inspect}" }
    after_aspect_1 = ->(result, *args) { puts "Aspect1 | Result: #{result}, Args: #{args.inspect}" }
    after_aspect_2 = ->(result, *args) { puts "Aspect2 | Result: #{result}, Args: #{args.inspect}" }
    expect(test.class.aspect(:yo, false, &before_aspect_1)).to eq :yo
    expect(test.class.aspect(:yo, true, &after_aspect_1)).to eq :yo
    expect(test.class.aspect(:yo, true, &after_aspect_2)).to eq :yo

    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
    expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
  end

  it 'attaches aspects properly with Aspector' do
    require 'kungfuig/aspector'
    before_aspect_1 = ->(*args) { puts "Before1 | Args: #{args.inspect}" }
    after_aspect_1 = ->(result, *args) { puts "Aspect1 | Result: #{result}, Args: #{args.inspect}" }
    after_aspect_2 = ->(result, *args) { puts "Aspect2 | Result: #{result}, Args: #{args.inspect}" }
    expect(Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_1)).to be_has_key(:yo)
    expect(Kungfuig::Aspector.attach(test.class, before: :yo, &before_aspect_1)[:yo][:before].size).to eq 1
    expect(Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_2)[:yo][:after].size).to eq 2

    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
    expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
  end
end
