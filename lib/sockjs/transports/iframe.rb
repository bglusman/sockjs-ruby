# encoding: utf-8

require "digest/md5"
require "sockjs/transport"

module SockJS
  module Transports
    class IFrame < Transport
      register 'GET', %r{/iframe.*[.]html?}

      BODY = <<-EOB.freeze
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <script>
    document.domain = document.domain;
    _sockjs_onload = function(){SockJS.bootstrap_iframe();};
  </script>
  <script src="{{ sockjs_url }}"></script>
</head>
<body>
  <h2>Don't panic!</h2>
  <p>This is a SockJS hidden iframe. It's used for cross domain magic.</p>
</body>
</html>
      EOB

      def setup_response(request, response)
        response.set_content_type(:html)
        response.set_header("ETag", self.etag)
        response.set_cache_control
        response.write(body)
        response
      end

      def body
        @body ||= BODY.gsub("{{ sockjs_url }}", options[:sockjs_url])
      end

      def digest
        @digest ||= Digest::MD5.new
      end

      def etag
        '"' + digest.hexdigest(body) + '"'
      end

      # Handler.
      def handle_request(request)
        if request.fresh?(etag)
          SockJS.debug "Content hasn't been modified."
          empty_response(request, 304)
        else
          SockJS.debug "Deferring to Transport"
          super
        end
      end
    end
  end
end
