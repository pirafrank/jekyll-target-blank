# frozen_string_literal: true

require "jekyll"
require "nokogiri"
require "uri"

module Jekyll
  class TargetBlank
    BODY_START_TAG = "<body"
    OPENING_BODY_TAG_REGEX = %r!<body(.*)>\s*!

    class << self
      # Public: Processes the content and updated the external links
      # by adding the target="_blank" attribute.
      #
      # content - the document or page to be processes.
      def process(content)
        @site_url = content.site.config['url']

        return unless content.output.include?("<a")
        if content.output.include? BODY_START_TAG
          content.output = process_html(content)
        else
          content.output = process_anchor_tags(content.output)
        end
      end


      # Public: Determines if the content should be processed.
      #
      # doc - the document being processes.
      def processable?(doc)
        (doc.is_a?(Jekyll::Page) || doc.write?) &&
            doc.output_ext == ".html" || (doc.permalink&.end_with?("/"))
      end

      private

      # Private: Processes html content which has a body opening tag.
      #
      # content - html to be processes.
      def process_html(content)
        head, opener, tail = content.output.partition(OPENING_BODY_TAG_REGEX)
        body_content, *rest = tail.partition("</body>")

        processed_markup = process_anchor_tags(body_content)

        content.output = String.new(head) << opener << processed_markup << rest.join

      end

      # Private: Processes the anchor tags and adds the target
      # attribute if the link is external.
      #
      # html = the html which includes the anchor tags.
      def process_anchor_tags(html)
        content = Nokogiri::HTML::DocumentFragment.parse(html)
        anchors = content.css('a[href]')
        anchors.each do |item|
          if external?(item['href'])
            item['target'] = '_blank'
          end
        end
        content.to_html
      end

      # Private: Checks if the links points to a host
      # other than that set in Jekyll's configuration.
      #
      # link - a url.
      def external?(link)
        if link =~ /\A#{URI.regexp(['http', 'https'])}\z/
          URI.parse(link).host != URI.parse(@site_url).host
        end
      end
    end
  end
end

# Hooks into Jekyll's post_render event.
Jekyll::Hooks.register %i[pages documents], :post_render do |doc|
  Jekyll::TargetBlank.process(doc) if Jekyll::TargetBlank.processable?(doc)
end
