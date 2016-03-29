require 'spec_helper'

describe Kungfuig do
  let(:test) { Test.new }
  let!(:before_aspect_1) { ->(receiver, method, _, *args) { puts "Before1[#{receiver.class}##{method}] | Args: #{args.inspect}" } }
  let!(:after_aspect_1) { ->(receiver, method, result, *args) { puts "After1[#{receiver.class}##{method}] | Result: #{result}, Args: #{args.inspect}" } }
  let!(:after_aspect_2) { ->(receiver, method, result, *args) { puts "After2[#{receiver.class}##{method}] | Result: #{result}, Args: #{args.inspect}" } }

  context 'general' do
    it 'has a version number' do
      expect(Kungfuig::VERSION).not_to be nil
    end
  end

  context 'simple aspects' do
    it 'attaches aspects properly' do
      test.class.send :include, Kungfuig
      expect(test.class.aspect(:yo, false, &before_aspect_1)).to eq :yo
      expect(test.class.aspect(:yo, true, &after_aspect_1)).to eq :yo
      expect(test.class.aspect(:yo, true, &after_aspect_2)).to eq :yo

      expect(test.yo(42)).to eq [42, [], {}, nil]
      expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
      expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
    end
  end

  context 'aspector on duty' do
    it 'attaches aspects properly with Aspector' do
      expect(Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_1)).to be_has_key(:yo)
      expect(Kungfuig::Aspector.attach(test.class, before: :yo, &before_aspect_1)[:yo][:before].size).to eq 1
      expect(Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_2)[:yo][:after].size).to eq 2

      expect(test.yo(42)).to eq [42, [], {}, nil]
      expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
      expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
    end
  end

  context 'aspector with eigenclass' do
    it 'attaches aspects properly to instance object’s eigenclass' do
      expect(Kungfuig::Aspector.attach(test, after: :yo, &after_aspect_1)).to be_has_key(:yo)
      expect(Kungfuig::Aspector.attach(test, before: :yo, &before_aspect_1)[:yo][:before].size).to eq 1
      expect(Kungfuig::Aspector.attach(test, after: :yo, &after_aspect_2)[:yo][:after].size).to eq 2

      expect(test.yo(42)).to eq [42, [], {}, nil]
      expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
      expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
    end
  end

  context 'bulk I' do
    it 'accepts YAML for bulk attach' do
      yaml = <<YAML
'Test':
  after:
    'yo': 'Kungfuig#✍'
  before:
    'yo': 'Kungfuig#✍'
YAML
      expect(Kungfuig::Aspector.bulk(yaml)).to be_truthy

      expect(test.yo(42)).to eq [42, [], {}, nil]
      expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
      expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
    end
  end

  context 'bulk II' do
    it 'accepts placeholders in YAML for bulk attach' do
      yaml = <<YAML
'Test':
  after:
    '*': 'Kungfuig#✍'
YAML
      expect(Kungfuig::Aspector.bulk(yaml)).to be_truthy

      expect(test.yo(42)).to eq [42, [], {}, nil]
      expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
      expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
    end
  end
end
