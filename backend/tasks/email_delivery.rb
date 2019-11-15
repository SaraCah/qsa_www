require 'html2text'

class EmailDelivery
  attr_accessor :email_subject, :data, :email_content, :recipients, :cc_recipients, :reply_to_addresses

  def initialize(email_subject, email_content, recipients, cc_recipients = [], reply_to_addresses = [])
    @email_subject = email_subject
    @data = data
    @recipients = recipients
    @cc_recipients = cc_recipients
    @reply_to_addresses = reply_to_addresses
    @email_content = email_content
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
    body = email_content
    plaintext_body = Html2Text.convert(body)

    msg = Mail.new do
      to to
      cc cc
      from AppConfig[:email_from_address]
      reply_to reply_to
      subject subject
      html_part do
        content_type 'text/html;charset=UTF-8'
        body body
      end

      text_part do
        body plaintext_body
      end
    end

    if AppConfig[:email_enabled]
      msg.deliver
    else
      Log.info(msg)
    end
  end

end
