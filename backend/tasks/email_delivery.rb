class EmailDelivery
  attr_accessor :email_subject, :data, :file, :recipients, :reply_to_addresses

  def initialize(email_subject, data, template, recipients, reply_to_addresses = [])
    @email_subject = email_subject
    @data = data
    @recipients = recipients
    @reply_to_addresses = reply_to_addresses
    @file = File.join(File.absolute_path(__dir__), 'email_templates', template)
  end

  def render
    unless File.exists?(file)
      raise "File does not exist: #{file}"
    end

    renderer = ERB.new(File.read(file))
    renderer.result(binding)
  end

  def send!
    bcc = AppConfig.has_key?(:email_override_recipient) ? ASUtils.wrap(AppConfig[:email_override_recipient]) : recipients
    subject = email_subject
    reply_to = reply_to_addresses
    body = render

    msg = Mail.new do
      bcc bcc
      from AppConfig[:email_from_address]
      reply_to reply_to
      subject subject
      body body
    end

    if AppConfig[:email_enabled]
      msg.deliver
    else
      Log.info(msg)
    end
  end

end