local currentDir = fs.getDir(shell.getRunningProgram())
local parentDir = fs.getDir(currentDir)
shell.setDir(parentDir)
shell.run("github clone PapaSmurfDev/AR_Multiplayer_CC")
shell.setDir(currentDir)
alias "PapaSmurfDev/AR_Multiplayer_CC/overlayTest" startAR
print("Run startAR to start the AR experience!")
