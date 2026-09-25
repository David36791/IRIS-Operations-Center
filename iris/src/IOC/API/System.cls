Class IOC.API.System Extends %RegisteredObject
{

/// GET /api/ioc/system
ClassMethod GetInfo() As %DynamicObject
{
    Quit ##class(IOC.Service.Management).GetInstanceInfo()
}

/// GET /api/ioc/system/usage
ClassMethod GetUsage() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("monitor/system-usage")
}

/// GET /api/ioc/system/license
ClassMethod GetLicenseUsage() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("monitor/license-usage")
}

/// GET /api/ioc/system/processes
ClassMethod GetProcesses() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("process/")
}

/// DELETE /api/ioc/system/processes/:pid — terminate a process.
/// The caller is expected to have checked CanBeTerminated on the process row;
/// IRIS enforces the same rule itself.
ClassMethod TerminateProcess(pPid As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.id = pPid
    Quit ##class(IOC.Service.Management).CallAdmin("process", "DELETE", tParams)
}

/// GET /api/ioc/system/memory — IRIS shared memory usage.
ClassMethod GetMemoryUsage() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("monitor/system-usage/shared-memory")
}

/// GET /api/ioc/system/devices
ClassMethod GetDevices() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("device/")
}

/// GET /api/ioc/system/disk — capacity of the storage volume each database
/// directory sits on.
///
/// The figures come from the instance's own system metrics endpoint, which
/// publishes them as Prometheus text. That endpoint is used rather than the
/// monitor classes because the data lives in %SYS and is not reachable from
/// this application's own namespace; going over HTTP gets there.
///
/// One row per database directory. The volume figures are the filesystem's,
/// not the database's, so directories sharing a volume repeat them.
ClassMethod GetDiskUsage() As %DynamicAbstractObject
{
    Set tText = ##class(IOC.Service.Management).CallMetrics()
    Set tMounts = {}
    Set tLineCount = $LENGTH(tText, $CHAR(10))

    For tIndex = 1:1:tLineCount {
        Set tLine = $TRANSLATE($PIECE(tText, $CHAR(10), tIndex), $CHAR(13))
        ; A postconditional takes only a simple expression, so these guards are
        ; written out rather than hung off the command.
        If (tLine = "") || ($EXTRACT(tLine, 1) = "#") {
            Continue
        }

        Set tOpen = $FIND(tLine, "{")
        If tOpen = 0 {
            Continue
        }
        Set tName = $EXTRACT(tLine, 1, tOpen - 2)
        If (tName '= "iris_directory_space") && (tName '= "iris_disk_percent_full") && (tName '= "iris_db_size_mb") {
            Continue
        }

        Set tClose = $FIND(tLine, "}", tOpen)
        If tClose = 0 {
            Continue
        }
        Set tLabels = ..MetricLabels($EXTRACT(tLine, tOpen, tClose - 2))
        Set tDirectory = tLabels.%Get("dir")
        If tDirectory = "" {
            Continue
        }
        ; The value is separated from the labels by a space, and the unary plus
        ; does not skip it: without the strip the whole figure reads as zero.
        Set tValue = +$ZSTRIP($EXTRACT(tLine, tClose, *), "<>", " ")

        Set tMount = tMounts.%Get(tDirectory)
        If '$ISOBJECT(tMount) {
            Set tMount = { "Directory": (tDirectory) }
            Do tMounts.%Set(tDirectory, tMount)
        }

        If tName = "iris_directory_space" {
            Do tMount.%Set("available", tValue)
        } ElseIf tName = "iris_disk_percent_full" {
            Do tMount.%Set("usage", tValue)
        } Else {
            ; one line per database, so these also list what lives here
            Set tNames = tMount.%Get("databases")
            Set tId = tLabels.%Get("id")
            Do tMount.%Set("databases", $SELECT(tNames = "": tId, 1: tNames _ ", " _ tId))
        }
    }

    ; Emit in directory order, which $ORDER over the subscripts gives.
    Set tKeys = ""
    Set tIter = tMounts.%GetIterator()
    While tIter.%GetNext(.tKey) {
        Set tKeys(tKey) = ""
    }

    Set tOut = []
    ; Walked with $ORDER in the condition rather than a Quit inside the block:
    ; Quit inside a block construct leaves the loop rather than the method.
    Set tDirectory = $ORDER(tKeys(""))
    While tDirectory '= "" {
        Set tMount = tMounts.%Get(tDirectory)
        Set tRow = { "Directory": (tDirectory) }
        Set tRow.databases = tMount.%Get("databases")

        ; The metrics carry a size for every database but the volume figures
        ; only for the directories the storage sensor reaches, so a row can be
        ; listed without them. It says so rather than reporting zero, which
        ; would read as a full disk.
        Set tMeasured = (tMount.%IsDefined("available") && tMount.%IsDefined("usage"))
        Do tRow.%Set("measured", tMeasured, "boolean")
        If tMeasured {
            Set tAvailable = +tMount.%Get("available")
            Set tUsage = +tMount.%Get("usage")
            ; The metrics give free space and the percentage used, not the size,
            ; so the size is derived from those two.
            Set tTotal = $SELECT((tUsage > 0) && (tUsage < 100): tAvailable / (1 - (tUsage / 100)), 1: tAvailable)
            Set tRow.total = ..Round(tTotal)
            Set tRow.used = ..Round(tTotal - tAvailable)
            Set tRow.available = tAvailable
            Set tRow.usage = tUsage
        } Else {
            Set tRow.total = 0
            Set tRow.used = 0
            Set tRow.available = 0
            Set tRow.usage = 0
        }
        Do tOut.%Push(tRow)
        Set tDirectory = $ORDER(tKeys(tDirectory))
    }
    Quit tOut
}

/// The labels of a Prometheus metric line, as an object of name to value.
ClassMethod MetricLabels(pText As %String) As %DynamicObject [ Private ]
{
    Set tOut = {}
    Set tCount = $LENGTH(pText, ",")
    For tIndex = 1:1:tCount {
        Set tPair = $PIECE(pText, ",", tIndex)
        Set tName = $ZSTRIP($PIECE(tPair, "=", 1), "<>", " ")
        ; the value is quoted, and a directory can contain anything else
        Set tValue = $ZSTRIP($PIECE(tPair, "=", 2, *), "<>", """")
        Do tOut.%Set(tName, tValue)
    }
    Quit tOut
}

/// Round to one decimal: the derived size carries a long fraction that means
/// nothing at megabyte scale.
ClassMethod Round(pValue As %Double) As %Double [ Private ]
{
    Quit ((pValue * 10) \ 1) / 10
}

}
