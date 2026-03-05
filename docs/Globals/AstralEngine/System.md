# AstralEngine.System
## Description
A function container holding system API
## Contains
### System.GetCoreCount() -> int
Returns the amount of logical cores on the processor. Best to know this before attempting multithreading
Alias of `lovr.system.getCoreCount()`
### System.GetOS() -> "Windows"|"macOS"|"Android"|"Linux"|"Web"
Returns a string representing the OS
Alias of `lovr.system.getOS()`
### System.SetClipboardText(Text:string)
Sets clipboard text. May silently fail
Alias of `lovr.system.setClipboardText()`
### System.GetClipboardText() -> string?
Gets the clipboard text. May silently fail or be nil
Alias of `lovr.system.getClipboardText()`

## Notes:
When mentioning 'Alias of...' a lovr function, it refers to version 0.18.0
