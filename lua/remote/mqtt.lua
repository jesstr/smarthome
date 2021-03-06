-- Holds dispatching keys to different topics. Serves as a makeshift callback
-- function dispatcher based on topic and message content
m_dis = {}

MQTT_CLIENTID = "remote"
MQTT_HOST = "192.168.1.206"
MQTT_PORT = 1883

local left_button = 0
local right_button = 1
local fd_button = 2
local rr_button = 3

local pins = {1, 2, 5, 6}

local pos = 0

function debounce (func, level)
    local last = 0
    local delay = 30000

    return function (...)
        local now = tmr.now()      
        local diff = now - last
        print(diff)
        
        if diff < delay then print(diff) return end

        last = now
        return func()
    end
end


function onChange ()
    print('hello')
end


function funcB_down()
    print('B pressed')
    m:publish("/motor/cmd/forward", 1023, 0, 0,
        function(m) print("fwd") end)
    gpio.trig(pins[4], 'up',  debounce(funcB_up))  
end

function funcB_up()
    print('B up')
    m:publish("/motor/cmd/forward", 0, 0, 0,
        function(m) print("stop") end)
    gpio.trig(pins[4], 'down',  debounce(funcB_down))  
end

function funcA_down()
    print('A pressed')
    m:publish("/motor/cmd/left", 1023, 0, 0,
        function(m) print("left") end)
    gpio.trig(pins[2], 'up',  funcA_up)  
end

function funcA_up()
    print('A up')
    m:publish("/motor/cmd/left", 0, 0, 0,
        function(m) print("stop") end)
    gpio.trig(pins[2], 'down',  funcA_down)  
end

function funcA(dir)
    if dir == 'd' then 
    print('D')
    gpio.trig(pins[2], 'up',  debounce(funcA, 'u'))
    else 
    print('U')
    gpio.trig(pins[2], 'down',  debounce(funcA, 'd'))
    end
end


print("Init Inputs: ")
for i = 1, table.getn(pins) do
    print("pin: " .. pins[i]) 
    gpio.mode(pins[i], gpio.INT, gpio.PULLUP)
    --gpio.trig(pins[i], 'down',  debounce(onChange))
end

gpio.trig(pins[1], 'down',  debounce(onChange))
gpio.trig(pins[2], 'down',  debounce(funcA_down))
gpio.trig(pins[3], 'down',  debounce(onChange))
gpio.trig(pins[4], 'down',  debounce(funcB_down))


adc.force_init_mode(adc.INIT_ADC)


tmr.alarm(5, 50, 1, function ()
    val = adc.read(0)
    if val > pos+12 or val < pos-12 then
        print (val)
        pos = val

        srv = val / 6 + 65
        m:publish("/motor/cmd/servo", "5"..","..srv, 0, 0,
            function(m) print("5"..","..srv) end)
    end
 end)


-- As part of the dispatcher algorithm, this assigns a topic name as a key or
-- index to a particular function name
m_dis["/motor/stat/run"] = parce_responce


-- initialize mqtt client with keepalive timer of 60sec
m = mqtt.Client(MQTT_CLIENTID, 60, "", "") -- Living dangerously. No password!


-- Set up Last Will and Testament (optional)
-- Broker will publish a message with qos = 0, retain = 0, data = "offline"
-- to topic "/lwt" if client don't send keepalive packet
m:lwt("/lwt", "Oh noes! Plz! I don't wanna die!", 0, 0)


-- When client connects, print status message and subscribe to cmd topic
m:on("connect", function(m) 
    -- Serial status message
    print ("\n\n", MQTT_CLIENTID, " connected to MQTT host ", MQTT_HOST,
        " on port ", MQTT_PORT, "\n\n")

    -- Subscribe to the topic where the ESP8266 will get commands from
    m:subscribe("/motor/cmd/#", 0,
        function(m) print("Subscribed to CMD Topic") end)
        
end)


-- When client disconnects, print a message and list space left on stack
m:on("offline", function(m)
    print ("\n\nDisconnected from broker")
    print("Heap: ", node.heap())
end)


-- On a publish message receive event, run the message dispatcher and
-- interpret the command
m:on("message", function(m,t,pl)
    print("PAYLOAD: ", pl)
    print("TOPIC: ", t)
    
    -- This is like client.message_callback_add() in the Paho python client.
    -- It allows different functions to be run based on the message topic
    if pl~=nil and m_dis[t] then
        m_dis[t](m,pl)
    end
end)

print("Connecting to: ", MQTT_HOST)
-- Connect to the broker
print(m:connect(MQTT_HOST, MQTT_PORT, 0, 1))
--m:close()

