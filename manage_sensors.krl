ruleset manage_sensors {
    meta {
        shares __testing, sensors
    }

    global {
        __testing = {
            "queries": [
                {
                    "name": "__testing"
                }
            ],
            "events": [
                {
                    "domain": "sensor",
                    "type": "new_sensor",
                    "attrs": [
                        "name"
                    ]
                },
                {
                    "domain": "sensor",
                    "type": "unneeded_sensor",
                    "attrs": [
                        "name"
                    ]
                }
            ]
        }

        sensors = function() {
            ent:sensors.defaultsTo({})
        }

        picoName = function(sensor_name) {
            sensor_name + " Sensor Pico"
        }

        default_notification_phone = "+17072926097"
        default_threshold = 60
    }

    rule add_sensor {
        select when sensor new_sensor

        pre {
            name = event:attr("name")
            exists = ent:sensors >< name
        }

        if exists then
            send_directive("name_exists", {
                "name": name
            })

        notfired {
            raise wrangler event "child_creation" attributes {
                "name": picoName(name),
                "color": "#3F51B5",
                "sensor_name": name
            }
        }
    }

    rule store_sensor {
        select when wrangler child_initialized

        pre {
            eci = event:attr("eci")
            sensor_name = event:attr("rs_attrs"){"sensor_name"}
        }

        event:send({
            "eci": eci,
            "eid": "install-rulesets",
            "domain": "wrangler",
            "type": "install_rulesets_requested",
            "attrs": {
                "rids": [
                    "temperature_store",
                    "wovyn_base",
                    "sensor_profile"
                ]
            }
        })

        fired {
            ent:sensors := sensors();
            ent:sensors{[sensor_name]} := eci;

            raise sensor event "stored" attributes {
                "eci": eci,
                "sensor_name": sensor_name
            }
        }
    }

    rule initialize_profile {
        select when sensor stored

        pre {
            eci = event:attr("eci")
            sensor_name = event:attr("sensor_name")
        }

        event:send({
            "eci": eci,
            "eid": "initialize-profile",
            "domain": "sensor",
            "type": "profile_updated",
            "attrs": {
                "name": sensor_name,
                "location": "",
                "phone": default_notification_phone,
                "threshold": default_threshold
            }
        })
    }

    rule delete_sensor {
        select when sensor unneeded_sensor

        pre {
            name = event:attr("name")
            exists = sensors() >< name
            pico_name = picoName(name)
        }

        if exists then
            send_directive("deleting_sensor", {
                "name": name
            })

        fired {
            raise wrangler event "child_deletion" attributes {
                "name": pico_name
            };

            clear ent:sensors{[name]}
        }
    }
}