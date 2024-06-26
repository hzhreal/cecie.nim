import json

type ClientRequestType* = enum
  rtKeySet,
  rtListSaveFiles,
  rtCreateSave,
  rtDecryptSealedKey,
  rtDumpSave,
  rtUpdateSave,
  rtResignSave,
  rtClean,
  rtUploadFile,
  rtDownloadFile,
  rtListFiles,
  rtInvalid

type ListClientRequest* = object
  saveName*: string

type CreateClientRequest* = object
  sourceFolder*: string
  saveName*: string
  blocks*: cint

type SealedKeyClientRequest* = object
  sealedKey*: seq[byte]

type UpdateClientRequest* = object
  sourceFolder*: string
  saveName*: string
  selectOnly*: seq[string]

type DumpClientRequest* = object
  targetFolder*: string
  saveName*: string
  selectOnly*: seq[string]

type ResignClientRequest* = object
  accountId*: uint64
  saveName*: string

type CleanClientRequest* = object
  saveName*: string
  folder*: string

type UploadClientRequest* = object
  target*: string
  size*: uint64

type DownloadClientRequest* = object
  source*: string

type ListFilesClientRequest* = object
  folder*:string

type ClientRequest* = object
  case RequestType*: ClientRequestType
  of rtKeySet, rtInvalid:
    discard
  of rtListSaveFiles:
    list*: ListClientRequest
  of rtCreateSave:
    create*: CreateClientRequest
  of rtDecryptSealedKey:
    decsdkey*: SealedKeyClientRequest
  of rtUpdateSave:
    update*: UpdateClientRequest
  of rtDumpSave:
    dump*: DumpClientRequest
  of rtResignSave:
    resign*: ResignClientRequest
  of rtClean:
    clean*: CleanClientRequest
  of rtUploadFile:
    upload*: UploadClientRequest
  of rtDownloadFile:
    download*: DownloadClientRequest
  of rtListFiles:
    ls*: ListFilesClientRequest

proc parseRequest*(data: string): ClientRequest = 
  try:
    let jsonData = parseJson(data)
    result = to(jsonData, ClientRequest)
  except JsonParsingError, KeyError, ValueError:
    result = ClientRequest(RequestType: rtInvalid)

