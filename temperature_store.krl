ruleset temperature_store {
    meta {
        provides temperatures, inrange_temperatures, threshold_violations
        shares temperatures, inrange_temperatures, threshold_violations
    }

    global {
        temperatures = function() {
            ent:temperatures.defaultsTo([])
        }

        inrange_temperatures = function() {
            ent:temperatures.difference(ent:threshold_violations)
        }

        threshold_violations = function() {
            ent:threshold_violations.defaultsTo([])
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading

        pre {
            temperature = event:attr("temperature")
            timestamp = event:attr("timestamp")
        }

        send_directive("store_temperature", {
            "temperature": temperature,
            "timestamp": timestamp
        })

        always {
            ent:temperatures := temperatures().append({
                "temperature": temperature,
                "timestamp": timestamp
            })
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation

        pre {
            temperature = event:attr("temperature")
            timestamp = event:attr("timestamp")
        }

        send_directive("store_threshold_violation", {
            "temperature": temperature,
            "timestamp": timestamp
        })

        always {
            ent:threshold_violations := threshold_violations().append({
                "temperature": temperature,
                "timestamp": timestamp
            })
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset

        always {
            clear ent:temperatures;
            clear ent:threshold_violations;
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added

        fired {
            raise wrangler event "pending_subscription_approval" attributes event:attrs
        }
    }
}