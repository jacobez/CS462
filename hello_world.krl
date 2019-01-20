ruleset hello_world {
    meta {
        name "Hello World"
        description <<
            A first rule for the Quickstart
        >>
        logging on
        shares hello
    }

    global {
        hello = function(obj) {
            msg = "Hello " + obj;
            msg
        }
    }

    rule hello_world {
        select when echo hello
        send_directive("say", {
            "something": "Hello World"
        })
    }

    rule hello_monkey {
        select when echo monkey
        pre {
            name = (event:attr("name") => event:attr("name") | "Monkey").klog("Name Used: ")
        }
        send_directive("say", {
            "something": "Hello " + name
        })
    }
}