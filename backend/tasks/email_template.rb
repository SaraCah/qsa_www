class EmailTemplates

  def self.render(page_name, replacements = {})
    page_content = nil

    PublicDB.open do |publicdb|
      page = publicdb[:page]
        .filter(:deleted => 0)
        .filter(:slug => page_name)
        .order(Sequel.desc(:create_time))
        .first

      raise "Page not found: #{page_name}" if page.nil?

      page_content = page[:content]
    end

    raise "Page content missing" if page_content.nil?

    replacements.each do |replacement_key, replacement_html|
      page_content = page_content.gsub(/%#{replacement_key}%/, replacement_html)
    end

    page_content = page_content.gsub(/%[A-Z_]+%/, "")
    doc = Nokogiri::HTML.parse(page_content)

    children_iterator = doc.css('body').children.each

    result = []

    begin
      while child = children_iterator.next
        if child.name == 'p' && child.children.length == 1 && child.children[0].name == 'code'
          combined = child.children[0].text

          while next_child = children_iterator.peek
            if next_child.name == 'p' && next_child.children.length == 1 && next_child.children[0].name == 'code'
              combined += next_child.children[0].text
              children_iterator.next
            else
              break
            end
          end

          result << combined
        else
          result << child.to_s
        end
      end
    rescue StopIteration
    end

    result.join
  end

  def self.render_partial(partial_name, locals = {})
    file = File.join(File.absolute_path(__dir__), 'email_replacements', "_#{partial_name}.html.erb")

    unless File.exists?(file)
      raise "File does not exist: #{file}"
    end

    ERBRenderer.new(file, locals).render
  end

  def self.preserve_newlines(string)
    string.gsub(/(?:\n\r?|\r\n?)/, '<br>')
  end

  def self.signature
    render('email-signature', {}).gsub(/<p>/, '<div>').gsub(/<\/p>/, '</div>')
  end
end

class ERBRenderer
  def initialize(erb_file, data)
    @file = erb_file
    @data = data
  end

  def render
    renderer = ERB.new(File.read(@file))
    renderer.result(binding).strip
  end
end