ruleset com.jacobeasley.twilio {
    meta {
        configure using account_sid = ""
                        auth_token = ""
        
        provides query_messages, send_sms, default_from_number
    }

    global {
        default_from_number = "+17075040839"

        base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>

        build_filter = function(sender, recipient) {
            sender_filter = sender => {
                "From": sender
            } | {};

            recipient => sender_filter.put(["To"], recipient) | sender_filter
        }
        
        compile_pages = function(messages, next_page_uri) {
            response_content = next_page_uri => http:get(next_page_uri){"content"}.decode() | next_page_uri;
            next_page_uri => compile_pages(messages.append(response_content{"messages"}), response_content{"next_page_uri"}) 
                                | messages
        }
        
        query_messages = function(paginate, page_uri, sender, recipient) {
            request_url = page_uri => page_uri | (base_url + "Messages.json");
            filter = build_filter(sender, recipient);
            response_content = http:get(request_url, qs = filter){"content"}.decode();
            paginate => {
                "messages": response_content{"messages"},
                "next_page_uri": response_content{"next_page_uri"}
            } | compile_pages(response_content{"messages"}, response_content{"next_page_uri"})
        }

        send_sms = defaction(to, from, message) {
            http:post(base_url + "Messages.json", form = {
                "From": from,
                "To": to,
                "Body": message
            })
        }
    }
}