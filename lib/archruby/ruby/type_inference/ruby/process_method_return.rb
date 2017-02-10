module Archruby
  module Ruby
    module TypeInference
      module Ruby
        class ProcessMethodReturn < SexpInterpreter
          
          def self.check(class_definitions)
            class_definitions.each do |class_name, class_definition|
              class_definition.all_methods.each do |method|
                self.analyse_return_method(method, class_definitions)
                puts "Tipos de retorno de #{method.complete_name}: #{method.return_types.to_a}"
              end
            end
          end

          def self.analyse_return_method(method, class_definitions)
             while(method.return_exps.size > 0)
              exp = method.return_exps.pop
              returns = Ruby::ProcessMethodReturn.new(method, exp, class_definitions).parse
              method.return_types.merge(returns)
            end
          end
          
          def initialize(method, ast, class_definitions)
            super()
            @method = method
            @ast = ast
            @class_definitions = class_definitions            
            @types = Set.new
          end

          def parse
            process(@ast)
            @types
          end

          def update_types(types_set, method_called)
            @types = Set.new
            types_set.each do |class_name|
              if(@class_definitions.has_key?(class_name))
                @class_definitions[class_name].all_methods.each do |method|
                  if(method.method_name == method_called)
                    Archruby::Ruby::TypeInference::Ruby::ProcessMethodReturn.analyse_return_method(method, @class_definitions)
                    @types = method.return_types
                  end
                end
              end
            end
          end

          def process_lvar(exp)
            if(@method.var_types.has_key?(exp[1]))
              @types = @method.var_types[exp[1]]
            elsif(@method.var_to_analyse.has_key?(exp[1]))
              @types = Ruby::ProcessMethodReturn.new(@method, @method.var_to_analyse[exp[1]],@class_definitions).parse
            end
          end

          def process_false(exp)
            @types = Set.new
            @types.add(false.class)
          end

          def process_str(exp)
            @types = Set.new
            @types.add("String")
          end
          
          #s(:return, s(:call, s(:call, s(:lvar, :b), :instance), :returnString))))
          def process_call(exp)
            _, values, method_called = exp
            process(values)
            update_types(@types, method_called)
          end

        end
      end
    end
  end
end