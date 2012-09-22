# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports

    # This is the receiver.
    class JSONP < Transport
      register '/jsonp', 'GET'

      #XXX May cause issues with single transport
      #Move callback_function to response?
      attr_accessor :callback_function

      # Handler.
      def handle(request)
        if request.callback
          self.callback_function = request.callback

          if session = self.connection.sessions[session_key(request)]
            response(request, 200) do |response, session|
              response.set_content_type(:plain)

              session.process_buffer
            end
          else
            response(request, 200, session: :create) do |response, session|
              response.set_content_type(:javascript)
              response.set_access_control(request.origin)
              response.set_no_cache
              response.set_session_id(request.session_id)

              session.open!(request.callback)
            end
          end
        else
          response(request, 500) do |response|
            response.set_content_type(:html)
            response.write('"callback" parameter required')
          end
        end
      end

      def format_frame(payload)
        raise TypeError.new("Payload must not be nil!") if payload.nil?

        # Yes, JSONed twice, there isn't a better way, we must pass
        # a string back, and the script, will be evaled() by the browser.
        "#{self.callback_function}(#{payload.chomp.to_json});\r\n"
      end
    end

    # This is the sender.
    class JSONPSend < Transport
      register '/jsonp_send', 'POST'

      # Handler.
      def handle_request(request)
        if request.content_type == "application/x-www-form-urlencoded"
          self.handle_form_data(request)
        else
          self.handle_raw_data(request)
        end
      end

      def handle_form_data(request)
        raw_data = request.data.read || empty_payload
        data = URI.decode_www_form(raw_data)

        # It always has to be d=something.
        if data && data.first && data.first.first == "d"
          data = data.first.last
          empty_payload if data.empty?
          self.handle_clean_data(request, data)
        else
          empty_payload
        end
      end

      def handle_raw_data(request)
        raw_data = request.data.read
        if raw_data && raw_data != ""
          self.handle_clean_data(request, raw_data)
        else
          empty_payload
        end
      end

      def handle_clean_data(request, data)
        response(request, 200) do |response, session|
          if session
            session.receive_message(request, data)

            response.set_content_type(:plain)
            response.set_session_id(request.session_id)
            response.write("ok")
          else
            raise SockJS::HttpError.new(404, "Session is not open!") { |response|
              response.set_content_type(:plain)
              response.set_session_id(request.session_id)
            }
          end
        end
      end

      def empty_payload
        raise SockJS::HttpError.new(500, "Payload expected.") { |response|
          response.set_content_type(:html)
        }
      end
    end
  end
end
