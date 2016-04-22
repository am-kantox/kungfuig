require 'spec_helper'
require 'rspec-sidekiq'

describe Kungfuig::Prepender do
  let(:test) { Test.new } # def yo(param, *rest, **splat)

  it 'is executed instead of original method' do
    Kungfuig::Prepender.anteponer :test, :yo do |**params|
      puts "I’d been called #1. Params: #{params.inspect}"
    end
    Kungfuig::Prepender.anteponer :test, :yo do |**params|
      puts "I’d been called #2. Params: #{params.inspect}"
    end
    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect { test.yo(42) }.to output([
      "I’d been called #1. Params: {:class=>Test, :method=>:yo, :receiver=>nil, :result=>[42, [], {}, nil]}",
      "I’d been called #2. Params: {:class=>Test, :method=>:yo, :receiver=>nil, :result=>[42, [], {}, nil]}",
      ""
    ].join($/)).to_stdout
  end

  it 'is not throwing an exception' do
    Kungfuig::Prepender.anteponer :test, :yo do |**_|
      raise "NEVER THROWN"
    end
    expect { test.yo(42) }.not_to raise_error
    expect(Kungfuig::Prepender.errors.size).to eq 1
  end

  it 'may be applied to not yet created class' do
    Kungfuig::Prepender.anteponer :future, :yo do |**params|
      puts "I’d been called. Params: #{params.inspect}"
    end
    class Future < Test
    end

    expect { Future.new.yo(42) }.not_to raise_error
    expect(Future.new.yo(42)).to eq [42, [], {}, nil]
    expect { Future.new.yo(42) }.to output(/:class=>Future/).to_stdout
  end

  it 'calls on_hook' do
    Kungfuig::Prepender.new(:hooked, :yo) do |**params|
      puts "I’d been called. Params: #{params.inspect}"
    end.on_hook do |*args|
      puts "Hook: #{args}"
    end
    sleep 3
    class Hooked < Test
    end

    expect { Hooked.new.yo(42) }.not_to raise_error
    expect(Hooked.new.yo(42)).to eq [42, [], {}, nil]
    expect { Hooked.new.yo(42) }.to output(/:class=>Hooked/).to_stdout
  end

  it 'may be applied to an instance' do
    Kungfuig::Prepender.anteponer test, :yo do |**params|
      puts "I’d been called. Params: #{params.inspect}"
    end
    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(Test.new.yo(42)).to eq [42, [], {}, nil]
    expect { test.yo(42) }.to output(/Class:#<Test:0x0/).to_stdout
    expect { test.yo(42) }.to output(/:receiver=>#<Test:0x0/).to_stdout
  end
end
