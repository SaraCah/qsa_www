class EmailDelivery
  attr_accessor :email_subject, :data, :file, :recipients, :cc_recipients, :reply_to_addresses

  def initialize(email_subject, data, template, recipients, cc_recipients = [], reply_to_addresses = [])
    @email_subject = email_subject
    @data = data
    @recipients = recipients
    @cc_recipients = cc_recipients
    @reply_to_addresses = reply_to_addresses
    @file = File.join(File.absolute_path(__dir__), 'email_templates', template)
  end

  def render
    unless File.exists?(file)
      raise "File does not exist: #{file}"
    end

    renderer = ERB.new(File.read(file))
    renderer.result(binding).strip
  end

  def send!
    to = AppConfig.has_key?(:email_override_recipient) ? ASUtils.wrap(AppConfig[:email_override_recipient]) : recipients
    cc = AppConfig.has_key?(:email_override_recipient) ? [] : cc_recipients
    reply_to = reply_to_addresses

    # the admin user may perform an action in the public app and as they
    # don't have a real email address, be sure to filter
    to.reject!{|email| email == 'admin'}
    cc.reject!{|email| email == 'admin'}
    reply_to.reject!{|email| email == 'admin'}

    subject = ("%s %s" % [AppConfig[:email_qsa_subject_prefix], email_subject]).strip
    body = render

    msg = Mail.new do
      to to
      cc cc
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