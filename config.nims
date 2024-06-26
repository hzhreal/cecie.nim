import std/strutils
import os

var jbcPath = getCurrentDir() / "ps4-libjbc"

switch "o", "cecie.elf"
switch "mm", "orc"
switch "nimcache", "./cache"
switch "threads", "off"
switch("cincludes", jbcPath)
switch("passL", "-L" & jbcPath & " -ljbc")

proc getContentId: string =
  let servId = getEnv("app_SERVICE_ID")
  #let titleId = getEnv("app_TITLE_ID")
  #var productLabel = getEnv("app_PRODUCT_LABEL")
  #productLabel = productLabel.toUpperAscii
  #productLabel = productLabel.alignLeft(16, '0')
  var contentId: string
  contentId.addf("$#", servId)
  return contentId

proc getOOBinaryPath(binName: string): string =
  var osDir: string
  if hostOS == "linux":
    osDir = "linux"
  elif hostOS == "windows":
    osDir = "windows"
  elif hostOS == "darwin":
    osDir = "macos"
  else:
    raise newException(ValueError, "Invalid host os $#" % hostOS)
  
  result.addf("$#/bin/$#/$#",getEnv("OO_PS4_TOOLCHAIN"), osDir, binName)
  if ExeExt != "":
    result = addFileExt(result, ExeExt)

type SfoEntry = tuple
  entryName: string
  entryType: string
  entryMaxSize: string
  entryValue: string

proc toParamSfoEditCommand(exePath: string, sfoFile: string, entry: SfoEntry): string =
  result.addf("$# sfo_setentry $#", exePath, sfoFile)
  result.addf(" $# --type $# --maxsize $#", 
              entry.entryName, 
              entry.entryType,
              entry.entryMaxSize)
  if entry.entryType == "Utf8":
    result.addf(" --value '$#'", entry.entryValue)
  else:
    result.addf(" --value $#", entry.entryValue)

proc executeCmd(cmd: string) = 
  # echo "Executing: ", cmd
  exec cmd

proc generateSfo(sfoPath: string) = 
  
  type SfoEntries = seq[SfoEntry]

  var sfoEntries: SfoEntries = @[
    ("APP_TYPE", "Integer", "4", "1"),
    ("APP_VER", "Utf8", "8", getEnv("app_VERSION")),
    ("ATTRIBUTE", "Integer", "4", "0"),
    ("CATEGORY", "Utf8", "4", "gd"),
    ("CONTENT_ID", "Utf8", "48", getContentId()),
    ("DOWNLOAD_DATA_SIZE", "Integer", "4", "0"),
    ("SYSTEM_VER", "Integer", "4", "0"),
    ("TITLE", "Utf8", "128", getEnv("app_TITLE")),
    ("TITLE_ID", "Utf8", "12", getEnv("app_TITLE_ID")),
    ("VERSION", "Utf8", "8", getEnv("app_VERSION"))
  ]

  var pkgToolPath = getOOBinaryPath("PkgTool.Core")
  var osDir : string

  var cmd: string = "$# sfo_new $#" % [pkgToolPath, sfoPath]
  executeCmd(cmd)
  for sfoEntry in sfoEntries:
    cmd = toParamSfoEditCommand(pkgToolPath, sfoPath, sfoEntry)
    executeCmd(cmd)

proc generateFself(elfIn:string, ebootPath: string) =
  var fselfBin = getOOBinaryPath("create-fself")
  var sdkVersion = 0x45_08_101
  var paid = "0x3800000000000011"
  # 0x3800000000000010
  var authinfo ="0000000000000000";
  authinfo.add("0000000080030020")
  authinfo.add("00FF000000000000")
  authinfo.add("0000000000000000")
  authinfo.add("0000000000000000")
  authinfo.add("0000004000400040")
  authinfo.add("0000000000000040")
  authinfo.add("0200000000008000")
  authinfo.add("0040FFFF000000F0")
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");
  authinfo    .add("0000000000000000");

  var fselfParamFmt = "$# -eboot=$# -sdkver=$# -in=$# --paid=$# --authinfo=$# $#"
  executeCmd(fselfParamFmt % [fselfBin, ebootPath, $sdkVersion, elfIn,paid, authinfo, elfIn])
  
proc generateGp4(pkgPath: string, outGp4Path: string) = 
  var createGp4Bin = getOOBinaryPath("create-gp4")
  var cmd : string
  cmd.add(createGp4Bin)
  cmd.addf(" -out $#", outGp4Path)
  cmd.addf(" --content-id $#", getContentId())
  var paths = newSeq[string]()
  for path in walkDirRec(pkgPath, relative=true):
    if path.endsWith(".gp4"):
      continue
    paths.add(path)
  cmd.add(" --files \"$#\"" % paths.join(" "))
  executeCmd(cmd)

proc generatePkg(gp4Path: string) = 
  var cmd: string
  var pkgToolPath = getOOBinaryPath("PkgTool.Core")
  cmd.add(pkgToolPath)
  cmd.addf(" pkg_build $# ." % gp4Path)
  executeCmd(cmd)

task build_pkg, "builds ps4 pkg for cecie":
  var paramsList = os.commandLineParams()
  var extraParams : string
  if paramsList.len > 1:
    extraParams.add(paramsList[1..^1].join(" ")) 
  selfExec "c --os:orbis -d:nimAllocPagesViaMalloc " & extraParams
  if getEnv("OO_PS4_TOOLCHAIN") == "":
    raise newException(ValueError, "Must set OO_PS4_TOOLCHAIN environment variable")
  let pkgPath = getEnv("app_PKG_DIR")
  if pkgPath == "":
    raise newException(ValueError, "Must set app_PKG_DIR environment variable")
  generateFself("cecie.elf", joinPath(pkgPath, "eboot.bin"))

  let paramSfoPath = joinPath(pkgPath, "sce_sys/param.sfo")
  generateSfo(paramSfoPath)
  let gp4FilePath = joinPath(pkgPath, "pkg.gp4")
  generateGp4(pkgPath, gp4FilePath)
  generatePkg(gp4FilePath)
