ruleset wovyn_base {
    meta {
        use module com.jacobeasley.keys
        use module com.jacobeasley.twilio alias twilio
            with account_sid = keys:twilio{"account_sid"}
                 auth_token = keys:twilio{"auth_token"}
        use module sensor_profile
        use module io.picolabs.subscription alias Subscription
    }

    global {
        manager_subscription = function() {
            Subscription:established().filter(function(subscription) {
                subscription{"Tx_role"} == "sensor_collection"
            }).head()
        }
    }

    rule process_heartbeat {
        select when wovyn heartbeat where event:attr("genericThing")

        pre {
            temperature = event:attr("genericThing"){"data"}{"temperature"}[0]{"temperatureF"}
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
            temperature = event:attr("temperature")
            timestamp = event:attr("timestamp")
            violation = temperature > sensor_profile:profile(){"threshold"}
            manager = manager_subscription()
        }

        if violation && manager then
            event:send({
                "eci": manager{"Tx"},
                "domain": "sensor",
                "type": "threshold_violation",
                "attrs": {
                    "temperature": temperature
                }
            }, manager{"Tx_host"}.defaultsTo(meta:host))

        always {
            raise wovyn event "threshold_violation" attributes {
                "temperature": temperature,
                "timestamp": timestamp
            } if violation;
        }
    }
}