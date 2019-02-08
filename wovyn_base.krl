ruleset wovyn_base {
    meta {
        use module com.jacobeasley.keys
        use module com.jacobeasley.twilio alias twilio
            with account_sid = keys:twilio{"account_sid"}
                 auth_token = keys:twilio{"auth_token"}
    }

    global {
        temperature_threshold = 60
        notification_phone = "+17072926097"
    }

    rule process_heartbeat {
        select when wovyn heartbeat where event:attr("genericThing")

        pre {
            temperature = event:attr("genericThing"){"data"}{"temperature"}[0]
        }

        send_directive("temperature_heartbeat", {
            "temperature": temperature
        })

        always {
            raise wovyn event "new_temperature_reading"
                attributes {
                    "temperature": temperature,
                    "timestamp": time:now()
                }
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading

        pre {
            temperature = event:attr("temperature"){"temperatureF"}
            violation = temperature > temperature_threshold
        }

        send_directive("temperature_violation", {
            "violation": violation
        })

        always {
            raise wovyn event "threshold_violation" attributes {
                "temperature": temperature
            } if violation;
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation

        pre {
            temperature = event:attr("temperature")
        }

        twilio:send_sms(notification_phone, twilio:default_from_number, "Temperature Violation: " + temperature)
    }
}