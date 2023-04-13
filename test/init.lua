_G.require = require
local Signal = require("main")
local mySignal = Signal.Bindable.New()
local insert = table.insert
local results = {}
local write = function (str) process.stdout:write(str) end
local timer = require("timer")

print(coroutine.running())
coroutine.wrap(function()
    do
        write(" - Connect/Disconnect test")
        local connection = mySignal:Connect(function(v)
            insert(results,v)
        end)
        mySignal:FireSync("1 (True)")
        connection:Disconnect()
        mySignal:FireSync("2 (False)")
        if
        results[1] == "1 (True)"
        and results[2] == nil
        then
            write(" [OK]\n")
        else
            write(" [FAIL]\n")
        end
        results = {}
    end

    do
        write(" - Wait test")
        timer.setTimeout(1000,function()
            mySignal:Fire("1 (True)")
        end)
        if mySignal:Wait() == "1 (True)" then
            write(" [OK]\n")
        else
            write(" [FAIL]\n")
        end
    end

    do
        write(" - Wait timeout test")
        if mySignal:Wait(1) == Signal.Timeouted then
            write(" [OK]\n")
        else
            write(" [FAIL]\n")
        end
    end

    do
        write(" - Wait release test")
        timer.setTimeout(2000,function()
            mySignal:ReleaseWaittings()
        end)
        if mySignal:Wait() == Signal.Released then
            write(" [OK]\n")
        else
            write(" [FAIL]\n")
        end
    end

    do
        write(" - Once test")
        mySignal:Once(function(v)
            insert(results,v)
        end)
        mySignal:FireSync("1 (True)")
        mySignal:FireSync("1 (False)")
        if
        results[1] == "1 (True)"
        and results[2] == nil
        then
            write(" [OK]\n")
        else
            write(" [FAIL]\n")
        end
        results = {}
    end

    do
        write(" - Once disconnect test")
        mySignal:Once(function(v)
            print(v)
        end):Disconnect()
        mySignal:FireSync("1 (False)")

        if results[1] == nil then
            write(" [OK]\n")
        else
            write(" [FAIL]\n")
        end
        results = {}
    end
end)()
