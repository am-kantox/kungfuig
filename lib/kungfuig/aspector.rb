require_relative '../kungfuig'

module Kungfuig
  # Generic helper for massive attaching aspects
  module Aspector
    # Helper methods
    class H
      def value_to_method_list klazz, values_inc, values_exc
        [values_inc, values_exc].map do |v|
          v = [*v].map(&:to_sym)
          case
          when v.empty? then []
          when v.include?(:'*') then klazz.instance_methods(false)
          else klazz.instance_methods & v
          end
        end.reduce(&:-)
      end
    end

    def attach(to, before: nil, after: nil, exclude: nil)
      raise ArgumentError, "Trying to attach nothing to #{klazz}. I need a block!" unless block_given?

      klazz = to.is_a?(Class) ? to : class << to; self; end # attach to klazz’s eigenclass if object given

      klazz.send(:include, Kungfuig::Aspector) unless klazz.ancestors.include? Kungfuig::Aspector
      cb = Proc.new

      H.new.value_to_method_list(klazz, before, exclude).each do |m|
        klazz.aspect(m, false, &cb)
      end unless before.nil?

      H.new.value_to_method_list(klazz, after, exclude).each do |m|
        klazz.aspect(m, true, &cb)
      end unless after.nil?

      klazz.aspects
    end
    module_function :attach

    private_constant :H
  end
end
