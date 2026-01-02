# USE --gc:none FLAG. THIS DOESNT ALLOC SO NEEDS NO GC
import times
import std/monotimes
import ../../LuaNim

template FastTime(): float64 = (getMonoTime()-T0).inSeconds.float

let T0 = getMonoTime()
template GetTime() : float64 = epochTime()

template KillRoutine(L,RIdx) = 
    lua_pushvalue(L,-1)
    lua_pushnil(L)
    lua_settable(L,RIdx)

proc Do_Routines(L:Plua_State; Budget, Start:float64) : bool =
    let Top = lua_gettop(L);
    let
        RoutinesIdx : cint = Top - 2
        ResumeAtIdx : cint = Top - 1
        ExternQueuedIdx : cint = Top

    lua_pushnil(L)
    while lua_next(L,RoutinesIdx) != 0:

        let t : cint = lua_type(L,-1)
        if t != LUA_TTHREAD:
            echo "Routine not a routine!"
            lua_pop(L,1)
            continue

        let Cor : Plua_State = lua_tothread(L,-1)

        # CHECK QUEUE

        lua_pushthread(Cor)
        lua_xmove(Cor,L,1)
        lua_gettable(L,ExternQueuedIdx)
        if lua_toboolean(L,-1) != 0:
            lua_pop(L,2)
            continue
        lua_pop(L,1)

        # RESUME OR SMTH

        lua_pushthread(Cor)
        lua_xmove(Cor,L,1)
        lua_gettable(L,ResumeAtIdx)
        var Wake : float64 = 0
        if lua_isnumber(L,-1) != 0:
            Wake = lua_tonumber(L,-1)
        lua_pop(L,1)

        if Wake != 0 and GetTime() < Wake: # waiting
            lua_pop(L,1)
            continue

        let Elapsed : float64 = GetTime() - Start
        if Elapsed > Budget: # timeout
            lua_pop(L,1)
            return false

        let State : cint = lua_status(Cor)

        if State != LUA_YIELD:
            lua_pop(L,1)
            KillRoutine(L,RoutinesIdx)
            continue

        let Status : cint = lua_resume(Cor,0)
        lua_pop(L,1)
    
        if Status == LUA_YIELD:
            discard
        else:
            # dead, remove
            KillRoutine(L,RoutinesIdx)

            if Status != 0:   
                let Msg : string = $lua_tostring(Cor,-1)
                echo "Coroutine Error: ", Msg
                lua_pop(Cor,1)
            
    return true

proc DoQueue(L: Plua_State; Budget, Start : float64) =

    let QueueIdx : cint = lua_gettop(L)
    
    lua_getfield(L,1,"Routines")
    let RIdx : cint = lua_gettop(L)

    lua_pushnil(L)
    while lua_next(L,QueueIdx) != 0:
        let Elapsed : float64 = GetTime() - Start
        if Elapsed > Budget:
            lua_pop(L,1)
            return

        let TP : cint = lua_type(L,-1)
        if TP != LUA_TTABLE:
            lua_pop(L,1)
            continue

        let QIdx = lua_gettop(L)

        lua_getfield(L,QIdx,"F")
        if lua_type(L,-1) != LUA_TFUNCTION:
            echo "Missing func entry!"
            lua_pop(L,2)
            continue

        let Co : Plua_State = lua_newthread(L)

        var Len = lua_objlen(L,RIdx)
        lua_pushvalue(L,-1)
        lua_rawseti(L,RIdx,Len.cint + 1)

        lua_pushvalue(L,-2)
        lua_xmove(L,Co,1)
        lua_pop(L,2)

        lua_getfield(L,-1,"P")
        var ArgCount : int = 0
        if lua_type(L,-1) == LUA_TTABLE:
            let Len : csize_t = lua_objlen(L,-1)
            for i in 1..Len.int:
                lua_rawgeti(L,-1,i.cint)
                lua_xmove(L,Co,1)
                inc ArgCount
        lua_pop(L,1)

        lua_pushvalue(L,-2)
        lua_pushnil(L)
        lua_settable(L,QueueIdx)

        let Status : cint = lua_resume(Co,ArgCount.cint)

        if Status != 0 and Status != LUA_YIELD:
            let msg = $lua_tolstring(Co, -1, nil)
            echo "[Scheduler] Error: ", msg
        lua_pop(L,1)

    lua_pop(L,1)

proc lua_SchedUpd*(L:Plua_State) : cint {.cdecl.} =
    let base = lua_gettop(L)
    defer:
        let top = lua_gettop(L)
        if top != base:
            lua_pop(L,top-base)

    lua_pushvalue(L,1) # table

    var WithinBudget : bool = true

    let Start : float64 = GetTime()

    # GET BUDGET
    lua_getfield(L,-1,"Budget")
    let Budget : cdouble = lua_tonumber(L,-1)
    lua_pop(L,1)
    # POP BUDGET

    # ROUTINES
    lua_getfield(L,-1,"Routines")
    lua_getfield(L,-2,"ResumeAt")
    lua_getfield(L,-3,"ExternQueued")
    WithinBudget = Do_Routines(L,Budget,Start)
    lua_pop(L,3)

    if WithinBudget != true or GetTime() - Start > Budget:
        lua_pop(L,1)
        return 0

    lua_getfield(L,-1,"Queue")
    Do_Queue(L,Budget,Start)
    lua_pop(L,1)

    lua_pop(L,1)

    return 0

proc lua_GetClock*(L:Plua_State) : cint {.cdecl.} =
    lua_pushnumber(L, GetTime())
    return 1

proc luaopen_libNativeSched*(L: Plua_State) : cint {.cdecl, exportc, dynlib.} =
    lua_newtable(L)
    lua_pushcfunction(L,lua_SchedUpd)
    lua_setfield(L,-2,"Update")
    lua_pushcfunction(L, lua_GetClock)
    lua_setfield(L,-2,"Clock")
    return 1
