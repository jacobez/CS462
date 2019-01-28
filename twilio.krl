ruleset com.jacobeasley.twilio {
    meta {
        configure using account_sid = ""
                        auth_token = ""
        
        provides query_messages, send_sms
    }

    global {
        base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
        
        query_messages = function() {
            http:get(base_url + "Messages.json"){"content"}
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