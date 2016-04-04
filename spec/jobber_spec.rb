require 'spec_helper'
require 'rspec-sidekiq'
require 'kungfuig/jobber'

class TestWorker
  include Sidekiq::Worker

  def perform(receiver, method, result, *args)
    Kungfuig.✍("TestWorker :: got #{receiver.inspect} while", method, result, *args) unless receiver.is_a?(Test) && method.to_s == 'yo'
  end
end

describe Kungfuig::Jobber do
  let(:test) { Test.new }

  it 'accepts YAML for bulk jobber' do
    yaml = <<YAML
'Test':
  'yo': 'TestWorker'
YAML
    bulk = Kungfuig::Jobber.bulk(yaml)
    expect(bulk).to be_truthy
    expect(bulk.inspect).to match(/"Test"=>\[\{:yo=>\{:after=>\[#<Proc:/)

    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
    expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
  end

  it 'logs an error but does not fail on wrong aspects in YAML for bulk jobber' do
    yaml = <<YAML
'Test':
  'yo': 'TestWorkerHARM'
YAML
    expect(Kungfuig::Jobber.bulk(yaml).inspect).to match(/"Test"=>\[\{:yo=>\{:after=>\[#<Proc:/)

    expect(test.yo(42)).to eq [42, [], {}, nil] # prints a backtrace
  end

  it 'schedules sidekiq jobs on execution' do
    yaml = <<YAML
'Test':
  'yo': 'TestWorker'
YAML
    expect(Kungfuig::Jobber.bulk(yaml)).to be_truthy
    expect(TestWorker.jobs.size).to eq 0

    [[42], [42, :p1, :p2], [42, :p1, :p2, sp1: 1, sp2: 1]].each.with_index do |args, idx|
      expect(TestWorker.jobs.size).to eq idx
      expect(test.yo(args)).to be_truthy
      sleep 0.5
      expect(TestWorker.jobs.size).to eq(idx + 1)
    end
    expect(TestWorker.jobs.size).to eq 3
    TestWorker.drain
    expect(TestWorker.jobs.size).to eq 0
  end
end
