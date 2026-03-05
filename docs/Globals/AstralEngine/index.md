# AstralEngine
## Description
One single global container for the majority of Astral API
## Contains
### AstralEngine.Log(Msg:string,Flag:'error'|'fatal'|any,Tag:string,Layer:int?)
A basic log function made to log things to console, output syntax will be:
`[ASTRAL <Flag:upper()>][<Tag:upper()>]: <Msg>`
If 'error' is passed, it will instead call `AstralEngine.Error()`
If 'fatal' is passed, it will log a fatal error and quit
### AstralEngine.Quit(Code:int?)
Quits the executable with given exit code
### AstralEngine.Error(Message:string,Tag:string,Layer:int?)
Throws an error at layer `Layer + 1`. Default value of Layer is 1 (caller)
### AstralEngine.Assert<Input>(Value:Input,Message:string,Tag:string) : Input
Checks truthiness of `Value`, if true, returns the `Value` back. Otherwise, errors
### AstralEngine.Restart(Cookie:(string|number|boolean|nil)?)
Restart Astral with the cookie given. CANNOT be a heap-allocated value (with the exception of a string)
### AstralEngine.GetHostVersion() -> string
Returns version of LOVR backend

AstralEngine global also contains several tables with extra methods, they can be read about here:
```markdown
./System.md
./Filesystem.md
./Graphics.md
./Window.md
./Signals.md
./Plugins.md
```
