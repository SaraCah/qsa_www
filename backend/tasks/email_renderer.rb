class EmailRenderer
  attr_accessor :data, :template, :file

  def initialize(data, template)
    @data = data
    @file = File.join(File.absolute_path(__dir__), 'email_templates', template)
  end

  def render
    unless File.exists?(file)
      raise "File does not exist: #{file}"
    end

    renderer = ERB.new(File.read(file))
    renderer.result(binding)
  end

end