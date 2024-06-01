import asyncdispatch
import asyncnet
import strutils

import "orbis/savedata_advanced"
import "../requests"
import "./object"
import "./response"
import "./utils"

proc DecryptSealedKey*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
    if cmd.decsdkey.sealedKey.len != 96:
        respondWithError(client, "E:SEALEDKEY_INVALID_LEN")
        return

    setupCredentials()
    
    var encryptedSealedKey: array[96, byte]
    for i in 0..<96:
        encryptedSealedKey[i] = cmd.decsdkey.sealedKey[i]

    var decryptedSealedKey: array[32, byte]
    
    var decStatus = decryptSealedKey(encryptedSealedKey, decryptedSealedKey)
    if decStatus == -1:
        respondWithError(client, "E:SEALEDKEY_DEC_FAIL")
        return
    
    respondWithJson(client, decryptedSealedKey)

let cmd* = Command(useSlot: false, useFork: true, fun: DecryptSealedKey)