ruleset sensor_profile {
    meta {
        provides profile
        shares profile
    }

    global {
        profile = function() {
            {
                "name": ent:name.defaultsTo("Wovyn 1"),
                "location": ent:location.defaultsTo("Jacob Easley's Home"),
                "phone": ent:phone.defaultsTo("+17072926097"),
                "threshold": ent:threshold.defaultsTo(60)
            }
        }
    }

    rule update_profile {
        select when sensor profile_updated

        pre {
            name = event:attr("name")
            location = event:attr("location")
            phone = event:attr("phone")
            threshold = event:attr("threshold")
        }

        send_directive("update_profile", {
            "name": name,
            "location": location,
            "phone": phone,
            "threshold": threshold
        })

        always {
            ent:name := name;
            ent:location := location;
            ent:phone := phone;
            ent:threshold := threshold;
        }
    }
}