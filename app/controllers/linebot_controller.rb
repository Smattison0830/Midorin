require "json"
require "net/http"
require "uri"
require "tempfile"

class LinebotController < ApplicationController

  protect_from_forgery except: :callback

  def callback
    body = request.body.read

    signature = request.env["HTTP_X_LINE_SIGNATURE"]
    unless client.validate_signature(body, signature)
      error 400 do "Bad Request" end
    end
    events = client.parse_events_from(body)
    events.each do |event|
      # Focus on the message events (including text, image, emoji, vocal.. messages)
      return if event.class != Line::Bot::Event::Message

      case event.type
      # when receive a text message
      when Line::Bot::Event::MessageType::Text
        user_name = ""
        user_id = event["source"]["userId"]
        response = client.get_profile(user_id)
        if response.class == Net::HTTPOK
          contact = JSON.parse(response.body)
          p contact
          user_name = contact["displayName"]
        else
          # Can't retrieve the contact info
          p "#{response.code} #{response.body}"
        end

      # The answer mecanism is here!
        send_bot_message(
          bot_answer_to(event.message["text"], user_name),
          client,
          event
        )
      end
    end
    "OK"
  end

  private

  def send_bot_message(message, client, event)
    message_hash = { type: "text", text: message }
    client.reply_message(event["replyToken"], message_hash)

    # Log prints
    # p 'Bot message sent!'
    # p event["replyToken"]
    # p message_hash
    # p client

  end

  def bot_answer_to(a_question, user_name)
  # Only answer to messages with "bob"
    if a_question.match?(/say (hello|hi) to/i)
      "Hello #{a_question.match(/say (hello|hi) to (.+)\b/i)[2]}!!"
    elsif a_question.match?(/(Hi|Hey|Bonjour|Hi there|Hey there|Hello).*/i)
      "Hello " + user_name + ", how are you doing today?"
    elsif a_question.match?(/how\s+.*are\s+.*you.*/i)
      "I am fine, " + user_name
    elsif a_question.end_with?('?')
      "Good question, " + user_name + "!"
    else
      ["I couldn't agree more.", "Great to hear that.", "Kinda makes sense."].sample
    end
  end

end
