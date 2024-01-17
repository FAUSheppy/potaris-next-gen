---
title: Python Flask Production Migration
date: 2014-12-22
description: Python Flask Production Migration
---

I like to start my flask projects with a simple __name__ == "__main__" with argparse and app.run(). But obviously the flask inbuilt server is not the fastest and probably not the safest either. This is why you should eventually use a WSGI-runner like waitress to run your app. This post will show how to migrate, while keeping any standalone capabilities.

## Migrating “__init__” code
In short, everything in your if __name__ block is not going to be executed anymore, the simplest solution is to move it to a `@app.before_first_request` annotated function, so:

    app = Flask("NAME")
    
    if __init__ == "__name__":
        # arparse stuff
        ...
        # init stuff
        ...
        app.run(host="127.0.0.1", port=5300)

becomes:

    app = Flask("NAME")
    
    @app.before_first_request
    def doStuff():
        # init stuff
        ...

    if __init__ == "__name__":
        # arparse stuff
        ...
        # write arparse results to config
        app.run(host="127.0.0.1", port=5300)

Obviously, we now need to create an alternative option for configuration to argparse, whenever the app is started through WSGI. This means we must write any argparse-inputs, which aren’t port or interface, to a static config file. You can, for example, create a config.py in the root directory of your project and load it with app.config.from_object or you can simply use:

    app.config['OPTION'] = "something"

We can then change it like a namespace-object (basically a dict-object). Remember that any options you pass to app.run don’t have to be/can’t be written to app.config, as they will later be supplied by the WSGI-runner configuration.

**config.py:**

    SOME_OPTION=A
    ANOTHER_VARIABLE=42
    server.py:
    
    app = Flask("NAME")
    app.config.from_object("config") # note the missing '.py'
    app.config["MORE_OPTIONS"] = "Hello"
    
    @app.before_first_request
    def doStuff():
        doInitSuff(app.config.SOME_OPTION)
    
    if __init__ == "__name__":
    
        parser = argparse.ArgumentParser()
        parser.add_argument(...)
        args = parse.parse_args()
    
        app.config['SOME_OPTION'] = args.SOME_OPTIONS
        app.run(host="127.0.0.1", port=53000)

Finally you need to add an entry point. The simplest way to do this, is to create a new file and add a really simple function, which returns the flask application in your main module, e.g. the following app.py with ‘app’ being the global variable app in server.py, aka your main file, presumably containing all the annotated functions/webserver paths etc. :

    # note the missing'.py'
    import server as moduleContainingApp
    # default value is required
    
    def createApp(envivorment=None, start_response=None): 
        return moduleContainingApp.app

You could also use the environment for on the fly configuration.

## Setting up WSGI (waitress)
The simplest production server for the WSGI-protocol is waitress, you can install it with pip, or via apt as python3-waitress on Debian9+. Then run it with:

    waitress-serve --host 127.0.0.1 --port 5300 --call 'app:createApp'
    createApp is your entry point, app your app.py containing this entry point.

## Bonus: Running with systemd
Write this to a file called NAME.service in /etc/systemd/user/

    [Unit]
    Description=Hello Flask
    After=network.target
    
    [Service]
    WorkingDirectory=/path/to/appDir/
    Type=simple
    User=www-data
    ExecStart=/usr/bin/waitress-serve/ --host 127.0.0.1 --port 5004 --call 'app:createApp'
    
    [Install]
    WantedBy=multi-user.target
    Enable it with it’s full path, then start it by it’s name:
    
    systemctl enable /etc/systemd/user/NAME.service


    systemctl start NAME

Now it will run and start automatically on reboot. No more excuses to use cron-@reboot. You people annoy me. Yes I’m looking at you.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Mail, Postfix, automx, IMAP, SMTP_</sup>
