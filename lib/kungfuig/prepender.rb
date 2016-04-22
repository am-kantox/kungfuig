module Kungfuig
  class Prepender
    class MalformedTarget < StandardError
      def initialize msg, args
        super "#{msg}. Target arguments: [#{args.inspect}]."
      end
    end

    AGRESSIVE_ERRORS = true

    class << self
      def errors
        @errors ||= []
      end

      def error! hash, e
        errors << [hash, e]
      end

      def anteponer *args
        raise MalformedTarget.new "Factory requires a block; use Prepender#new for more accurate tuning", args unless block_given?
        Prepender.new(*args, &Proc.new)
      end
    end

    # Parameters might be:
    # • 1
    #   — method instance
    #   — string in form "Class#method"
    # • 2
    #   — class (String, Symbol or Class), method name (String, Symbol)
    #   — instance (Object), method name (String, Symbol)
    def initialize *args, **params
      @λ = { before: nil, after: nil, on_hook: nil }
      @klazz, @method, @receiver =  case args.size
                                    when 1
                                      case args.first
                                      when Method then [(class << args.first.receiver ; self ; end), args.first.name, args.first.receiver]
                                      when UnboundMethod then [args.first.owner, args.first.name]
                                      when String
                                        k, m = args.first.split('#')
                                        [k, m && m.to_sym]
                                      end
                                    when 2
                                      case args.first
                                      when Module, String then [args.first, args.last.to_sym]
                                      when Symbol then [args.first.to_s.split('_').map(&:capitalize).join, args.last.to_sym]
                                      else
                                        [(class << args.first ; self ; end), args.last.to_sym, args.first]
                                      end
                                    end

      @options = params
      after(Proc.new) if block_given? # assign the block to after by default

      raise MalformedTarget.new "Unable to lookup class", args unless @klazz
      raise MalformedTarget.new "Unable to lookup method", args unless @method

      postpone_hook
    end

    def before λ = nil
      @λ[__callee__] = λ || (block_given? ? Proc.new : nil)
      self
    end
    alias_method :after, :before
    alias_method :on_hook, :before

    protected

    def klazz
      return @klazz if @klazz.is_a?(Module)
      @klazz = Kernel.const_get(@klazz) if Kernel.const_defined?(@klazz)
      @klazz
    end

    def ready?
      @receiver && @receiver.respond_to?(@method) ||
        klazz.is_a?(Module) && klazz.instance_methods.include?(@method)
    end

    def to_hash
      {
        class: klazz,
        method: @method,
        receiver: @receiver,
        lambdas: @λ
      }
    end

    def hook
      status = false

      λ = (hash = to_hash).delete(:lambdas)

      p = Module.new do
        define_method(hash[:method]) do |*args, **params, &cb|
          begin
            λ[:before].call(hash.merge!(args: args, params: params, cb: cb)) if λ[:before]
          rescue => e
            Kungfuig::Prepender.error! hash, e
          end

          super(*args, **params, &cb).tap do |result|
            begin
              λ[:after].call(hash.merge!(result: result)) if λ[:after]
            rescue => e
              Kungfuig::Prepender.error! hash, e
            end
          end
        end
      end
      klazz.send :prepend, p

    rescue => e
      status = e
      raise MalformedTarget.new e.message, "#{@klazz}##{@method}" if AGRESSIVE_ERRORS
    ensure
      λ[:on_hook].call(status) if λ[:on_hook]
    end

    def postpone_hook
      return hook if ready?

      TracePoint.new(:end) do |tp|
        if tp.self.name == @klazz && ready?
          hook
          tp.disable
        end
      end.enable
    end
  end
end
