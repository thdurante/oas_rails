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
      rescue ::MethodSource::SourceNotFoundError => _e
        ''
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

        Rails.logger.debug("[#{method}] Method comment: #{method_comment}")

        method_tags = parse_tags(method_comment)
        class_tags = parse_tags(class_comment)

        Rails.logger.debug("[#{method}] Method tags: #{method_tags.inspect}")
        Rails.logger.debug("[#{method}] Class tags: #{class_tags.inspect}")

        method_tags + class_tags
      end

      def extract_class_comment(klass)
        instance_method = klass.instance_method(method)
        return instance_method.class_comment if instance_method.respond_to?(:class_comment)

        # Ruby 2.7 compatibility fallback
        ''
      end

      def parse_tags(comment)
        lines = comment.lines.map { |line| line.sub(/^# /, '') }
        ::YARD::Docstring.parser.parse(lines.join).tags
      end
    end
  end
end
