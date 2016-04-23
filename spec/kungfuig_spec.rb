require 'spec_helper'

describe Kungfuig do
  let(:test) { Test.new }
  let(:test_child) { TestChild.new }
  let!(:before_aspect_1) do
    lambda do |klazz: nil, receiver: nil, method: nil, args: nil, **params|
      puts "Before1[#{receiver || klazz}##{method}] | Args: #{args.inspect} | Params: #{params.inspect}"
    end
  end
  let!(:after_aspect_1) do
    lambda do |klazz: nil, method: nil, args: nil, **params|
      puts "After1[#{klazz}##{method}] | Result: #{params[:result]}, Args: #{args.inspect}"
    end
  end
  let!(:after_aspect_2) { ->(**params) { puts "After2[#{params[:klazz]}##{params[:method]}] | Result: #{params[:result]}, Args: #{params[:args].inspect}" } }

  let!(:re) { /\ABefore1.*?| Args: \[42\].*?After1.*?After2.*?| Result: \[42, \[\], {}, nil\], Args: \[42\]\z/ }
  let!(:re1) { /\ABefore1.*?| Args: \[42, :p1, :p2\] | Params: {:params=>{}, :cb=>nil}.*?After1.*?After2.*?| Result: \[42, \[\], \{\}, nil\], Args: \[42\]\z/ }
  let!(:re2) { /\ABefore1.*?| Args: \[42, :p1, :p2\] | Params: {:params=>{:sp1=>1, :sp2=>1}, :cb=>nil}.*?After1.*?After2.*?| Result: \[42, \[\], \{\}, nil\], Args: \[42\]\z/ }

  let!(:re4) { /\AInside TestChild#yo.*After1\[Test#yo\].*?After2\[TestChild#yo\]/m }

  context 'general' do
    it 'has a version number' do
      expect(Kungfuig::VERSION).not_to be nil
    end
  end

  context 'simple aspects' do
    it 'attaches aspects properly' do
      test.class.send :include, Kungfuig
      expect(test.class.aspect(:yo, false, &before_aspect_1).method).to eq :yo
      expect(test.class.aspect(:yo, true, &after_aspect_1).method).to eq :yo
      expect(test.class.aspect(:yo, true, &after_aspect_2).method).to eq :yo

      expect { test.yo(42) }.to output(re).to_stdout
      expect { test.yo(42, :p1, :p2) }.to output(re1).to_stdout
      expect { test.yo(42, :p1, :p2, sp1: 1, sp2: 1) }.to output(re2).to_stdout
    end
  end

  context 'aspector on duty' do
    it 'attaches aspects properly with Aspector' do
      Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_1)
      Kungfuig::Aspector.attach(test.class, before: :yo, &before_aspect_1)
      Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_2)
      expect(test.class.aspects).to eq(yo: 3)

      expect { test.yo(42) }.to output(re).to_stdout
      expect { test.yo(42, :p1, :p2) }.to output(re1).to_stdout
      expect { test.yo(42, :p1, :p2, sp1: 1, sp2: 1) }.to output(re2).to_stdout
    end

    it 'attaches aspects properly to instance object’s eigenclass' do
      expect(Kungfuig::Aspector.attach(test, after: :yo, &after_aspect_1)).to be_has_key(:yo)
      expect(Kungfuig::Aspector.attach(test, before: :yo, &before_aspect_1)[:yo]).to eq 2

      expect { test.yo(42) }.to output(re).to_stdout
      expect { test.yo(42, :p1, :p2) }.to output(re1).to_stdout
      expect { test.yo(42, :p1, :p2, sp1: 1, sp2: 1) }.to output(re2).to_stdout
    end

    it 'all aspects in class hierarchy are called' do
      expect(Kungfuig::Aspector.attach(test.class, after: :yo, &after_aspect_1)).to be_has_key(:yo)
      expect(Kungfuig::Aspector.attach(test_child.class, after: :yo, &after_aspect_2)).to be_has_key(:yo)

      expect { test_child.yo(42) }.to output(re4).to_stdout
      expect { test_child.yo(42, :p1, :p2) }.to output(re4).to_stdout
      expect { test_child.yo(42, :p1, :p2, sp1: 1, sp2: 1) }.to output(re4).to_stdout
    end
  end

  context 'bulk' do
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

    it 'accepts promises for bulk attach' do
      yaml = <<YAML
'TestFuture':
  after:
    'yo': 'Kungfuig#✍'
  before:
    'yo': 'Kungfuig#✍'
YAML
      expect(Kungfuig::Aspector.bulk(yaml)).to be_truthy

      class TestFuture < Test; end

      expect(TestFuture.new.yo(42)).to eq [42, [], {}, nil]
      expect(TestFuture.new.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
      expect(TestFuture.new.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
    end
  end
end
