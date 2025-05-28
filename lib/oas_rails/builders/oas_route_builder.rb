module OasRails
  module Builders
    class OasRouteBuilder
      def self.build_from_rails_route(rails_route)
        new(rails_route).build
      end

      def initialize(rails_route)
        @rails_route = rails_route
      end

      def build
        OasRoute.new(
          controller_class: controller_class,
          controller_action: controller_action,
          controller: controller,
          controller_path: controller_path,
          method: method,
          verb: verb,
          path: path,
          rails_route: @rails_route,
          docstring: docstring,
          source_string: source_string,
          tags: tags
        )
      end

      private

      def controller_class
        "#{@rails_route.defaults[:controller].camelize}Controller"
      end

      def controller_action
        "#{controller_class}##{@rails_route.defaults[:action]}"
      end

      def controller
        @rails_route.defaults[:controller]
      end

      def controller_path
        Rails.root.join("app/controllers/#{controller}_controller.rb").to_s
      end

      def method
        @rails_route.defaults[:action]
      end

      def verb
        @rails_route.verb
      end

      def path
        Extractors::RouteExtractor.clean_route(@rails_route.path.spec.to_s)
      end

      def source_string
        controller_class.constantize.instance_method(method).source
      end

      def docstring
        comment_lines = controller_class.constantize.instance_method(method).comment.lines
        processed_lines = comment_lines.map { |line| line.sub(/^# /, '') }

        filtered_lines = processed_lines.reject do |line|
          line.include?('rubocop') ||
            line.include?('TODO')
        end

        ::YARD::Docstring.parser.parse(filtered_lines.join).to_docstring
      end

      def tags
        method_comment = controller_class.constantize.instance_method(method).comment
        class_comment = extract_class_comment(controller_class.constantize)

        method_tags = parse_tags(method_comment)
        class_tags = parse_tags(class_comment)

        method_tags + class_tags
      end

      def extract_class_comment(klass)
        # Ruby 2.7 compatible way to get class comments
        # Get the file path where the class is defined
        file_path = klass.instance_method(method).source_location.first
        return "" unless file_path && File.exist?(file_path)
      
        # Read the file and extract comments above the class definition
        file_content = File.read(file_path)
        class_name = klass.name.split("::").last
        if (match = file_content.match(/^\s*#\s*(.*?)\s*class\s+#{class_name}/m))
          match[1].to_s
        else
          ""
        end
      rescue StandardError => e
        Rails.logger.warn("Failed to extract class comment: #{e.message}") if defined?(Rails) && Rails.logger
        ""
      end

      def parse_tags(comment)
        lines = comment.lines.map { |line| line.sub(/^# /, '') }
        ::YARD::Docstring.parser.parse(lines.join).tags
      end
    end
  end
end
