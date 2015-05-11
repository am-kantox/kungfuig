# Kungfuig

**Kungfuig** (_pronounced: [ˌkʌŋˈfig]_) provides a drastically easy way to plug configuration into everything.

## Usage

```ruby
class MyApp
  include Kungfuig
end

# Load configuration file
MyApp.config('config/myapp.yml')

# Append options explicitly
MyApp.config do |options|
  options.value = 42
end

# load options from JSON file and execute block on it
MyApp.config('config/myapp.json') do |options|
  options.other_value = options[:value]
end

# DSL (note `configure` method name)
MyApp.configure do
  set :value, 42
end
```

### Plugin to be called on method execution

```ruby
class MyApp
  include Kungfuig
  def report
    # ...
    42
  end
end

MyApp.configure do
  plugin :report do |result|
    puts "MyApp#report returned #{result}"
  end
end

MyApp.new.report
#⇒ "MyApp#report returned 42"
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
