import posix
import asyncdispatch
import asyncnet

import "../savedata"
import "../requests"
import "./utils"
import "./object"
import "./response"

proc CreateSave*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
    var s: Stat
    if stat(cmd.create.sourceFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
        respondWithError(client, "E:TARGET_FOLDER_INVALID")
        return

    setupCredentials()

    var createStatus = createSave(cmd.create.sourceFolder, cmd.create.saveName, cmd.create.blocks)
    if createStatus != 0:
        respondWithError(client, "E:CREATE_FAILED")
        return
    
    respondWithOk(client)

let cmd* = Command(useSlot: false, useFork: true, fun: CreateSave) 