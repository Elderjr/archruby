module ArchChecker
  module Architecture
    
    class ModuleDefinition
      
      ALLOWED_CONSTRAINTS = ['required', 'allowed', 'forbidden']
      
      attr_reader :name, :allowed_modules, :required_modules, :forbidden_modules,
      :classes, :dependencies, :classes_and_dependencies
      
      def initialize config_definition, base_directory
        @config_definition = config_definition
        @name = @config_definition.module_name
        @allowed_modules = @config_definition.allowed_modules
        @required_modules = @config_definition.required_modules
        @forbidden_modules = @config_definition.forbidden_modules
        @base_directory = base_directory
        @files_and_contents = []
        @classes = []
        @dependencies = []
        @classes_and_dependencies = []
        extract_content_of_files
        extract_dependencies        
      end
            
      def extract_content_of_files file_extractor = ArchChecker::Architecture::FileContent
        file_extractor = file_extractor.new(@base_directory)
        @config_definition.files.each do |file|
          file_content = file_extractor.all_content_from_directory file
          @files_and_contents << file_content
        end
      end
      
      def extract_dependencies ruby_parser = ArchChecker::Ruby::Parser
        @files_and_contents.each do |file_and_content|
          file_and_content.each do |file_name, content|
            parser = ruby_parser.new content
            @classes << parser.classes
            @dependencies << parser.dependencies
            @classes_and_dependencies << parser.classes_and_dependencies
          end
        end
        @classes << @config_definition.gems
        @classes.flatten!
        @dependencies.flatten!
      end
      
      def is_mine? class_name
        class_name = class_name.split('::').first
        @classes.each do |klass|
          #TODO Arrumar isso com uma expressao regular
          if klass.include?(class_name) && klass.size == class_name.size
            return true
          end
        end
        return false
      end
      
      def is_external?
        !@config_definition.gems.empty?
      end
      
      def is_empty?
        @classes.empty?
      end
      
      def verify_constraints architecture
        required_breaks = verify_required architecture
        forbidden_breaks = verify_forbidden architecture
        allowed_breaks = verify_allowed architecture
        all_constraints_breaks = [required_breaks, forbidden_breaks, allowed_breaks].flatten
        all_constraints_breaks.delete(nil)
        all_constraints_breaks
      end
                  
      # Verifica todas as classes do modulo
      # Cada uma deve, de alguma forma, depender dos modulos que estao listados como required
      def verify_required architecture
        return if @config_definition.required_modules.empty?
        breaks = []
        @classes_and_dependencies.each_with_index do |class_and_depencies, index|
          if class_and_depencies.empty?
            breaks << ArchChecker::Architecture::ConstraintBreak.new(:type => 'absence', :module_origin => self.name, :module_target => @config_definition.required_modules.first, :class_origin => @classes[index], :msg => "not implement a required module")  
            next
          end
          class_and_depencies.each do |class_name, dependencies|
            dependency_module_names = []
            dependencies.each do |dependency|
              module_name = architecture.module_name(dependency.class_name)
              dependency_module_names << module_name
            end
            @config_definition.required_modules.each do |required_module|
              if !dependency_module_names.include?(required_module)
                breaks << ArchChecker::Architecture::ConstraintBreak.new(:type => 'absence', :module_origin => self.name, :module_target => required_module, :class_origin => class_name, :msg => "not implement a required module")
              end
            end
          end
        end        
        breaks
      end

      def verify_forbidden architecture
        return if @config_definition.forbidden_modules.empty?
        breaks = []
        @classes_and_dependencies.each do |class_and_depencies|
          class_and_depencies.each do |class_name, dependencies|
            dependencies.each do |dependency|
              module_name = architecture.module_name(dependency.class_name)
              if @config_definition.forbidden_modules.include? module_name
                breaks << ArchChecker::Architecture::ConstraintBreak.new(:type => 'divergence', :class_origin => class_name, :line_origin => dependency.line_number, :class_target => dependency.class_name, :module_origin => self.name, :module_target => module_name, :msg => "accessing a module which is forbidden")
              end
            end
          end
        end
        breaks        
      end
      
      def verify_allowed architecture
        return if @config_definition.allowed_modules.empty?
        breaks = []
        @classes_and_dependencies.each do |class_and_depencies|
          class_and_depencies.each do |class_name, dependencies|
            dependencies.each do |dependency|
              module_name = architecture.module_name(dependency.class_name)
              if module_name != self.name && !@config_definition.allowed_modules.include?(module_name)
                breaks << ArchChecker::Architecture::ConstraintBreak.new(:type => 'divergence', :class_origin => class_name, :line_origin => dependency.line_number, :class_target => dependency.class_name, :module_origin => self.name, :module_target => module_name, :msg => "accessing a module not allowed")
              end
            end
          end
        end
        breaks
      end

    end
  end
end