# [![夫](https://en.wiktionary.org/wiki/%E5%A4%AB)](kungfuig.png) Kungfuig

**Kungfuig** (_pronounced: [ˌkʌŋˈfig]_) provides a drastically easy way to plug configuration into everything.

[![Build Status](https://travis-ci.org/am-kantox/kungfuig.svg\?branch\=master)](https://travis-ci.org/am-kantox/kungfuig)

## Config on steroids

This gem allows to (including but not limited to):

* easily attach a configuration to any class and/or instance;
* attach basic [aspects](https://en.wikipedia.org/wiki/Aspect-oriented_programming)
  to any existing method on `before` and `after` pointcuts;
* bulk attach aspects as defined by `yaml` configuration file
  (see [Bulk aspects assignment](#bulk-aspects-assignment).)
* bulk attach sidekiq jobs as aspects as defined by `yaml` configuration file
  (see [Bulk jobs assignment](#bulk-jobs-assignment).)
* thread-safe configure nested / derived classes / instances.

## Eastern eggs:

* easy way to handle console colors:
  * `Color.to_xterm256('Hello, world!', :info)`
  * `Color.to_xterm256('Hello, world!', :success)`
  * `Color.to_xterm256('Hello, world!', '#FFFF00')`

## Usage

```ruby
class MyApp
  include Kungfuig
end

# Load configuration file
MyApp.kungfuig('config/myapp.yml')

# Append options explicitly
MyApp.kungfuig do |options|
  options.value = 42
end

# load options from JSON file and execute block on it
MyApp.kungfuig('config/myapp.json') do |options|
  options.other_value = options[:value]
end

# DSL (note `kungfuig` method name)
MyApp.kungfuigure do
  set :value, 42
end
```

### Aspect to be called on method execution

```ruby
class MyApp
  include Kungfuig
  def report
    # ...
    42
  end
end

MyApp.kungfuigure do
  aspect :report do |result|  # or just MyApp.aspect :report do |result|
    puts "MyApp#report returned #{result}"
  end
end

MyApp.new.report
#⇒ "MyApp#report returned 42"
```

### Bulk aspects assignment

```ruby
it 'accepts YAML for bulk attach' do
    yaml = <<YAML
'Test':
  after:
    '*': 'MyLogger#debug_after_method_call'
  before:
    'shutdown': 'MyLogger#info_before_shutdown_call'
YAML
expect(Kungfuig::Aspector.bulk(yaml)).to be_truthy
expect(test.yo(42)).to eq ['Answer given']
```

in the example above, `MyLogger#debug_after_method_call` will be called
after _all_ methods of `Test` class, and `MyLogger#info_before_shutdown_call`—before
`Test#shutdown`.

### Bulk jobs assignment

```ruby
Kungfuig::Jobber.bulk("#{Rails.root}/config/my_app.yml")
```

**config/my_app.yml**

```yaml
'SessionsController':
  'login': 'OnLoginJob'
'UsersController':
  'show': 'OnUsersShownJob'
```

in the example above, `OnLoginJob` will be executed after `SessionsController#login`
method is called, and `OnUsersShownJob`—after `UsersController#show`.

### Jobs `perform` format

The job’s `perform` method will be called with four parameters:

```ruby
job.perform_async(receiver, method, result, *args)
```

* `receiver` — the actual method receiver, serialized to the hash (see below);
* `method` — the actual method name;
* `result` — the result of call to the method (`nil` for before filters);
* `args` — arguments, passed to the method; objects will be lost (cast to `String`
  instance as by `Sidekiq` convention.)

```ruby
respond_to = ->(m, r) { r.respond_to? m.to_sym }
r = case receiver
    when Hash, Array, String then receiver
    when respond_to.curry[:to_hash] then receiver.to_hash
    when respond_to.curry[:to_h] then receiver.to_h
    else receiver
    end
job.perform_async(r, method, result, *args)
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kungfuig'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kungfuig

## Include/extend each class/instance you want to have configuration options

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/kungfuig/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
