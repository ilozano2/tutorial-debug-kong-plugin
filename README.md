# Debug your Kong Lua plugins 

![tutorial-debug-plugin](https://github.com/user-attachments/assets/218b9698-981c-45b4-bdae-f3cc7286a662)


## Why debug and not only logging?

I started implementing a plugin to convert a blocking API to an asynchronous API, and I found several issues with determining which global objects and contexts I could use in Kong.

The documentation is fine, but when you try to go further, you need to dive into the Lua nginx code. Also, a fair number of Kong developers say that logging is enough and that it follows best practices.
While I concur that judicious use of relevant logs at an appropriate level can enhance your project, it's crucial to avoid unnecessary logging. Over-logging can lead to a cluttered codebase and potentially impact production.

If that's not enough:
* You shouldn't modify third-party components just to check the information about something, and it could be hard
* You cannot print some Lua tables (Try `print(ngx.var)`)
* Modifying your code for adding lines will consume your time

## Requirements

* You have a docker engine installed (Docker desktop or any open source engine like Rancher Desktop, Colima, ...) and docker-compose
* You are using pongo (you can follow the getting started guide https://docs.konghq.com/gateway/latest/plugin-development/get-started/testing/)

## Why I chose `mobdebug`

According to https://www.tutorialspoint.com/lua/lua_debugging.htm there are more debug alternatives. Some of them are deprecated or require adding operative system binaries.

I have to say that there is no particular reason; it is just that `mobdebug` is a good starting point.

## Tutorial

Let's start.

### Prepare Kong image for Pongo

Firstly, you must include the `mobdebug` library in the docker image because `pongo` will run a container with Kong tools, and this container will run a tiny Kong instance with the plugin.

1. Open <KONG_PONGO_HOME>/assets/Dockerfile (Example: `~/.kong-pongo/assets/Dockerfile`)

2. In the RUN block that uses luarocks for installing some packages, add the lua modules to install. I added a new `RUN` to make it clear.

```Dockerfile
RUN cd /kong \
    && git config --global url.https://github.com/.insteadOf git://github.com/ \
    && make dependencies $LUAROCKS_OPTS \
    && luarocks install busted-htest \
    && luarocks install luacov \
    && luarocks install kong-plugin-dbless-reload 0.1.0

# For debugging (you can use other libraries)
RUN luarocks install mobdebug
```

(optional) Alternatively, I think you can try to download files directly in the Pongo shell, which is the Kong container, and move `mobdebug` lua file where all the Lua files are in.

### Add a breakpoint for jumping to Debug mode

You need to add this line in your code:

```lua
function Ilozano2PluginHandler:access(config)
    require("mobdebug").start()
    --[[
        ... your code ...
    --]]

end
```

## Trigger image building by Pongo

Clean the image and generate a new one

```shell
pongo clean
```

Run pongo exposing ports so we can reach Kong with no shell needed; I want to use the shell as a debugger prompt

```shell
pongo up --expose
```

```shell
pongo shell
```

## Run migrations

```
[Kong-3.8.0:external-services:/kong]$> kms
```

## Run Debug 

Run a Lua terminal activating moddebug

```shell
lua -e "require('mobdebug').listen()"
```

> Lua Remote Debugger
> Run the program you wish to debug

### Send request for testing

Configure service and route

```shell
curl -i -s -X POST http://localhost:8001/services \
   --data name=example_service \
   --data url='https://httpbin.konghq.com'

curl -is -X POST http://localhost:8001/services/example_service/plugins \
    --data 'name=ilozano2-plugin'

curl -i -X POST http://localhost:8001/services/example_service/routes \
    --data 'paths[]=/mock' \
    --data name=example_route
```

Assuming you know how Kong plugin works, you can check https://docs.konghq.com/gateway/latest/plugin-development/get-started/testing/ and https://docs.konghq.com/gateway/latest/plugin-development for more information

Send the request

```shell
curl -i http://localhost:8000/mock/anything
```

### Debugging

> Paused at file /kong-plugin/kong/plugins/my-plugin/handler.lua
> Type 'help' for commands

```shell
help
```

```
setb <file> <line>    -- sets a breakpoint
delb <file> <line>    -- removes a breakpoint
delallb               -- removes all breakpoints
setw <exp>            -- adds a new watch expression
delw <index>          -- removes the watch expression at index
delallw               -- removes all watch expressions
run                   -- runs until next breakpoint
step                  -- runs until next line, stepping into function calls
over                  -- runs until next line, stepping over function calls
out                   -- runs until line after returning from current function
listb                 -- lists breakpoints
listw                 -- lists watch expressions
eval <exp>            -- evaluates expression on the current context and returns its value
exec <stmt>           -- executes statement on the current context
load <file>           -- loads a local file for debugging
reload                -- restarts the current debugging session
stack                 -- reports stack trace
output stdout <d|c|r> -- capture and redirect io stream (default|copy|redirect)
basedir [<path>]      -- sets the base path of the remote application, or shows the current one
done                  -- stops the debugger and continues application execution
exit                  -- exits debugger and the application
```

You can inspect the `stack`

```shell
 stack
```

```
{"execute_collecting_plugins_iterator", "/usr/local/share/lua/5.1/kong/init.lua", 363, 398, "Lua", "upvalue", "/usr/local/share/lua/5.1/kong/init.lua"}
{"access", "/usr/local/share/lua/5.1/kong/init.lua", 1167, 1190, "Lua", "field", "/usr/local/share/lua/5.1/kong/init.lua"}
{nil, "=access_by_lua(nginx-kong.conf:112)", 0, 2, "main", "", "access_by_lua(nginx-kong.conf:112)"}
```

You can evaluate `ngx.ctx` and other variables using `eval`


```shell
eval ngx.ctx
```

```
{KONG_ACCESS_START = 1730121763835, KONG_LOG = {alert = function() --[[..skipped..]] end, crit = function() --[[..skipped..]] end, debug = function() --[[..skipped..]] end,
...omitting...
request_uri = "/mock/anything", route = {created_at = 1730121758, https_redirect_status_code = 426, id = "e2a2f152-6c48-4022-8708-6af1d6847909", name = "example_route", path_handling = "v0", paths = {"/mock"}, preserve_host = false, protocols = {"http", "https"}, regex_priority = 0, request_buffering = true, response_buffering = true, service = {id = "ce3a8363-048c-4f36-9142-d8279d537352"}, strip_path = true, updated_at = 1730121758, ws_id = "decd2b97-e2d0-4ec8-917d-ec433723f564"}, route_match_cached = "pos", router_matches = {}, scheme = "http", service = {connect_timeout = 60000, created_at = 1730121757, enabled = true, host = "whatever.requestcatcher.com", id = "ce3a8363-048c-4f36-9142-d8279d537352", name = "whatever_service", port = 443, protocol = "https", read_timeout = 60000, retries = 5, updated_at = 1730121757, write_timeout = 60000, ws_id = "decd2b97-e2d0-4ec8-917d-ec433723f564"}, workspace = "decd2b97-e2d0-4ec8-917d-ec433723f564"} --[[table: 0x10dfbd4c9310]] --[[incomplete output with shared/self-references skipped]]
```

Other interesting commands: `load` (for loading lua files), `exec` (for running a lua statement, you can create global variables).

# Next possible actions

- [] Investigate if there is an alternative to modifying code with the `require("mobdebug").start()` line
- [] Check if just running `pongo build` will make the job instead of cleaning all the images
- [] Check if other Debug tools that include a UI or remote debugging compatibility
- [] Extend this tutorial for debugging in a Kong environment without Pongo requirements
- [] Explore other alternatives to `mobdebug`
