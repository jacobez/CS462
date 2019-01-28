ruleset com.jacobeasley.sms {
    meta {
        use module com.jacobeasley.keys
        use module com.jacobeasley.twilio alias twilio
            with account_sid = keys:twilio{"account_sid"}
                 auth_token = keys:twilio{"auth_token"}
        
        shares __testing
    }

    global {
        __testing = {
            "queries": [
                { "name": "send_sms" }
            ],
            "events": [
                {
                    "domain": "messages",
                    "type": "new",
                    "attrs": ["to", "from", "message"]
                }
            ]
        }
    }

    rule send_sms {
        select when messages new

        twilio:send_sms(event:attr("to"), event:attr("from"), event:attr("message"))
    }
}