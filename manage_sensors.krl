ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias Wrangler
        use module io.picolabs.subscription alias Subscription
        use module com.jacobeasley.keys
        use module com.jacobeasley.twilio alias twilio
            with account_sid = keys:twilio{"account_sid"}
                auth_token = keys:twilio{"auth_token"}
        use module sensor_profile

        shares __testing, sensors, temperatures
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

        sensor_names = function() {
            ent:sensor_names.defaultsTo({})
        }

        sensors = function() {
            Subscription:established().filter(function(subscription) {
                subscription{"Tx_role"} == "sensor"
            }).reduce(function(a, b) {
                id = b{"Id"};
                sensor_name = ent:sensor_names.get([id]);
                a.put([sensor_name], b)
            }, {})
        }

        temperatures = function() {
            sensors().map(function(v, k) {
                Wrangler:skyQuery(v{"Tx"}, "temperature_store", "temperatures", {}, v{"Tx_host"})
            })
        }

        picoName = function(sensor_name) {
            sensor_name + " Sensor Pico"
        }

        phone = function() {
            sensor_profile:profile(){"phone"}.defaultsTo(default_notification_phone)
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

    rule install_sensor_rulesets {
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
            raise sensor event "rulesets_installed" attributes {
                "eci": eci,
                "sensor_name": sensor_name
            }
        }
    }

    rule subscribe_to_sensor {
        select when wrangler child_initialized

        pre {
            eci = event:attr("eci")
            sensor_name = event:attr("rs_attrs"){"sensor_name"}
        }

        always {
            raise wrangler event "subscription" attributes {
                "name": sensor_name,
                "Rx_role": "sensor_collection",
                "Tx_role": "sensor",
                "channel_type": "subscription",
                "wellKnown_Tx": eci
            }
        }
    }

    rule initialize_profile {
        select when sensor rulesets_installed

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

    rule store_sensor {
        select when wrangler subscription_added

        pre {
            subscription_id = event:attr("Id")
            sensor_name = event:attr("name")
        }

        fired {
            ent:sensor_names := sensor_names();
            ent:sensor_names{[subscription_id]} := sensor_name
        }
    }

    rule introduce_sensor {
        select when sensor introduced

        pre {
            eci = event:attr("eci")
            sensor_name = event:attr("sensor_name")
            host = event:attr("host").defaultsTo(meta:host)
        }

        always {
            raise wrangler event "subscription" attributes {
                "name": sensor_name,
                "Rx_role": "sensor_collection",
                "Tx_role": "sensor",
                "channel_type": "subscription",
                "wellKnown_Tx": eci,
                "Tx_host": host
            }
        }
    }

    rule delete_sensor {
        select when sensor unneeded_sensor

        pre {
            name = event:attr("name")
            exists = sensors_names().values() >< name
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

    rule notify_threshold_violation {
        select when sensor threshold_violation

        pre {
            temperature = event:attr("temperature")
        }

        twilio:send_sms(phone(), twilio:default_from_number, "Temperature Violation: " + temperature)
    }
}