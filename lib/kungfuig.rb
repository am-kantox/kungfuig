require 'kungfuig/version'
require 'yaml'
require 'hashie'

module Kungfuig
  MX = Mutex.new

  module InstanceMethods
    # Configures everything by hash or yaml from string or file. Whether code block
    #   is passed, it is processed with @options instance.
    # @param hos [String|Hash|Hashie::Mash] the input data to merge into options
    def config hos = nil
      MX.synchronize {
        merge_hash_or_string! hos
        yield options if block_given?
        options
      }
    end

    # Options getter
    # @return [Hashie::Mash] options
    def options
      @options ||= Hashie::Mash.new
    end
    private :options

    # Accepts:
    #     option :foo, :bar: baz
    #     option [:foo, 'bar', 'baz']
    #     option 'foo.bar.baz'
    #     option 'foo::bar::baz'
    def option *keys
      key = keys.join('.').gsub(/::/, '.').split('.')

      MX.synchronize {
        # options.foo!.bar!.baz!
        build = [key, key[1..-1]].map do |candidate|
          candidate.inject(options.dup) do |memo, k|
            memo.public_send("#{k}") unless memo.nil?
          end
        end.reduce(nil) do |memo, candidate|
          memo || candidate
        end
      }
    end

    # Accepts:
    #     option! [:foo, 'bar', 'baz'], value
    #     option! 'foo.bar.baz', value
    #     option! 'foo::bar::baz', value
    def option! keys, value
      key = (keys.is_a?(Array) ? keys.join('.') : keys).gsub(/::/, '.').split('.')
      last = key.pop

      MX.synchronize {
        # options.foo!.bar!.baz! = value
        build = key.inject(options) do |memo, k|
          memo.public_send("#{k}!")
        end
        build[last] = value
      }
    end

    def option? *keys
      !option(*keys).nil?
    end

    # @param hos [Hash|String] the new values taken from hash,
    #   mash or string (when string, should be either valid YAML file name or
    #   string with valid YAML)
    def merge_hash_or_string! hos
      options.deep_merge! case hos
                          when NilClass then {} # aka skip
                          when Hash then hos
                          when String
                            begin
                              File.exists?(hos) ? Hashie::Mash.load(hos) : Hashie::Mash.new(YAML.load(hos))
                            rescue ArgumentError => ae
                              fail ArgumentError.new "#{__callee__} expects valid YAML configuration file. [#{hos}] contains invalid syntax."
                            rescue Psych::SyntaxError => pse
                              fail ArgumentError.new "#{__callee__} expects valid YAML configuration string. Got:\n#{hos}"
                            end
                          else
                            fail ArgumentError.new "#{__callee__} accepts either String or Hash as parameter."
                          end
    end
    private :merge_hash_or_string!
  end

  def self.included base
    base.include InstanceMethods
    base.extend ClassMethods
    if (base.instance_methods & [:[], :[]=]).empty?
      base.send :alias_method, :[], :option
      base.send :alias_method, :[]=, :option!
    end
  end

  def self.extended base
    base.include ClassMethods
  end

  module ClassMethods
    include InstanceMethods

    # A wrapper for the configuration block
    # @param block the block to be executed in the context of this module
    def kungfuig &block
      instance_eval(&block)
    end

    def plugin meth
      fail ArgumentError.new "Plugin must have a codeblock" unless block_given?
      fail NoMethodError.new "Plugin must be attached to existing method" unless instance_methods.include? meth.to_sym

      ((@plugins ||= {})[meth.to_sym] ||= []) << Proc.new
      plugins = @plugins
      class_eval do
        unless instance_methods(true).include?(:"∃#{meth}")
          alias_method :"∃#{meth}", meth.to_sym
          define_method meth.to_sym do |*args|
            send(:"∃#{meth}", *args).tap do |result|
              plugins[meth.to_sym].each do |p|
                p.call result
              end
            end
          end
        end

      end
    end
    alias_method :set, :option!
  end
end
