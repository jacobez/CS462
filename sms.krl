ruleset com.jacobeasley.sms {
    meta {
        use module com.jacobeasley.keys
        use module com.jacobeasley.twilio alias twilio
            with account_sid = keys:twilio{"account_sid"}
                 auth_token = keys:twilio{"auth_token"}
        
        shares __testing, messages
    }

    global {
        __testing = {
            "queries": [
                { "name": "messages", "args": ["paginate", "next_page_uri", "sender", "recipient"] }
            ],
            "events": [
                {
                    "domain": "messages",
                    "type": "new",
                    "attrs": ["to", "from", "message"]
                }
            ]
        }

        messages = function(paginate = false, next_page_uri = null, sender = "", recipient = "") {
            twilio:query_messages(paginate, next_page_uri, sender, recipient)
        }
    }

    rule send_sms {
        select when messages new

        twilio:send_sms(event:attr("to"), event:attr("from"), event:attr("message"))
    }
}