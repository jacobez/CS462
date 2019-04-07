ruleset gossip {
    meta {
        use module temperature_store
        use module io.picolabs.subscription alias Subscription
        shares temperatures, messages
    }

    global {
        // MODEL ACCESSORS

        messages = function() {
            ent:messages.defaultsTo({})
        }

        update_own_messages = function() {
            messages().put([meta:picoId], temperature_store:temperatures().map(function(temperature, i) {
                {
                    "MessageID": meta:picoId + (":" + (i + 1)),
                    "SensorID": meta:picoId,
                    "Temperature": temperature{"temperature"},
                    "Timestamp": temperature{"timestamp"}
                }
            }))
        }

        peers_seen = function() {
            ent:peers_seen.defaultsTo({})
        }

        subscriptionID_to_picoID = function() {
            ent:subscriptionID_to_picoID.defaultsTo({})
        }

        // COMPUTED PROPERTIES

        own_seen = function() {
            ent:own_seen.defaultsTo({})
        }

        update_own_seen = function() {
            messages().delete([meta:picoId]).map(function(v, k) {
                message_nums = v.map(function(message) {
                    message_id_to_num(message{"MessageID"})
                }).sort("numeric");

                message_nums.reduce(function(a, b) {
                    b - a == 1 => b | a
                }, 0)
            })
        }

        private_seen = function() {
            ent:private_seen.defaultsTo({})
        }

        update_private_seen = function() {
            messages().map(function(v, k) {
                message_nums = v.map(function(message) {
                    message_id_to_num(message{"MessageID"})
                }).sort("numeric");

                message_nums[message_nums.length() - 1]
            })
        }

        temperatures = function() {
            messages().map(function(v, k) {
                v.map(function(t) {
                    {
                        "temperature": t{"Temperature"},
                        "timestamp": t{"Timestamp"}
                    }
                })
            })
        }

        // HELPERS

        message_id_to_num = function(messageID) {
            messageID.split(re#:#)[1].as("Number")
        }

        needs_rumor = function(subscription) {
            picoID = subscriptionID_to_picoID(){[subscription{"Id"}]};

            private_seen().filter(function(v, k) {
                v > peers_seen().get([picoID, k])
            }).keys().length() > 0
        }

        random_message_type = function() {
            types = ["rumor", "seen"];

            types[random:integer(types.length() - 1)]
        }

        extend_messages = function(source, extension) {
            extension.reduce(function(a, b) {
                a.any(function(message) {
                    message{"MessageID"} == b{"MessageID"}
                }) => a | a.append(b)
            }, source)
        }

        getPeer = function() {
            candidates = Subscription:established().filter(function(subscription) {
                subscription{"Tx_role"} == "gossip_peer" && needs_rumor(subscription)
            });
            num_candidates = candidates.length();

            num_candidates > 0 => candidates[random:integer(num_candidates - 1)] | null
        }

        prepare_message = function(peer, message_type) {
            message_type == "seen" => prepare_seen_message() | prepare_rumor_message(peer)
        }

        prepare_rumor_message = function(subscription) {
            picoID = subscriptionID_to_picoID{[subscription{"Id"}]};

            messages().filter(function(v, k) {
                private_seen(){[k]} > peers_seen(){[picoID, k]}
            }).map(function(v, k) {
                v.filter(function(message) {
                    message_id_to_num(message{"MessageID"}) > peers_seen(){[picoID, k]}
                })
            })
        }

        prepare_seen_message = function() {
            {
                "pico": meta:picoId,
                "seen": own_seen()
            }
        }
    }

    rule handle_heartbeat {
        select when gossip heartbeat

        pre {
            peer = getPeer()
            message_type = peer => random_message_type() | "seen"
            message = prepare_message(peer, message_type)
        }

        if peer then
            event:send({
                "eci": peer{"Tx"},
                "eid": "gossip-heartbeat",
                "domain": "gossip",
                "type": message_type,
                "attrs": message
            })

        always {
            ent:messages := update_own_messages();

            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 10})
        }
    }

    rule handle_rumor {
        select when gossip rumor

        pre {
            rumor = event:attrs()
        }

        always {
            ent:messages := rumor.keys().reduce(function(a, b) {
                existing_messages = a.get([b]);
                rumor_messages = rumor.get([b]);

                existing_messages => a.put([b], extend_messages(existing_messages, rumor_messages)) | a.put([b], rumor_messages)
            }, messages());

            ent:own_seen := update_own_seen();
            ent:private_seen := update_private_seen()
        }
    }

    rule handle_seen {
        select when gossip seen

        pre {
            picoID = event:attr("pico")
            seen = event:attr("seen")
        }

        always {
            ent:peers_seen := peers_seen().put([picoID], seen)
        }
    }

    rule initialize {
        select when gossip started

        always {
            ent:messages := update_own_messages();
            ent:own_seen := update_own_seen();
            ent:private_seen := update_private_seen();

            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 20})
        }
    }

    rule add_peer {
        select when gossip peer_introduced

        pre {
            eci = event:attr("eci")
            picoID = event:attr("picoID")
            name = picoID + ":" + meta:picoId
        }

        always {
            raise wrangler event "subscription" attributes {
                "name": name,
                "Rx_role": "gossip_peer",
                "Tx_role": "gossip_peer",
                "channel_type": "subscription",
                "wellKnown_Tx": eci
            }
        }
    }

    rule onboard_peer {
        select when wrangler subscription_added

        pre {
            subscriptionID = event:attr("Id")
            picoIDs = event:attr("name").split(re#:#)
            picoID = picoIDs[0] == meta:picoId => picoIDs[1] | picoIDs[0] 
        }

        always {
            ent:subscriptionID_to_picoID := subscriptionID_to_picoID().put([subscriptionID], picoID)
        }
    }
}